package com.tether.app.tether

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "TetherProtocol"

// ─────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────

object TetherConstants {
    const val APP_NAME = "Tether"
    const val APP_VERSION = "1.0.0"
    const val TCP_PORT = 5280
    const val UDP_PORT = 5281
    const val MDNS_SERVICE_TYPE = "_continuumlink._tcp"
    const val HEARTBEAT_INTERVAL_MS = 5000L
    const val HEARTBEAT_TIMEOUT_MS = 15000L
    const val RECONNECT_INTERVAL_MS = 10000L
    const val CONNECT_TIMEOUT_MS = 10000
    const val MAX_RECONNECT_ATTEMPTS = 10
}

// ─────────────────────────────────────────────────────────────
// PacketType
// ─────────────────────────────────────────────────────────────

enum class PacketType(val wire: String) {
    HANDSHAKE("HANDSHAKE"),
    HEARTBEAT("HEARTBEAT"),
    CLIPBOARD_UPDATE("CLIPBOARD_UPDATE"),
    NOTIFICATION("NOTIFICATION"),
    NOTIFICATION_REPLY("NOTIFICATION_REPLY"),
    FILE_LIST_REQUEST("FILE_LIST_REQUEST"),
    FILE_LIST_RESPONSE("FILE_LIST_RESPONSE"),
    FILE_CHUNK("FILE_CHUNK"),
    FILE_CHUNK_ACK("FILE_CHUNK_ACK"),
    ADB_STATUS("ADB_STATUS"),
    DISCONNECT("DISCONNECT");

    companion object {
        private val wireMap: Map<String, PacketType> =
            entries.associateBy { it.wire }

        fun fromWire(wire: String): PacketType =
            wireMap[wire]
                ?: throw IllegalArgumentException("Unknown packet type: $wire")
    }
}

// ─────────────────────────────────────────────────────────────
// Packet
// ─────────────────────────────────────────────────────────────

data class Packet(
    val type: PacketType,
    val deviceId: String,
    val timestamp: Long = System.currentTimeMillis(),
    val payload: Map<String, Any?> = emptyMap()
) {

    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("type", type.wire)
        json.put("device_id", deviceId)
        json.put("timestamp", timestamp)
        json.put("payload", mapToJson(payload))
        return json
    }

    /**
     * Encodes this packet as a single NDJSON line (UTF-8 bytes terminated by `\n`).
     */
    fun encode(): ByteArray {
        val line = toJson().toString() + "\n"
        return line.toByteArray(Charsets.UTF_8)
    }

    companion object {

        fun fromJson(json: JSONObject): Packet {
            val type = PacketType.fromWire(json.getString("type"))
            val deviceId = json.getString("device_id")
            val timestamp = json.optLong("timestamp", System.currentTimeMillis())
            val payloadJson = json.optJSONObject("payload")
            val payload: Map<String, Any?> = if (payloadJson != null) {
                jsonObjectToMap(payloadJson)
            } else {
                emptyMap()
            }
            return Packet(
                type = type,
                deviceId = deviceId,
                timestamp = timestamp,
                payload = payload
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────
// PacketCodec — buffered NDJSON decoder
// ─────────────────────────────────────────────────────────────

class PacketCodec {

    private val buffer = StringBuilder()

    /**
     * Appends incoming [data] to the internal buffer and returns all
     * complete packets parsed so far. Partial lines are kept in the
     * buffer until a newline delimiter arrives. Malformed JSON lines
     * are logged and silently skipped.
     */
    fun decode(data: ByteArray): List<Packet> {
        buffer.append(String(data, Charsets.UTF_8))

        val packets = mutableListOf<Packet>()
        while (true) {
            val newlineIndex = buffer.indexOf('\n')
            if (newlineIndex == -1) break

            val line = buffer.substring(0, newlineIndex).trim()
            buffer.delete(0, newlineIndex + 1)

            if (line.isEmpty()) continue

            try {
                val json = JSONObject(line)
                packets.add(Packet.fromJson(json))
            } catch (e: Exception) {
                Log.w(TAG, "Skipping malformed NDJSON line: ${e.message}")
            }
        }
        return packets
    }

    /** Clears the internal buffer, discarding any partial data. */
    fun reset() {
        buffer.setLength(0)
    }
}

// ─────────────────────────────────────────────────────────────
// Payload data classes
// ─────────────────────────────────────────────────────────────

data class HandshakePayload(
    val name: String,
    val platform: String,
    val version: String
) {
    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("name", name)
        json.put("platform", platform)
        json.put("version", version)
        return json
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "platform" to platform,
        "version" to version
    )

    companion object {
        fun fromJson(json: JSONObject): HandshakePayload =
            HandshakePayload(
                name = json.getString("name"),
                platform = json.getString("platform"),
                version = json.getString("version")
            )

        fun fromMap(map: Map<String, Any?>): HandshakePayload =
            HandshakePayload(
                name = map["name"] as? String ?: "",
                platform = map["platform"] as? String ?: "",
                version = map["version"] as? String ?: ""
            )
    }
}

data class HeartbeatPayload(
    val battery: Int? = null,
    val wifiStrength: Int? = null
) {
    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("battery", battery ?: JSONObject.NULL)
        json.put("wifi_strength", wifiStrength ?: JSONObject.NULL)
        return json
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "battery" to battery,
        "wifi_strength" to wifiStrength
    )

    companion object {
        fun fromJson(json: JSONObject): HeartbeatPayload =
            HeartbeatPayload(
                battery = if (json.has("battery") && !json.isNull("battery"))
                    json.getInt("battery") else null,
                wifiStrength = if (json.has("wifi_strength") && !json.isNull("wifi_strength"))
                    json.getInt("wifi_strength") else null
            )

        fun fromMap(map: Map<String, Any?>): HeartbeatPayload =
            HeartbeatPayload(
                battery = map["battery"] as? Int,
                wifiStrength = map["wifi_strength"] as? Int
            )
    }
}

data class ClipboardPayload(
    val content: String,
    val dataType: String
) {
    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("content", content)
        json.put("data_type", dataType)
        return json
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "content" to content,
        "data_type" to dataType
    )

    companion object {
        fun fromJson(json: JSONObject): ClipboardPayload =
            ClipboardPayload(
                content = json.getString("content"),
                dataType = json.getString("data_type")
            )

        fun fromMap(map: Map<String, Any?>): ClipboardPayload =
            ClipboardPayload(
                content = map["content"] as? String ?: "",
                dataType = map["data_type"] as? String ?: "TEXT"
            )
    }
}

data class NotificationPayload(
    val app: String,
    val packageName: String,
    val title: String,
    val text: String,
    val iconB64: String? = null,
    val actions: List<String> = emptyList()
) {
    fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("app", app)
        json.put("package", packageName)
        json.put("title", title)
        json.put("text", text)
        json.put("icon_b64", iconB64 ?: JSONObject.NULL)
        json.put("actions", JSONArray(actions))
        return json
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "app" to app,
        "package" to packageName,
        "title" to title,
        "text" to text,
        "icon_b64" to iconB64,
        "actions" to actions
    )

    companion object {
        fun fromJson(json: JSONObject): NotificationPayload {
            val actionsList = mutableListOf<String>()
            val actionsArray = json.optJSONArray("actions")
            if (actionsArray != null) {
                for (i in 0 until actionsArray.length()) {
                    actionsList.add(actionsArray.getString(i))
                }
            }
            return NotificationPayload(
                app = json.getString("app"),
                packageName = json.getString("package"),
                title = json.getString("title"),
                text = json.getString("text"),
                iconB64 = if (json.has("icon_b64") && !json.isNull("icon_b64"))
                    json.getString("icon_b64") else null,
                actions = actionsList
            )
        }

        fun fromMap(map: Map<String, Any?>): NotificationPayload {
            @Suppress("UNCHECKED_CAST")
            val actionsList = map["actions"] as? List<String> ?: emptyList()
            return NotificationPayload(
                app = map["app"] as? String ?: "",
                packageName = map["package"] as? String ?: "",
                title = map["title"] as? String ?: "",
                text = map["text"] as? String ?: "",
                iconB64 = map["icon_b64"] as? String,
                actions = actionsList
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────
// JSON ↔ Map helpers (recursive, handles nested objects/arrays)
// ─────────────────────────────────────────────────────────────

private fun mapToJson(map: Map<String, Any?>): JSONObject {
    val json = JSONObject()
    for ((key, value) in map) {
        json.put(key, toJsonValue(value))
    }
    return json
}

private fun toJsonValue(value: Any?): Any? = when (value) {
    null -> JSONObject.NULL
    is Map<*, *> -> {
        @Suppress("UNCHECKED_CAST")
        mapToJson(value as Map<String, Any?>)
    }
    is List<*> -> {
        val arr = JSONArray()
        for (item in value) {
            arr.put(toJsonValue(item))
        }
        arr
    }
    is Boolean, is Int, is Long, is Double, is Float, is String -> value
    else -> value.toString()
}

private fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val keys = json.keys()
    while (keys.hasNext()) {
        val key = keys.next()
        map[key] = fromJsonValue(json.get(key))
    }
    return map
}

private fun fromJsonValue(value: Any?): Any? = when (value) {
    JSONObject.NULL, null -> null
    is JSONObject -> jsonObjectToMap(value)
    is JSONArray -> {
        val list = mutableListOf<Any?>()
        for (i in 0 until value.length()) {
            list.add(fromJsonValue(value.get(i)))
        }
        list
    }
    else -> value // primitives pass through
}
