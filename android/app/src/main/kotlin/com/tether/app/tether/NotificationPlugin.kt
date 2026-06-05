package com.tether.app.tether

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * NotificationListenerService that forwards Android notifications to Flutter.
 */
class NotificationPlugin : NotificationListenerService() {

    companion object {
        private const val CHANNEL = "com.tether/notifications"
        var channel: MethodChannel? = null
        var isListening = false

        fun register(engine: FlutterEngine, context: Context) {
            channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> {
                        result.success(isNotificationAccessGranted(context))
                    }
                    "requestPermission" -> {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    }
                    "startListening" -> {
                        isListening = true
                        result.success(true)
                    }
                    "stopListening" -> {
                        isListening = false
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        fun unregister() {
            channel?.setMethodCallHandler(null)
            channel = null
        }

        private fun isNotificationAccessGranted(context: Context): Boolean {
            val cn = ComponentName(context, NotificationPlugin::class.java)
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            return flat != null && flat.contains(cn.flattenToString())
        }


}}
