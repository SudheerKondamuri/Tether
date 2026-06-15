package com.tether.app.tether

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.SocketTimeoutException
import java.security.MessageDigest

/**
 * Native UDP broadcast + NSD (mDNS) discovery engine.
 *
 * Replaces the Dart `MdnsDiscovery` class with pure Android APIs:
 * - [NsdManager] for mDNS service registration and browsing
 * - [DatagramSocket] for UDP broadcast pings and subnet sweeps
 *
 * Discovered peers are reported to the [listener] callback.
 */
class NativeDiscovery(
    private val context: Context,
    private val deviceId: String,
    private val deviceName: String,
    private val listener: DiscoveryListener
) {

    companion object {
        private const val TAG = "NativeDiscovery"
        private const val UDP_PING_PREFIX = "TETHER_DISCOVER:"
        private const val UDP_REPLY_PREFIX = "TETHER_REPLY:"
        private const val UDP_BUFFER_SIZE = 1024
        /** After this many empty UDP ping cycles, start unicast sweep */
        private const val SWEEP_TRIGGER_CYCLES = 3
    }

    interface DiscoveryListener {
        fun onPeerDiscovered(peer: DiscoveredPeer)
    }

    data class DiscoveredPeer(
        val name: String,
        val ip: String,
        val port: Int,
        val nonce: Int,
        val discoveryHash: String
    )

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var nsdManager: NsdManager? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryBrowseListener: NsdManager.DiscoveryListener? = null
    private var udpListenerSocket: DatagramSocket? = null
    private var udpSenderSocket: DatagramSocket? = null
    private var udpPingJob: Job? = null
    private var udpListenJob: Job? = null
    private var nonce: Int = (0..10_000_000).random()
    private var emptyCycles = 0
    @Volatile
    private var isRunning = false

    // ─── Public API ───

    /**
     * Start both NSD registration/browsing and UDP broadcast discovery.
     */
    fun start() {
        if (isRunning) {
            Log.w(TAG, "Discovery already running")
            return
        }
        isRunning = true
        emptyCycles = 0
        nonce = (0..10_000_000).random()

        startNsd()
        startUdpListener()
        startUdpPinger()

        Log.i(TAG, "Discovery started (nonce=$nonce)")
    }

    /**
     * Stop all discovery mechanisms and release resources.
     */
    fun stop() {
        if (!isRunning) return
        isRunning = false

        stopNsd()
        stopUdp()
        scope.coroutineContext[Job]?.cancelChildren()

        Log.i(TAG, "Discovery stopped")
    }

    // ─── Discovery Hash (identical to Dart CryptoUtils) ───

    /**
     * Compute discovery hash: `SHA256("deviceId:epoch").substring(0, 16)`
     * where epoch = `System.currentTimeMillis() / (5 * 60 * 1000)`.
     */
    private fun computeDiscoveryHash(): String {
        val epoch = System.currentTimeMillis() / (5 * 60 * 1000)
        return sha256Hex("$deviceId:$epoch").substring(0, 16)
    }

    /**
     * Verify a peer's discovery hash against known device IDs.
     * Checks both current and previous epoch to handle boundary transitions.
     */
    fun verifyDiscoveryHash(hash: String, knownDeviceIds: List<String>): Boolean {
        val currentEpoch = System.currentTimeMillis() / (5 * 60 * 1000)
        for (id in knownDeviceIds) {
            val currentHash = sha256Hex("$id:$currentEpoch").substring(0, 16)
            if (currentHash == hash) return true
            val prevHash = sha256Hex("$id:${currentEpoch - 1}").substring(0, 16)
            if (prevHash == hash) return true
        }
        return false
    }

    private fun sha256Hex(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }
    }

    // ─── NSD (mDNS) ───

    private fun startNsd() {
        try {
            nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager

            // Register our service
            val serviceInfo = NsdServiceInfo().apply {
                serviceName = deviceName
                serviceType = TetherConstants.MDNS_SERVICE_TYPE
                port = TetherConstants.TCP_PORT
                setAttribute("nonce", nonce.toString())
                setAttribute("dh", computeDiscoveryHash())
            }

            registrationListener = object : NsdManager.RegistrationListener {
                override fun onRegistrationFailed(si: NsdServiceInfo, errorCode: Int) {
                    Log.e(TAG, "NSD registration failed: $errorCode")
                }
                override fun onUnregistrationFailed(si: NsdServiceInfo, errorCode: Int) {
                    Log.e(TAG, "NSD unregistration failed: $errorCode")
                }
                override fun onServiceRegistered(si: NsdServiceInfo) {
                    Log.i(TAG, "NSD service registered: ${si.serviceName}")
                }
                override fun onServiceUnregistered(si: NsdServiceInfo) {
                    Log.d(TAG, "NSD service unregistered")
                }
            }

            nsdManager?.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)

            // Browse for peers
            discoveryBrowseListener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(serviceType: String) {
                    Log.d(TAG, "NSD browse started for $serviceType")
                }
                override fun onDiscoveryStopped(serviceType: String) {
                    Log.d(TAG, "NSD browse stopped")
                }
                override fun onServiceFound(si: NsdServiceInfo) {
                    Log.d(TAG, "NSD service found: ${si.serviceName}")
                    // Don't resolve our own service
                    if (si.serviceName == deviceName) return
                    resolveNsdService(si)
                }
                override fun onServiceLost(si: NsdServiceInfo) {
                    Log.d(TAG, "NSD service lost: ${si.serviceName}")
                }
                override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                    Log.e(TAG, "NSD browse start failed: $errorCode")
                }
                override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                    Log.e(TAG, "NSD browse stop failed: $errorCode")
                }
            }

            nsdManager?.discoverServices(
                TetherConstants.MDNS_SERVICE_TYPE,
                NsdManager.PROTOCOL_DNS_SD,
                discoveryBrowseListener
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start NSD", e)
        }
    }

    private fun resolveNsdService(serviceInfo: NsdServiceInfo) {
        try {
            nsdManager?.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                override fun onResolveFailed(si: NsdServiceInfo, errorCode: Int) {
                    Log.w(TAG, "NSD resolve failed for ${si.serviceName}: $errorCode")
                }

                override fun onServiceResolved(si: NsdServiceInfo) {
                    val host = si.host?.hostAddress ?: return
                    val port = si.port
                    val peerNonce = si.attributes?.get("nonce")?.let {
                        String(it).toIntOrNull()
                    } ?: 0
                    val peerHash = si.attributes?.get("dh")?.let {
                        String(it)
                    } ?: ""

                    Log.i(TAG, "NSD resolved: ${si.serviceName} @ $host:$port")

                    listener.onPeerDiscovered(
                        DiscoveredPeer(
                            name = si.serviceName,
                            ip = host,
                            port = port,
                            nonce = peerNonce,
                            discoveryHash = peerHash
                        )
                    )
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "NSD resolve error", e)
        }
    }

    private fun stopNsd() {
        try {
            registrationListener?.let { nsdManager?.unregisterService(it) }
        } catch (e: Exception) {
            Log.w(TAG, "NSD unregister failed: ${e.message}")
        }
        try {
            discoveryBrowseListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (e: Exception) {
            Log.w(TAG, "NSD stop browse failed: ${e.message}")
        }
        registrationListener = null
        discoveryBrowseListener = null
        nsdManager = null
    }

    // ─── UDP Discovery ───

    private fun startUdpListener() {
        udpListenJob = scope.launch {
            try {
                udpListenerSocket = DatagramSocket(null).apply {
                    reuseAddress = true
                    bind(InetSocketAddress(TetherConstants.UDP_PORT))
                    soTimeout = 5000
                }

                Log.d(TAG, "UDP listener started on port ${TetherConstants.UDP_PORT}")

                while (isActive && isRunning) {
                    try {
                        val buffer = ByteArray(UDP_BUFFER_SIZE)
                        val packet = DatagramPacket(buffer, buffer.size)
                        udpListenerSocket?.receive(packet)

                        val message = String(packet.data, 0, packet.length, Charsets.UTF_8)
                        val senderIp = packet.address.hostAddress ?: continue

                        handleUdpMessage(message, senderIp)
                    } catch (_: SocketTimeoutException) {
                        // Normal — just loop back
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.w(TAG, "UDP receive error: ${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "UDP listener failed to start", e)
            }
        }
    }

    private fun handleUdpMessage(message: String, senderIp: String) {
        when {
            message.startsWith(UDP_PING_PREFIX) -> {
                // Someone is looking for us — send a reply
                val peerNonce = message.removePrefix(UDP_PING_PREFIX).trim().toIntOrNull() ?: return
                if (peerNonce == nonce) return // Ignore our own broadcast

                val discoveryHash = computeDiscoveryHash()
                val reply = "$UDP_REPLY_PREFIX$deviceName:${TetherConstants.TCP_PORT}:$nonce:$discoveryHash"

                scope.launch {
                    try {
                        val replyBytes = reply.toByteArray(Charsets.UTF_8)
                        val replyPacket = DatagramPacket(
                            replyBytes, replyBytes.size,
                            InetAddress.getByName(senderIp),
                            TetherConstants.UDP_PORT
                        )
                        udpSenderSocket?.send(replyPacket)
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to send UDP reply: ${e.message}")
                    }
                }
            }

            message.startsWith(UDP_REPLY_PREFIX) -> {
                // Parse: TETHER_REPLY:<name>:<port>:<nonce>:<hash>
                val parts = message.removePrefix(UDP_REPLY_PREFIX).split(":")
                if (parts.size < 4) return

                val peerName = parts[0]
                val peerPort = parts[1].toIntOrNull() ?: TetherConstants.TCP_PORT
                val peerNonce = parts[2].toIntOrNull() ?: return
                val peerHash = parts[3]

                if (peerNonce == nonce) return // Ignore self

                emptyCycles = 0 // Got a reply — reset sweep counter

                listener.onPeerDiscovered(
                    DiscoveredPeer(
                        name = peerName,
                        ip = senderIp,
                        port = peerPort,
                        nonce = peerNonce,
                        discoveryHash = peerHash
                    )
                )
            }
        }
    }

    private fun startUdpPinger() {
        udpPingJob = scope.launch {
            try {
                udpSenderSocket = DatagramSocket().apply {
                    broadcast = true
                }

                while (isActive && isRunning) {
                    delay(3000) // 3-second ping interval

                    val pingMessage = "$UDP_PING_PREFIX$nonce"
                    val pingBytes = pingMessage.toByteArray(Charsets.UTF_8)

                    // Try broadcast first
                    try {
                        val broadcastPacket = DatagramPacket(
                            pingBytes, pingBytes.size,
                            InetAddress.getByName("255.255.255.255"),
                            TetherConstants.UDP_PORT
                        )
                        udpSenderSocket?.send(broadcastPacket)
                    } catch (e: Exception) {
                        // Broadcast may be blocked (hotspot) — fall through to sweep
                        Log.d(TAG, "Broadcast ping failed, will use unicast: ${e.message}")
                    }

                    emptyCycles++

                    // After SWEEP_TRIGGER_CYCLES without a reply, do a subnet sweep
                    if (emptyCycles >= SWEEP_TRIGGER_CYCLES) {
                        emptyCycles = 0
                        subnetSweep(pingBytes)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "UDP pinger failed", e)
            }
        }
    }

    /**
     * Sends the UDP discovery ping to every IP on the local /24 subnet.
     */
    private suspend fun subnetSweep(pingBytes: ByteArray) {
        try {
            val localIp = getLocalIpAddress() ?: return
            val parts = localIp.split(".")
            if (parts.size != 4) return

            val subnet = "${parts[0]}.${parts[1]}.${parts[2]}"
            Log.d(TAG, "Subnet sweep: $subnet.0/24")

            for (i in 1..254) {
                if (!isRunning) break
                try {
                    val target = InetAddress.getByName("$subnet.$i")
                    val packet = DatagramPacket(
                        pingBytes, pingBytes.size,
                        target, TetherConstants.UDP_PORT
                    )
                    udpSenderSocket?.send(packet)
                } catch (_: Exception) {
                    // Ignore individual send failures
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Subnet sweep failed: ${e.message}")
        }
    }

    private fun stopUdp() {
        udpPingJob?.cancel()
        udpListenJob?.cancel()
        udpPingJob = null
        udpListenJob = null

        try { udpListenerSocket?.close() } catch (_: Exception) {}
        try { udpSenderSocket?.close() } catch (_: Exception) {}
        udpListenerSocket = null
        udpSenderSocket = null
    }

    // ─── Utility ───

    private fun getLocalIpAddress(): String? {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val wifiInfo = wifiManager?.connectionInfo
            val ipInt = wifiInfo?.ipAddress ?: 0
            if (ipInt != 0) {
                return "${ipInt and 0xFF}.${(ipInt shr 8) and 0xFF}.${(ipInt shr 16) and 0xFF}.${(ipInt shr 24) and 0xFF}"
            }
        } catch (_: Exception) {}

        // Fallback to NetworkInterface scan
        try {
            for (iface in NetworkInterface.getNetworkInterfaces()) {
                if (iface.isLoopback || !iface.isUp) continue
                for (addr in iface.inetAddresses) {
                    if (addr.isLoopbackAddress) continue
                    val ip = addr.hostAddress ?: continue
                    if (ip.contains(".")) return ip // Return first IPv4
                }
            }
        } catch (_: Exception) {}

        return null
    }
}
