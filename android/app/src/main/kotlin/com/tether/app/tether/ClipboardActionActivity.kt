package com.tether.app.tether

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.widget.Toast

/**
 * A transparent activity launched from the foreground service notification.
 * Since Android 10+ restricts background apps from reading the clipboard,
 * launching this short-lived transparent activity places us in the foreground
 * state, allowing us to read the clipboard and sync it to the peer.
 */
class ClipboardActionActivity : Activity() {

    companion object {
        private const val TAG = "ClipboardAction"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Disable exit/entry transitions to remain completely invisible
        overridePendingTransition(0, 0)

        try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            if (cm != null && cm.hasPrimaryClip()) {
                val clip = cm.primaryClip
                if (clip != null && clip.itemCount > 0) {
                    val content = clip.getItemAt(0)?.text?.toString()
                    if (!content.isNullOrBlank()) {
                        val connectionManager = ForegroundServicePlugin.getConnectionManager()
                        if (connectionManager != null && connectionManager.getConnectionState() == "connected") {
                            // Send clipboard over the TLS socket
                            connectionManager.sendClipboard(content)

                            // Save to SQLite for the history UI
                            val db = TetherDatabase.getInstance(applicationContext)
                            db.insertClipboardEntry(content, "TEXT", "local")

                            Toast.makeText(this, "Clipboard sent ✓", Toast.LENGTH_SHORT).show()
                        } else {
                            Toast.makeText(this, "Not connected to any device", Toast.LENGTH_SHORT).show()
                        }
                    } else {
                        Toast.makeText(this, "Clipboard is empty", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    Toast.makeText(this, "Clipboard is empty", Toast.LENGTH_SHORT).show()
                }
            } else {
                Toast.makeText(this, "Clipboard is empty", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read or send clipboard: ${e.message}")
            Toast.makeText(this, "Failed to send clipboard", Toast.LENGTH_SHORT).show()
        }

        finish()
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }
}
