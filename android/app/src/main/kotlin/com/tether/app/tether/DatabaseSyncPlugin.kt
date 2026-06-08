package com.tether.app.tether

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine

/**
 * Formerly handled cross-process SQLite table invalidation via Android broadcasts.
 * Now a no-op stub — DriftIsolate handles all cross-isolate reactive stream
 * notifications natively through its built-in communication channel.
 */
object DatabaseSyncPlugin {
    fun register(engine: FlutterEngine, context: Context) { /* no-op */ }
    fun unregister(engine: FlutterEngine, context: Context) { /* no-op */ }
}
