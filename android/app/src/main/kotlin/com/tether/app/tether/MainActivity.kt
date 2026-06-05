package com.tether.app.tether

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var clipboardPlugin: ClipboardPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register clipboard plugin
        clipboardPlugin = ClipboardPlugin(this)
        clipboardPlugin?.register(flutterEngine)

        // Register notification plugin
        NotificationPlugin.register(flutterEngine, this)

        // Register foreground service plugin
        ForegroundServicePlugin.register(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        clipboardPlugin?.unregister()
        NotificationPlugin.unregister()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
