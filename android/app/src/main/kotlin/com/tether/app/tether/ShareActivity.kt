package com.tether.app.tether

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Parcelable
import android.util.Log
import android.widget.Toast

/**
 * A transparent activity that intercepts system share intents (SEND / SEND_MULTIPLE).
 * Tapping "Tether" in the sharing drawer launches this activity invisibly.
 * If connected, it schedules the upload in the persistent service and finishes.
 * If disconnected, it prompts the user and opens the main pairing UI.
 */
class ShareActivity : Activity() {

    companion object {
        private const val TAG = "ShareActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        overridePendingTransition(0, 0)

        val intent = intent
        val action = intent?.action
        val uris = mutableListOf<Uri>()

        try {
            if (Intent.ACTION_SEND == action) {
                val streamUri = intent.getParcelableExtra<Parcelable>(Intent.EXTRA_STREAM) as? Uri
                if (streamUri != null) {
                    uris.add(streamUri)
                }
            } else if (Intent.ACTION_SEND_MULTIPLE == action) {
                val streamUris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (streamUris != null) {
                    uris.addAll(streamUris.filterNotNull())
                }
            }

            if (uris.isNotEmpty()) {
                val connectionManager = ForegroundServicePlugin.getConnectionManager()
                if (connectionManager != null && connectionManager.getConnectionState() == "connected") {
                    val peerInfo = connectionManager.getConnectedDeviceInfo()
                    val peerName = peerInfo?.get("name") as? String ?: "Device"

                    // Enqueue upload in background service coroutine
                    ForegroundServicePlugin.getInstance()?.enqueueNativeUpload(uris)

                    val fileCountLabel = if (uris.size == 1) "file" else "${uris.size} files"
                    Toast.makeText(this, "Tether: Sending $fileCountLabel to $peerName...", Toast.LENGTH_LONG).show()
                } else {
                    Toast.makeText(this, "Tether: No connected device to share with", Toast.LENGTH_LONG).show()
                    val mainIntent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    }
                    startActivity(mainIntent)
                }
            } else {
                Toast.makeText(this, "Tether: No files shared", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling share intent: ${e.message}", e)
            Toast.makeText(this, "Tether: Share failed", Toast.LENGTH_SHORT).show()
        }

        finish()
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }
}
