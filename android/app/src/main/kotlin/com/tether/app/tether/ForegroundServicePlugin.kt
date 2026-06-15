package com.tether.app.tether

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that runs the native Kotlin networking layer.
 *
 * Architecture: KDE Connect model — all TCP sockets, TLS handshakes, UDP/mDNS
 * discovery, heartbeats, and auto-reconnection run natively in Kotlin Coroutines.
 * The Flutter/Dart layer is strictly a UI remote control that sends commands
 * via MethodChannel and reads state from SQLite.
 *
 * Survives:
 * - LMKD (Low Memory Killer Daemon) — native service, no Dart VM to kill
 * - Doze — holds PARTIAL_WAKE_LOCK + WIFI_MODE_FULL_HIGH_PERF
 * - Task eviction — stopWithTask=false in manifest, onTaskRemoved is no-op
 */
class ForegroundServicePlugin : Service(),
    NativeConnectionManager.ConnectionListener,
    NativeDiscovery.DiscoveryListener {

    companion object {
        private const val TAG = "TetherService"
        private const val CHANNEL = "com.tether/foreground"
        private const val NOTIFICATION_CHANNEL_ID = "tether_foreground"
        private const val NOTIFICATION_ID = 1

        // Static reference for MethodChannel bridge from UI
        private var connectionManager: NativeConnectionManager? = null
        private var discovery: NativeDiscovery? = null

        /**
         * Register the MethodChannel on the UI FlutterEngine.
         * Called from [MainActivity.configureFlutterEngine].
         */
        fun register(engine: FlutterEngine, context: Context) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(context, ForegroundServicePlugin::class.java)
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(intent)
                            } else {
                                context.startService(intent)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "stopService" -> {
                        val intent = Intent(context, ForegroundServicePlugin::class.java)
                        context.stopService(intent)
                        result.success(true)
                    }
                    "connectTo" -> {
                        val host = call.argument<String>("host")
                        val port = call.argument<Int>("port") ?: TetherConstants.TCP_PORT
                        if (host != null) {
                            connectionManager?.connectTo(host, port)
                            result.success(true)
                        } else {
                            result.error("ARGS", "host is required", null)
                        }
                    }
                    "disconnect" -> {
                        connectionManager?.disconnect()
                        result.success(true)
                    }
                    "getConnectionState" -> {
                        result.success(connectionManager?.getConnectionState() ?: "disconnected")
                    }
                    "getPeerInfo" -> {
                        result.success(connectionManager?.getConnectedDeviceInfo())
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(context.packageName)
                        } else {
                            true
                        }
                        result.success(ignoring)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(context.packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:${context.packageName}")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                context.startActivity(intent)
                                result.success(true)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(false)
                    }
                    "openAutostartSettings" -> {
                        val opened = openAutostartSettings(context)
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        private fun openAutostartSettings(context: Context): Boolean {
            val manufacturer = Build.MANUFACTURER.lowercase()
            val intents = mutableListOf<Intent>()

            when {
                manufacturer.contains("xiaomi") -> {
                    intents.add(Intent().apply {
                        component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    })
                }
                manufacturer.contains("oppo") -> {
                    intents.add(Intent().apply {
                        component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startupapp.StartupAppListActivity")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.FakeActivity")
                    })
                }
                manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                    intents.add(Intent().apply {
                        component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
                    })
                }
                manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                    intents.add(Intent().apply {
                        component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                    })
                    intents.add(Intent().apply {
                        component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")
                    })
                }
                manufacturer.contains("oneplus") -> {
                    intents.add(Intent().apply {
                        component = ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
                    })
                }
            }

            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }

            for (intent in intents) {
                try {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(intent)
                    return true
                } catch (_: Exception) {}
            }

            return try {
                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(fallbackIntent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    // ─── OS Locks ───
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var networkReceiver: BroadcastReceiver? = null
    private var isHotspotEnabled = false

    // ─── Native Clipboard Monitor ───
    private var clipboardManager: ClipboardManager? = null
    private var lastClipContent: String = ""
    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        handleClipboardChange()
    }

    // ─── Service Lifecycle ───

    override fun onCreate() {
        super.onCreate()
        startNotificationForeground()
        acquireAllLocks()
        registerNetworkTracking()
        startNativeNetworking()
        startClipboardMonitor()
        Log.i(TAG, "Service created — native networking started")
    }

    override fun onDestroy() {
        Log.i(TAG, "Service destroying")
        stopClipboardMonitor()
        stopNativeNetworking()
        releaseAllLocks()
        unregisterNetworkTracking()
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Intentionally empty — service outlives the activity task.
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── Native Networking ───

    private fun startNativeNetworking() {
        val db = TetherDatabase.getInstance(applicationContext)

        val connMgr = NativeConnectionManager(applicationContext, this)
        connectionManager = connMgr
        connMgr.startServer()

        val disco = NativeDiscovery(
            context = applicationContext,
            deviceId = db.getDeviceId(),
            deviceName = db.getDeviceName(),
            listener = this
        )
        discovery = disco
        disco.start()
    }

    private fun stopNativeNetworking() {
        discovery?.stop()
        discovery = null

        connectionManager?.shutdown()
        connectionManager = null
    }

    // ─── ConnectionListener Callbacks ───

    override fun onConnectionStateChanged(state: String) {
        Log.i(TAG, "Connection state: $state")
        updateNotification(state)
    }

    override fun onDeviceConnected(device: NativeConnectionManager.ConnectedDevice) {
        Log.i(TAG, "Connected to ${device.name} (${device.platform}) @ ${device.ip}")
        updateNotification("Connected to ${device.name}")
    }

    override fun onDeviceDisconnected() {
        Log.i(TAG, "Disconnected")
        updateNotification("disconnected")
    }

    override fun onClipboardReceived(content: String, dataType: String) {
        Log.d(TAG, "Clipboard received: ${content.take(50)}...")
        // Set the clipboard content natively
        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            lastClipContent = content // Prevent echo
            val clip = ClipData.newPlainText("Tether", content)
            cm.setPrimaryClip(clip)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set clipboard: ${e.message}")
        }
    }

    override fun onNotificationReceived(payload: NotificationPayload) {
        Log.d(TAG, "Notification received: ${payload.title}")
        // TODO: Display notification via NotificationManager
    }

    // ─── DiscoveryListener Callbacks ───

    override fun onPeerDiscovered(peer: NativeDiscovery.DiscoveredPeer) {
        Log.i(TAG, "Peer discovered: ${peer.name} @ ${peer.ip}:${peer.port}")
        connectionManager?.onPeerDiscovered(peer)
    }

    // ─── Native Clipboard Monitor ───

    private fun startClipboardMonitor() {
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        clipboardManager?.addPrimaryClipChangedListener(clipboardListener)
        Log.d(TAG, "Clipboard monitor started")
    }

    private fun stopClipboardMonitor() {
        clipboardManager?.removePrimaryClipChangedListener(clipboardListener)
        clipboardManager = null
    }

    private fun handleClipboardChange() {
        try {
            val cm = clipboardManager ?: return
            if (!cm.hasPrimaryClip()) return

            val clip = cm.primaryClip ?: return
            if (clip.itemCount == 0) return

            val content = clip.getItemAt(0)?.text?.toString() ?: return
            if (content == lastClipContent) return // Skip echo
            if (content.isBlank()) return

            lastClipContent = content
            connectionManager?.sendClipboard(content)
        } catch (e: Exception) {
            Log.w(TAG, "Clipboard change error: ${e.message}")
        }
    }

    // ─── OS Locks ───

    private fun acquireAllLocks() {
        // WakeLock — prevent CPU sleep
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Tether::WakeLock"
        ).apply {
            acquire()
        }

        // WifiLock — prevent WiFi radio sleep
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        wifiLock = wifiManager.createWifiLock(
            WifiManager.WIFI_MODE_FULL_HIGH_PERF,
            "Tether::WifiLock"
        ).apply {
            acquire()
        }

        // MulticastLock — required for mDNS/NSD
        multicastLock = wifiManager.createMulticastLock("Tether::MulticastLock").apply {
            setReferenceCounted(false)
            acquire()
        }

        Log.i(TAG, "All OS locks acquired")
    }

    private fun releaseAllLocks() {
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (_: Exception) {}
        try { if (wifiLock?.isHeld == true) wifiLock?.release() } catch (_: Exception) {}
        try { if (multicastLock?.isHeld == true) multicastLock?.release() } catch (_: Exception) {}
        wakeLock = null
        wifiLock = null
        multicastLock = null
        Log.i(TAG, "All OS locks released")
    }

    // ─── Network Tracking ───

    private fun registerNetworkTracking() {
        isHotspotEnabled = checkCurrentHotspotState()

        val filter = IntentFilter().apply {
            addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            @Suppress("DEPRECATION")
            addAction("android.net.wifi.WIFI_AP_STATE_CHANGED")
        }

        networkReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if ("android.net.wifi.WIFI_AP_STATE_CHANGED" == intent.action) {
                    val state = intent.getIntExtra("wifi_state", 11)
                    isHotspotEnabled = (state == 13)
                }

                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                @Suppress("DEPRECATION")
                val activeNetwork = cm.activeNetworkInfo
                @Suppress("DEPRECATION")
                val isWifiConnected = activeNetwork != null && activeNetwork.type == ConnectivityManager.TYPE_WIFI

                manageNetworkPipeline(enabled = isWifiConnected || isHotspotEnabled)
            }
        }
        registerReceiver(networkReceiver, filter)
    }

    private fun unregisterNetworkTracking() {
        networkReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        networkReceiver = null
    }

    private fun manageNetworkPipeline(enabled: Boolean) {
        if (enabled) {
            if (multicastLock?.isHeld == false) multicastLock?.acquire()
        } else {
            if (multicastLock?.isHeld == true) multicastLock?.release()
        }
    }

    private fun checkCurrentHotspotState(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method = wifiManager.javaClass.getMethod("getWifiApState")
            val state = method.invoke(wifiManager) as Int
            state == 13
        } catch (_: Exception) {
            false
        }
    }

    // ─── Notification ───

    private fun startNotificationForeground() {
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Tether")
            .setContentText("Background sync active")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(status: String) {
        val text = when (status) {
            "connected" -> "Connected"
            "searching" -> "Searching for peers..."
            "connecting" -> "Connecting..."
            "disconnected" -> "Background sync active"
            else -> status
        }

        try {
            val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Tether")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()

            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update notification: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Tether Connection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Tether connected to your peer device"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
