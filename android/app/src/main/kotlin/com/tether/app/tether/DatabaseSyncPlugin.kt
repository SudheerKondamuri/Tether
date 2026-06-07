package com.tether.app.tether

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

object DatabaseSyncPlugin {
    private const val CHANNEL = "com.tether/db_sync"
    private val activeEngines = mutableListOf<WeakReference<FlutterEngine>>()

    fun register(engine: FlutterEngine) {
        synchronized(this) {
            // Clean up dead references
            activeEngines.removeAll { it.get() == null }
            // Add new reference if not already present
            if (activeEngines.none { it.get() == engine }) {
                activeEngines.add(WeakReference(engine))
            }
        }

        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "notifyTableUpdate") {
                val tables = call.argument<List<String>>("tables")
                if (tables != null) {
                    broadcastTableUpdate(engine, tables)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    fun unregister(engine: FlutterEngine) {
        synchronized(this) {
            activeEngines.removeAll { it.get() == engine || it.get() == null }
        }
    }

    private fun broadcastTableUpdate(sender: FlutterEngine, tables: List<String>) {
        val targets = synchronized(this) {
            activeEngines.removeAll { it.get() == null }
            activeEngines.mapNotNull { it.get() }.filter { it != sender }
        }
        
        for (engine in targets) {
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.invokeMethod("onTableUpdate", mapOf("tables" to tables))
        }
    }
}
