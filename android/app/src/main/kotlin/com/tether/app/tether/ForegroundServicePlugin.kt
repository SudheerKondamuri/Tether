package com.tether.app.tether

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
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
    private var commandReceiver: BroadcastReceiver? = null

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
                    "openAutostartSettings" -> {
                        val opened = openAutostartSettings(context)
                        result.success(opened)
                    }
                    "sendBackgroundCommand" -> {
                        val command = call.argument<String>("command")
                        val args = call.argument<Map<String, Any>>("args")
                        val intent = Intent("com.tether.BACKGROUND_COMMAND").apply {
                            setPackage(context.packageName)
                            putExtra("command", command)
                            if (args != null) {
                                for ((key, value) in args) {
                                    when (value) {
                                        is String -> putExtra(key, value)
                                        is Int -> putExtra(key, value)
                                        is Long -> putExtra(key, value)
                                        is Double -> putExtra(key, value)
                                        is Boolean -> putExtra(key, value)
                                    }
                                }
                            }
                        }
                        context.sendBroadcast(intent, "com.tether.INTERNAL_BROADCAST")
                        result.success(true)
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

            // Always add a fallback intent to app details screen
            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
            }

            for (intent in intents) {
                try {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(intent)
                    return true
                } catch (_: Exception) {
                    // Try next one
                }
            }

            // Fallback
            return try {
                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(fallbackIntent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startNotificationForeground()
        initMulticastLock()
        registerNetworkTracking()
        
        // Register receiver for cross-process commands from the UI process
        val filter = IntentFilter("com.tether.BACKGROUND_COMMAND")
        commandReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "com.tether.BACKGROUND_COMMAND") {
                    val command = intent.getStringExtra("command")
                    
                    val argsMap = HashMap<String, Any>()
                    intent.extras?.let { extras ->
                        for (key in extras.keySet()) {
                            if (key != "command") {
                                extras.get(key)?.let { value ->
                                    argsMap[key] = value
                                }
                            }
                        }
                    }
                    
                    // Forward to background Dart engine
                    backgroundEngine?.let { engine ->
                        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.tether/foreground")
                        channel.invokeMethod("onBackgroundCommand", mapOf(
                            "command" to command,
                            "args" to argsMap
                        ))
                    }
                }
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(commandReceiver, filter, "com.tether.INTERNAL_BROADCAST", null, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(commandReceiver, filter, "com.tether.INTERNAL_BROADCAST", null)
        }
        
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
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        
        // Let Flutter automatically register all plugins via GeneratedPluginRegistrant.
        // This is strictly required so that path_provider, drift, jni_flutter, etc.
        // are properly initialized in the background engine.
        backgroundEngine = FlutterEngine(applicationContext)

        // Register custom MethodChannel plugins on background engine
        val clipboardPlugin = ClipboardPlugin(applicationContext)
        clipboardPlugin.register(backgroundEngine!!)
        NotificationPlugin.register(backgroundEngine!!, applicationContext)

        // Use 2-parameter DartEntrypoint — auto-resolves the default library.
        // The 3-parameter version with "lib/main.dart" fails in same-process
        // mode because the shared Dart VM registers libraries under package URIs
        // (package:tether/main.dart), not raw file paths.
        val entrypoint = DartExecutor.DartEntrypoint(
            loader.findAppBundlePath(),
            "backgroundMain"
        )
        backgroundEngine?.dartExecutor?.executeDartEntrypoint(entrypoint)
    }

    private fun teardownBackgroundDartIsolate() {
        backgroundEngine?.let {
            it.destroy()
        }
        backgroundEngine = null
    }

    override fun onDestroy() {
        if (multicastLock?.isHeld == true) multicastLock?.release()
        if (networkReceiver != null) {
            try {
                unregisterReceiver(networkReceiver)
            } catch (_: Exception) {}
        }
        commandReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        commandReceiver = null
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
