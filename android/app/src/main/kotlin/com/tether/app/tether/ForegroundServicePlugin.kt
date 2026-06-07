package com.tether.app.tether

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
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
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                        val packageName = context.packageName
                        val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }
                        result.success(ignoring)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                            val packageName = context.packageName
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                context.startActivity(intent)
                                result.success(true)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(false)
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
        
        // Start the background engine unconditionally when service is created
        triggerBackgroundDartIsolate()
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
        } else {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        }
    }

    private fun triggerBackgroundDartIsolate() {
        if (backgroundEngine != null) return
        
        val loader = FlutterInjector.instance().flutterLoader()
        loader.ensureInitializationComplete(applicationContext, null)
        backgroundEngine = FlutterEngine(applicationContext)

        // Register JniFlutterPlugin (required by path_provider_android JNI FFI bindings)
        try {
            val jniClass = Class.forName("com.github.dart_lang.jni_flutter.JniFlutterPlugin")
            val jniPlugin = jniClass.getDeclaredConstructor().newInstance() as io.flutter.embedding.engine.plugins.FlutterPlugin
            backgroundEngine?.plugins?.add(jniPlugin)
        } catch (e: Exception) {
            android.util.Log.e("Tether", "Failed to register JniFlutterPlugin: ${e.message}")
        }

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

        // Register database synchronization plugin
        try {
            DatabaseSyncPlugin.register(backgroundEngine!!)
        } catch (e: Exception) {
            android.util.Log.e("Tether", "Failed to register DatabaseSyncPlugin: ${e.message}")
        }

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
        backgroundEngine?.let {
            DatabaseSyncPlugin.unregister(it)
            it.destroy()
        }
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Do NOT call stopSelf(). The service outlives the activity task stack.
        // This is intentionally empty to prevent the default behavior of
        // stopping the service when the user swipes the app from recents.
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
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
