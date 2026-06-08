package com.tether.app.tether

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var clipboardPlugin: ClipboardPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Eagerly start the foreground service BEFORE Dart's main() runs.
        // This ensures the background engine is creating the DriftIsolate
        // database server before the UI isolate starts polling for it.
        startTetherService()

        // Register clipboard plugin
        clipboardPlugin = ClipboardPlugin(this)
        clipboardPlugin?.register(flutterEngine)

        // Register notification plugin
        NotificationPlugin.register(flutterEngine, this)

        // Register foreground service MethodChannel (for stopService, battery, etc.)
        ForegroundServicePlugin.register(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        clipboardPlugin?.unregister()
        NotificationPlugin.unregister()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun startTetherService() {
        try {
            val intent = Intent(this, ForegroundServicePlugin::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("Tether", "Failed to start foreground service: ${e.message}")
        }
    }
}
