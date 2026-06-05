package com.tether.app.tether

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service to keep the app alive for persistent connections.
 * Required on Android 8+ for long-running background TCP connections.
 */
class ForegroundServicePlugin : Service() {

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
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(intent)
                        } else {
                            context.startService(intent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        val intent = Intent(context, ForegroundServicePlugin::class.java)
                        context.stopService(intent)
                        result.success(true)

}}}}}}
