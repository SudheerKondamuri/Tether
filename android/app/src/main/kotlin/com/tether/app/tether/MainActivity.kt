package com.tether.app.tether

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Force the Foreground Service to start natively immediately on boot
        val serviceIntent = Intent(this, ForegroundServicePlugin::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the MethodChannel cleanly
        ForegroundServicePlugin.register(flutterEngine, context)
        ClipboardPlugin(context).register(flutterEngine)
        NotificationPlugin.register(flutterEngine, context)
    }
}
