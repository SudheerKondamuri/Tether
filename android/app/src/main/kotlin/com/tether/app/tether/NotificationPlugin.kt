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

        private fun drawableToBitmap(drawable: Drawable): Bitmap {
            if (drawable is BitmapDrawable) return drawable.bitmap
            val bmp = Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(1),
                drawable.intrinsicHeight.coerceAtLeast(1),
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            return bmp
        }

        private fun bitmapToBase64(bitmap: Bitmap, maxSize: Int = 64): String {
            val scaled = Bitmap.createScaledBitmap(bitmap, maxSize, maxSize, true)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 80, stream)
            return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isListening) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return
        val appName = try {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(
                pm.getApplicationInfo(sbn.packageName, 0)
            ).toString()
        } catch (_: Exception) {
            sbn.packageName
        }

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val body = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

        if (title.isEmpty() && body.isEmpty()) return

        // Get app icon as base64
        val iconBase64 = try {
            val pm = applicationContext.packageManager
            val icon = pm.getApplicationIcon(sbn.packageName)
            bitmapToBase64(drawableToBitmap(icon))
        } catch (_: Exception) {
            null
        }

        val data = mapOf(
            "app_name" to appName,
            "package" to sbn.packageName,
            "title" to title,
            "body" to body,
            "icon" to iconBase64,
            "timestamp" to sbn.postTime,
        )

        channel?.invokeMethod("onNotificationPosted", data)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (!isListening) return
        channel?.invokeMethod("onNotificationRemoved", mapOf(
            "package" to sbn.packageName,
            "key" to sbn.key,
        ))
    }
}
