package com.tether.app.tether

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.InetSocketAddress
import java.security.cert.X509Certificate
import javax.net.ssl.*

/**
 * Native Kotlin TCP server/client with TLS, handshake protocol,
 * tie-breaking, heartbeats, and auto-reconnection.
 *
 * Replaces the Dart `ConnectionManager`, `TcpServer`, and `TcpClient`.
 * Runs entirely on Kotlin Coroutines inside the ForegroundService.
 */
class NativeConnectionManager(
    private val context: Context,
    private val listener: ConnectionListener
) {
    companion object {
        private const val TAG = "NativeConnMgr"
    }

    interface ConnectionListener {
        fun onConnectionStateChanged(state: String)
        fun onDeviceConnected(device: ConnectedDevice)
        fun onDeviceDisconnected()
        fun onClipboardReceived(content: String, dataType: String)
        fun onNotificationReceived(payload: NotificationPayload)
    }

    data class ConnectedDevice(
        val deviceId: String,
        val name: String,
        val platform: String,
        val ip: String,
        val port: Int,
        var battery: Int? = null,
        var wifiStrength: Int? = null,
        var lastSeen: Long = System.currentTimeMillis()
    )

    enum class ConnectionState(val value: String) {
        DISCONNECTED("disconnected"),
        SEARCHING("searching"),
        CONNECTING("connecting"),
        CONNECTED("connected")
    }

    // ─── State ───

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val db = TetherDatabase.getInstance(context)
    private val deviceId = db.getDeviceId()
    private val deviceName = db.getDeviceName()
    private var discoveryNonce: Int = (0..10_000_000).random()

    @Volatile
    private var state = ConnectionState.DISCONNECTED

    @Volatile
    private var connectedDevice: ConnectedDevice? = null

    @Volatile
    private var explicitDisconnect = false

    // Server
    private var serverSocket: SSLServerSocket? = null
    private var serverJob: Job? = null

    // Client
    private var clientSocket: SSLSocket? = null
    private var clientReaderJob: Job? = null
    private var heartbeatJob: Job? = null

    // Reconnect
    private var reconnectJob: Job? = null

    // ─── Public API ───

    fun getConnectionState(): String = state.value

    fun getConnectedDeviceInfo(): Map<String, Any?>? {
        val dev = connectedDevice ?: return null
        return mapOf(
            "deviceId" to dev.deviceId,
            "name" to dev.name,
            "platform" to dev.platform,
            "ip" to dev.ip,
            "port" to dev.port,
            "battery" to dev.battery,
            "wifiStrength" to dev.wifiStrength
        )
    }

    /**
     * Start the TLS server on port 5280 and begin accepting connections.
     */
    fun startServer() {
        if (serverJob?.isActive == true) {
            Log.w(TAG, "Server already running")
            return
        }

        serverJob = scope.launch {
            var retries = 0
            val maxRetries = 5

            while (retries < maxRetries && isActive) {
                try {
                    val sslContext = TetherTlsManager.createServerSSLContext(context)
                    val factory = sslContext.serverSocketFactory as SSLServerSocketFactory

                    serverSocket = (factory.createServerSocket() as SSLServerSocket).apply {
                        reuseAddress = true
                        bind(InetSocketAddress(TetherConstants.TCP_PORT))
                        needClientAuth = false
                        wantClientAuth = false
                    }

                    Log.i(TAG, "TLS server listening on port ${TetherConstants.TCP_PORT}")
                    acceptLoop()
                    break // If acceptLoop returns normally, we're done
                } catch (e: Exception) {
                    retries++
                    Log.e(TAG, "Server bind failed (attempt $retries/$maxRetries): ${e.message}")
                    serverSocket?.close()
                    serverSocket = null
                    if (retries < maxRetries) {
                        delay(2000)
                    }
                }
            }
        }
    }

    /**
     * Connect to a specific peer as a TLS client.
     */
    fun connectTo(host: String, port: Int) {
        if (state == ConnectionState.CONNECTED) {
            Log.w(TAG, "Already connected, disconnect first")
            return
        }

        explicitDisconnect = false
        setState(ConnectionState.CONNECTING)

        scope.launch {
            try {
                val sslContext = TetherTlsManager.createTrustAllSSLContext()
                val factory = sslContext.socketFactory as SSLSocketFactory

                val socket = factory.createSocket() as SSLSocket
                socket.connect(
                    InetSocketAddress(host, port),
                    TetherConstants.CONNECT_TIMEOUT_MS
                )
                socket.startHandshake()

                clientSocket = socket
                Log.i(TAG, "TLS client connected to $host:$port")

                // Send our handshake
                sendPacket(
                    socket,
                    Packet(
                        type = PacketType.HANDSHAKE,
                        deviceId = deviceId,
                        payload = HandshakePayload(
                            name = deviceName,
                            platform = "Android",
                            version = TetherConstants.APP_VERSION
                        ).toMap()
                    )
                )

                // Start reading
                startClientReader(socket, host, port)
                startHeartbeat(socket)
            } catch (e: Exception) {
                Log.e(TAG, "connectTo($host:$port) failed: ${e.message}")
                setState(ConnectionState.DISCONNECTED)
                scheduleReconnect()
            }
        }
    }

    /**
     * Disconnect from the current peer gracefully.
     */
    fun disconnect() {
        explicitDisconnect = true
        reconnectJob?.cancel()
        reconnectJob = null

        scope.launch {
            try {
                clientSocket?.let { socket ->
                    try {
                        sendPacket(
                            socket,
                            Packet(
                                type = PacketType.DISCONNECT,
                                deviceId = deviceId,
                                payload = mapOf("reason" to "user_initiated")
                            )
                        )
                        socket.close()
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {}

            clientSocket = null
            heartbeatJob?.cancel()
            clientReaderJob?.cancel()
            connectedDevice = null
            setState(ConnectionState.DISCONNECTED)
            listener.onDeviceDisconnected()
            persistState()
        }
    }

    /**
     * Called by [NativeDiscovery] when a peer is found.
     * Handles tie-breaking logic to decide who connects to whom.
     */
    fun onPeerDiscovered(peer: NativeDiscovery.DiscoveredPeer) {
        if (state == ConnectionState.CONNECTED) return

        // Tie-breaker: higher nonce is the client (initiates connection)
        if (discoveryNonce > peer.nonce) {
            Log.i(TAG, "Tie-break: I am CLIENT (my nonce ${discoveryNonce} > peer ${peer.nonce})")
            connectTo(peer.ip, peer.port)
        } else {
            Log.i(TAG, "Tie-break: I am SERVER (my nonce ${discoveryNonce} < peer ${peer.nonce})")
            // Wait for peer to connect to us
        }
    }

    /**
     * Send clipboard data to the connected peer.
     */
    fun sendClipboard(content: String, dataType: String = "TEXT") {
        val socket = clientSocket ?: return
        scope.launch {
            try {
                sendPacket(
                    socket,
                    Packet(
                        type = PacketType.CLIPBOARD_UPDATE,
                        deviceId = deviceId,
                        payload = ClipboardPayload(content, dataType).toMap()
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send clipboard: ${e.message}")
            }
        }
    }

    /**
     * Send a notification to the connected peer.
     */
    fun sendNotification(payload: NotificationPayload) {
        val socket = clientSocket ?: return
        scope.launch {
            try {
                sendPacket(
                    socket,
                    Packet(
                        type = PacketType.NOTIFICATION,
                        deviceId = deviceId,
                        payload = payload.toMap()
                    )
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send notification: ${e.message}")
            }
        }
    }

    /**
     * Stop everything: server, client, reconnect, heartbeat.
     */
    fun shutdown() {
        Log.i(TAG, "Shutting down connection manager")
        reconnectJob?.cancel()
        heartbeatJob?.cancel()
        clientReaderJob?.cancel()
        serverJob?.cancel()

        try { clientSocket?.close() } catch (_: Exception) {}
        try { serverSocket?.close() } catch (_: Exception) {}

        clientSocket = null
        serverSocket = null
        connectedDevice = null
        setState(ConnectionState.DISCONNECTED)
        scope.coroutineContext[Job]?.cancelChildren()
    }

    // ─── Server Accept Loop ───

    private suspend fun acceptLoop() {
        val server = serverSocket ?: return

        while (scope.isActive) {
            try {
                val socket = withContext(Dispatchers.IO) {
                    server.accept() as SSLSocket
                }

                Log.i(TAG, "Inbound connection from ${socket.inetAddress.hostAddress}")

                // Handle in a new coroutine
                scope.launch {
                    handleInboundConnection(socket)
                }
            } catch (e: Exception) {
                if (scope.isActive) {
                    Log.e(TAG, "Accept failed: ${e.message}")
                }
                break
            }
        }
    }

    private suspend fun handleInboundConnection(socket: SSLSocket) {
        val codec = PacketCodec()
        val reader = BufferedReader(InputStreamReader(socket.inputStream, Charsets.UTF_8))
        val peerIp = socket.inetAddress.hostAddress ?: "unknown"
        val peerPort = socket.port

        try {
            // Wait for handshake (with timeout)
            val handshakePacket = withTimeoutOrNull(TetherConstants.HEARTBEAT_TIMEOUT_MS) {
                withContext(Dispatchers.IO) {
                    val line = reader.readLine() ?: throw Exception("Connection closed before handshake")
                    val packets = codec.decode("$line\n".toByteArray(Charsets.UTF_8))
                    packets.firstOrNull { it.type == PacketType.HANDSHAKE }
                }
            }

            if (handshakePacket == null) {
                Log.w(TAG, "No handshake received, closing inbound connection")
                socket.close()
                return
            }

            val peerDeviceId = handshakePacket.deviceId
            val handshake = HandshakePayload.fromMap(handshakePacket.payload)

            // Handshake collision guard: if we're already connecting as client,
            // compare UUIDs. Lower ID yields.
            if (state == ConnectionState.CONNECTING || state == ConnectionState.CONNECTED) {
                if (deviceId.compareTo(peerDeviceId) < 0) {
                    Log.i(TAG, "Handshake collision: my ID is lower, yielding server to peer")
                    socket.close()
                    return
                } else {
                    Log.i(TAG, "Handshake collision: my ID is higher, taking server role")
                    // Disconnect existing client connection
                    clientSocket?.close()
                    clientSocket = null
                    heartbeatJob?.cancel()
                    clientReaderJob?.cancel()
                }
            }

            // Send our handshake back
            sendPacket(
                socket,
                Packet(
                    type = PacketType.HANDSHAKE,
                    deviceId = deviceId,
                    payload = HandshakePayload(
                        name = deviceName,
                        platform = "Android",
                        version = TetherConstants.APP_VERSION
                    ).toMap()
                )
            )

            // We're now connected
            clientSocket = socket
            val device = ConnectedDevice(
                deviceId = peerDeviceId,
                name = handshake.name,
                platform = handshake.platform,
                ip = peerIp,
                port = peerPort
            )
            connectedDevice = device
            setState(ConnectionState.CONNECTED)
            listener.onDeviceConnected(device)

            // Store pairing record
            storePairingRecord(socket, peerDeviceId, handshake, peerIp, peerPort)

            // Start heartbeat and reading
            startHeartbeat(socket)
            readLoop(socket, codec, reader)
        } catch (e: Exception) {
            Log.e(TAG, "Inbound connection error: ${e.message}")
            try { socket.close() } catch (_: Exception) {}
            handleDisconnect()
        }
    }

    // ─── Client Reader ───

    private fun startClientReader(socket: SSLSocket, host: String, port: Int) {
        clientReaderJob = scope.launch {
            val codec = PacketCodec()
            val reader = BufferedReader(InputStreamReader(socket.inputStream, Charsets.UTF_8))

            try {
                // Wait for server's handshake response
                val firstLine = withContext(Dispatchers.IO) { reader.readLine() }
                    ?: throw Exception("Server closed before handshake response")

                val packets = codec.decode("$firstLine\n".toByteArray(Charsets.UTF_8))
                val handshakePacket = packets.firstOrNull { it.type == PacketType.HANDSHAKE }

                if (handshakePacket != null) {
                    val handshake = HandshakePayload.fromMap(handshakePacket.payload)
                    val device = ConnectedDevice(
                        deviceId = handshakePacket.deviceId,
                        name = handshake.name,
                        platform = handshake.platform,
                        ip = host,
                        port = port
                    )
                    connectedDevice = device
                    setState(ConnectionState.CONNECTED)
                    listener.onDeviceConnected(device)

                    // Store pairing record
                    storePairingRecord(socket, handshakePacket.deviceId, handshake, host, port)
                }

                readLoop(socket, codec, reader)
            } catch (e: Exception) {
                Log.e(TAG, "Client reader error: ${e.message}")
                handleDisconnect()
            }
        }
    }

    // ─── Shared Read Loop ───

    private suspend fun readLoop(
        socket: SSLSocket,
        codec: PacketCodec,
        reader: BufferedReader
    ) {
        try {
            while (scope.isActive && !socket.isClosed) {
                val line = withContext(Dispatchers.IO) { reader.readLine() }
                    ?: break // Connection closed

                val packets = codec.decode("$line\n".toByteArray(Charsets.UTF_8))
                for (packet in packets) {
                    handlePacket(packet)
                }
            }
        } catch (e: Exception) {
            if (scope.isActive) {
                Log.w(TAG, "Read loop terminated: ${e.message}")
            }
        }

        handleDisconnect()
    }

    // ─── Packet Handling ───

    private fun handlePacket(packet: Packet) {
        when (packet.type) {
            PacketType.HEARTBEAT -> {
                connectedDevice?.let { dev ->
                    val hb = HeartbeatPayload.fromMap(packet.payload)
                    dev.battery = hb.battery
                    dev.wifiStrength = hb.wifiStrength
                    dev.lastSeen = System.currentTimeMillis()
                }
            }

            PacketType.CLIPBOARD_UPDATE -> {
                val clipboard = ClipboardPayload.fromMap(packet.payload)
                listener.onClipboardReceived(clipboard.content, clipboard.dataType)
            }

            PacketType.NOTIFICATION -> {
                val notification = NotificationPayload.fromMap(packet.payload)
                listener.onNotificationReceived(notification)
            }

            PacketType.DISCONNECT -> {
                Log.i(TAG, "Peer sent DISCONNECT")
                scope.launch {
                    try { clientSocket?.close() } catch (_: Exception) {}
                    handleDisconnect()
                }
            }

            else -> {
                Log.d(TAG, "Received ${packet.type.wire} (not handled natively)")
            }
        }
    }

    // ─── Heartbeat ───

    private fun startHeartbeat(socket: SSLSocket) {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive && !socket.isClosed) {
                delay(TetherConstants.HEARTBEAT_INTERVAL_MS)
                try {
                    sendPacket(
                        socket,
                        Packet(
                            type = PacketType.HEARTBEAT,
                            deviceId = deviceId,
                            payload = HeartbeatPayload().toMap()
                        )
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Heartbeat send failed: ${e.message}")
                    break
                }
            }
        }
    }

    // ─── Reconnect ───

    private fun scheduleReconnect() {
        if (explicitDisconnect) return
        if (reconnectJob?.isActive == true) return

        reconnectJob = scope.launch {
            var attempts = 0
            while (attempts < TetherConstants.MAX_RECONNECT_ATTEMPTS && isActive) {
                delay(TetherConstants.RECONNECT_INTERVAL_MS)
                if (state == ConnectionState.CONNECTED) break

                setState(ConnectionState.SEARCHING)
                attempts++
                Log.d(TAG, "Reconnect attempt $attempts/${TetherConstants.MAX_RECONNECT_ATTEMPTS}")

                // Try all paired devices at their last known IP
                val pairedDevices = db.getPairedDevices()
                for (device in pairedDevices) {
                    val ip = device.lastIp ?: continue
                    val port = device.lastPort ?: TetherConstants.TCP_PORT

                    try {
                        val sslContext = TetherTlsManager.createTrustAllSSLContext()
                        val factory = sslContext.socketFactory as SSLSocketFactory
                        val socket = factory.createSocket() as SSLSocket

                        socket.connect(InetSocketAddress(ip, port), 3000)
                        socket.startHandshake()

                        // Success! Perform handshake
                        clientSocket = socket
                        sendPacket(
                            socket,
                            Packet(
                                type = PacketType.HANDSHAKE,
                                deviceId = deviceId,
                                payload = HandshakePayload(
                                    name = deviceName,
                                    platform = "Android",
                                    version = TetherConstants.APP_VERSION
                                ).toMap()
                            )
                        )

                        setState(ConnectionState.CONNECTING)
                        startClientReader(socket, ip, port)
                        startHeartbeat(socket)

                        Log.i(TAG, "Reconnected to ${device.name} @ $ip:$port")
                        return@launch
                    } catch (e: Exception) {
                        Log.d(TAG, "Reconnect to $ip:$port failed: ${e.message}")
                    }
                }
            }

            if (state != ConnectionState.CONNECTED) {
                Log.w(TAG, "Reconnection gave up after $attempts attempts")
                setState(ConnectionState.DISCONNECTED)
            }
        }
    }

    private fun handleDisconnect() {
        heartbeatJob?.cancel()
        clientReaderJob?.cancel()
        clientSocket = null
        connectedDevice = null
        setState(ConnectionState.DISCONNECTED)
        listener.onDeviceDisconnected()
        persistState()

        if (!explicitDisconnect) {
            scheduleReconnect()
        }
    }

    // ─── Helpers ───

    private fun sendPacket(socket: SSLSocket, packet: Packet) {
        try {
            val bytes = packet.encode()
            socket.outputStream.write(bytes)
            socket.outputStream.flush()
        } catch (e: Exception) {
            Log.w(TAG, "sendPacket(${packet.type.wire}) failed: ${e.message}")
            throw e
        }
    }

    private fun setState(newState: ConnectionState) {
        if (state == newState) return
        Log.i(TAG, "State: ${state.value} → ${newState.value}")
        state = newState
        listener.onConnectionStateChanged(newState.value)
        persistState()
    }

    private fun persistState() {
        try {
            db.setSetting("connection_state", state.value)
            val peer = connectedDevice
            if (peer != null) {
                val peerJson = JSONObject().apply {
                    put("deviceId", peer.deviceId)
                    put("name", peer.name)
                    put("platform", peer.platform)
                    put("ip", peer.ip)
                    put("port", peer.port)
                }
                db.setSetting("connected_peer", peerJson.toString())
            } else {
                db.setSetting("connected_peer", "")
            }
        } catch (e: Exception) {
            Log.w(TAG, "persistState failed: ${e.message}")
        }
    }

    private fun storePairingRecord(
        socket: SSLSocket,
        peerDeviceId: String,
        handshake: HandshakePayload,
        ip: String,
        port: Int
    ) {
        try {
            val peerCerts = socket.session.peerCertificates
            if (peerCerts.isNotEmpty()) {
                val peerCert = peerCerts[0] as X509Certificate
                val certPem = certToPem(peerCert)
                val fingerprint = TetherTlsManager.fingerprint(peerCert)

                db.upsertPairedDevice(
                    TetherDatabase.PairedDeviceRecord(
                        deviceId = peerDeviceId,
                        name = handshake.name,
                        platform = handshake.platform,
                        certPem = certPem,
                        certFingerprint = fingerprint,
                        lastIp = ip,
                        lastPort = port,
                        pairedAt = System.currentTimeMillis()
                    )
                )
                Log.i(TAG, "Stored pairing record for ${handshake.name} ($fingerprint)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to store pairing record: ${e.message}")
        }
    }

    private fun certToPem(cert: X509Certificate): String {
        val base64 = java.util.Base64.getMimeEncoder(64, "\n".toByteArray())
            .encodeToString(cert.encoded)
        return "-----BEGIN CERTIFICATE-----\n$base64\n-----END CERTIFICATE-----\n"
    }
}
