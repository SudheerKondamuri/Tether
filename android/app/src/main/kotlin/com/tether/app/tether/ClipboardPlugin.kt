package com.tether.app.tether

import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native clipboard listener for Android.
 * Uses ClipboardManager.OnPrimaryClipChangedListener to detect
 * clipboard changes even when the app is in the background.
 */
class ClipboardPlugin(private val context: Context) {
    companion object {
        private const val CHANNEL = "com.tether/clipboard"
    }

    private var channel: MethodChannel? = null
    private val clipboardManager =
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        val clip = clipboardManager.primaryClip
        if (clip != null && clip.itemCount > 0) {
            val text = clip.getItemAt(0).coerceToText(context).toString()
            channel?.invokeMethod("onClipboardChanged", mapOf("text" to text))
        }
    }

    fun register(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    clipboardManager.addPrimaryClipChangedListener(clipListener)

}}}}}
