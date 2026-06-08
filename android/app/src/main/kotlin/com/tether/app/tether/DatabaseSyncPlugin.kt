package com.tether.app.tether

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.ArrayList

object DatabaseSyncPlugin {
    private const val CHANNEL = "com.tether/db_sync"
    private const val ACTION_DB_UPDATE = "com.tether.DATABASE_UPDATE"
    private const val PERMISSION_DB_UPDATE = "com.tether.INTERNAL_BROADCAST"

    private val activeEngines = mutableListOf<WeakReference<FlutterEngine>>()
    private var receiver: BroadcastReceiver? = null

    fun register(engine: FlutterEngine, context: Context) {
        synchronized(this) {
            // Clean up dead references
            activeEngines.removeAll { it.get() == null }
            // Add new reference if not already present
            if (activeEngines.none { it.get() == engine }) {
                activeEngines.add(WeakReference(engine))
            }

            if (receiver == null) {
                receiver = object : BroadcastReceiver() {
                    override fun onReceive(ctx: Context, intent: Intent) {
                        if (intent.action == ACTION_DB_UPDATE) {
                            val tables = intent.getStringArrayListExtra("tables")
                            if (tables != null) {
                                // Forward to all engines in this process
                                synchronized(DatabaseSyncPlugin) {
                                    activeEngines.removeAll { it.get() == null }
                                    for (ref in activeEngines) {
                                        val eng = ref.get() ?: continue
                                        val channel = MethodChannel(eng.dartExecutor.binaryMessenger, CHANNEL)
                                        channel.invokeMethod("onTableUpdate", mapOf("tables" to tables))
                                    }
                                }
                            }
                        }
                    }
                }

                val filter = IntentFilter(ACTION_DB_UPDATE)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    context.registerReceiver(
                        receiver,
                        filter,
                        PERMISSION_DB_UPDATE,
                        null,
                        Context.RECEIVER_NOT_EXPORTED
                    )
                } else {
                    context.registerReceiver(
                        receiver,
                        filter,
                        PERMISSION_DB_UPDATE,
                        null
                    )
                }
            }
        }

        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "notifyTableUpdate") {
                val tables = call.argument<List<String>>("tables")
                if (tables != null) {
                    broadcastTableUpdate(context, tables)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    fun unregister(engine: FlutterEngine, context: Context) {
        synchronized(this) {
            activeEngines.removeAll { it.get() == engine || it.get() == null }
            if (activeEngines.isEmpty() && receiver != null) {
                try {
                    context.unregisterReceiver(receiver)
                } catch (_: Exception) {}
                receiver = null
            }
        }
    }

    private fun broadcastTableUpdate(context: Context, tables: List<String>) {
        val intent = Intent(ACTION_DB_UPDATE).apply {
            setPackage(context.packageName)
            putStringArrayListExtra("tables", ArrayList(tables))
        }
        context.sendBroadcast(intent, PERMISSION_DB_UPDATE)
    }
}
