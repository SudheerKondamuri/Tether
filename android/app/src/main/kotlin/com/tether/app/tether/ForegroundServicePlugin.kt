package com.tether.app.tether

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.FlutterInjector

/**
 * Foreground service to keep the app alive for persistent connections.
 * Runs a headless background FlutterEngine to manage sockets and sync independent of UI.
 */
class ForegroundServicePlugin : Service() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var backgroundEngine: FlutterEngine? = null
    private var networkReceiver: BroadcastReceiver? = null
    private var isHotspotEnabled = false

    private fun checkCurrentHotspotState(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method = wifiManager.javaClass.getMethod("getWifiApState")
            val state = method.invoke(wifiManager) as Int
            state == 13 // 13 = WIFI_AP_STATE_ENABLED
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "com.tether/foreground"
        private const val NOTIFICATION_CHANNEL_ID = "tether_foreground"
        private const val NOTIFICATION_ID = 1

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
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startNotificationForeground()
        initMulticastLock()
        registerNetworkTracking()
        
        // Trigger initial network state check
        val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        @Suppress("DEPRECATION")
        val activeNetwork = cm.activeNetworkInfo
        @Suppress("DEPRECATION")
        val isWifiConnected = activeNetwork != null && activeNetwork.type == ConnectivityManager.TYPE_WIFI
        manageNetworkPipeline(enabled = isWifiConnected || isHotspotEnabled)
    }

    private fun initMulticastLock() {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifiManager.createMulticastLock("Tether::MulticastLock").apply {
            setReferenceCounted(false)
        }
    }

    private fun registerNetworkTracking() {
        isHotspotEnabled = checkCurrentHotspotState()

        val filter = IntentFilter().apply {
            addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            @Suppress("DEPRECATION")
            addAction("android.net.wifi.WIFI_AP_STATE_CHANGED")
        }

        networkReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val action = intent.action
                if ("android.net.wifi.WIFI_AP_STATE_CHANGED" == action) {
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

    private fun manageNetworkPipeline(enabled: Boolean) {
        if (enabled) {
            if (multicastLock?.isHeld == false) {
                multicastLock?.acquire()
            }
            triggerBackgroundDartIsolate()
        } else {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
            teardownBackgroundDartIsolate()
        }
    }

    private fun triggerBackgroundDartIsolate() {
        if (backgroundEngine != null) return
        
        val loader = FlutterInjector.instance().flutterLoader()
        loader.ensureInitializationComplete(applicationContext, null)
        backgroundEngine = FlutterEngine(applicationContext)

        // Manually register only the necessary plugins to save RAM
        try {
            val pathProviderClass = Class.forName("dev.flutter.plugins.pathprovider.PathProviderPlugin")
            val pathProviderPlugin = pathProviderClass.getDeclaredConstructor().newInstance() as io.flutter.embedding.engine.plugins.FlutterPlugin
            backgroundEngine?.plugins?.add(pathProviderPlugin)
        } catch (_: Exception) {}

        try {
            val bonsoirClass = Class.forName("fr.skyost.bonsoir.BonsoirPlugin")
            val bonsoirPlugin = bonsoirClass.getDeclaredConstructor().newInstance() as io.flutter.embedding.engine.plugins.FlutterPlugin
            backgroundEngine?.plugins?.add(bonsoirPlugin)
        } catch (_: Exception) {}

        // Register custom MethodChannel plugins on background engine
        val clipboardPlugin = ClipboardPlugin(applicationContext)
        clipboardPlugin.register(backgroundEngine!!)
        NotificationPlugin.register(backgroundEngine!!, applicationContext)

        val entrypoint = DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(),
            "lib/main.dart",
            "backgroundMain"
        )
        backgroundEngine?.dartExecutor?.executeDartEntrypoint(entrypoint)
    }

    private fun teardownBackgroundDartIsolate() {
        backgroundEngine?.destroy()
        backgroundEngine = null
    }

    override fun onDestroy() {
        if (multicastLock?.isHeld == true) multicastLock?.release()
        if (networkReceiver != null) {
            unregisterReceiver(networkReceiver)
        }
        teardownBackgroundDartIsolate()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startNotificationForeground() {
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Tether")
            .setContentText("Background sync active")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
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
