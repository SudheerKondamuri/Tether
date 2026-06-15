package com.tether.app.tether

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.util.Log
import java.io.File
import java.util.UUID
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Lightweight native SQLite wrapper that reads/writes the same `tether.db`
 * database that the Dart Drift layer uses.
 *
 * The database is opened in WAL mode so that concurrent reads from the
 * foreground service don't block the Flutter isolate (and vice-versa).
 *
 * All public methods are guarded by a [ReentrantLock] for thread safety.
 */
class TetherDatabase private constructor(context: Context) {

    companion object {
        private const val TAG = "TetherDB"
        private const val DB_NAME = "tether.db"
        private const val SETTINGS_TABLE = "settings"
        private const val PAIRED_DEVICES_TABLE = "paired_devices"

        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_DEVICE_NAME = "device_name"

        @Volatile
        private var instance: TetherDatabase? = null

        fun getInstance(context: Context): TetherDatabase {
            return instance ?: synchronized(this) {
                instance ?: TetherDatabase(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    data class PairedDeviceRecord(
        val deviceId: String,
        val name: String,
        val platform: String,
        val certPem: String,
        val certFingerprint: String,
        val lastIp: String?,
        val lastPort: Int?,
        val pairedAt: Long // epoch milliseconds (converted to/from epoch seconds in SQLite)
    )

    private val lock = ReentrantLock()
    private var db: SQLiteDatabase? = null

    init {
        db = openDatabase(context)
    }

    // ---------------------------------------------------------------
    // Database opening
    // ---------------------------------------------------------------

    private fun openDatabase(context: Context): SQLiteDatabase? {
        try {
            // path_provider's getApplicationDocumentsDirectory() on Android
            // resolves to <dataDir>/app_flutter
            val appFlutterDir = File(context.applicationInfo.dataDir, "app_flutter")
            val dbFile = File(appFlutterDir, DB_NAME)

            if (!dbFile.exists()) {
                Log.w(TAG, "Database file does not exist yet: ${dbFile.absolutePath}")
                // Ensure directory exists so we can create a minimal DB
                if (!appFlutterDir.exists()) {
                    appFlutterDir.mkdirs()
                }
                // Create a minimal database with required tables so the
                // service can operate before Flutter has run for the first time.
                return createMinimalDatabase(dbFile)
            }

            val database = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING
            )
            database.execSQL("PRAGMA synchronous=NORMAL")
            Log.i(TAG, "Opened database at ${dbFile.absolutePath}")
            return database
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open database", e)
            return null
        }
    }

    private fun createMinimalDatabase(dbFile: File): SQLiteDatabase? {
        return try {
            val database = SQLiteDatabase.openOrCreateDatabase(dbFile, null)
            database.execSQL("PRAGMA journal_mode=WAL")
            database.execSQL("PRAGMA synchronous=NORMAL")

            database.execSQL(
                """
                CREATE TABLE IF NOT EXISTS $SETTINGS_TABLE (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                )
                """.trimIndent()
            )

            database.execSQL(
                """
                CREATE TABLE IF NOT EXISTS $PAIRED_DEVICES_TABLE (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    platform TEXT NOT NULL,
                    cert_pem TEXT NOT NULL,
                    cert_fingerprint TEXT NOT NULL,
                    last_ip TEXT,
                    last_port INTEGER,
                    paired_at INTEGER NOT NULL
                )
                """.trimIndent()
            )

            Log.i(TAG, "Created minimal database at ${dbFile.absolutePath}")
            database
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create minimal database", e)
            null
        }
    }

    // ---------------------------------------------------------------
    // Settings
    // ---------------------------------------------------------------

    /**
     * Read a single value from the `settings` table.
     */
    fun getSetting(key: String): String? = lock.withLock {
        val database = db ?: return null
        try {
            database.rawQuery(
                "SELECT value FROM $SETTINGS_TABLE WHERE key = ? LIMIT 1",
                arrayOf(key)
            ).use { cursor ->
                if (cursor.moveToFirst()) {
                    cursor.getString(0)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "getSetting($key) failed", e)
            null
        }
    }

    /**
     * Insert or replace a value in the `settings` table.
     */
    fun setSetting(key: String, value: String): Unit = lock.withLock {
        val database = db ?: return
        try {
            val cv = ContentValues(2).apply {
                put("key", key)
                put("value", value)
            }
            database.insertWithOnConflict(
                SETTINGS_TABLE,
                null,
                cv,
                SQLiteDatabase.CONFLICT_REPLACE
            )
        } catch (e: Exception) {
            Log.e(TAG, "setSetting($key) failed", e)
        }
    }

    // ---------------------------------------------------------------
    // Paired devices
    // ---------------------------------------------------------------

    /**
     * Return every row from the `paired_devices` table.
     *
     * Drift stores `DateTime` as epoch **seconds** in SQLite, so we convert
     * to milliseconds for the [PairedDeviceRecord.pairedAt] field.
     */
    fun getPairedDevices(): List<PairedDeviceRecord> = lock.withLock {
        val database = db ?: return emptyList()
        val result = mutableListOf<PairedDeviceRecord>()
        try {
            database.rawQuery(
                """
                SELECT device_id, name, platform, cert_pem, cert_fingerprint,
                       last_ip, last_port, paired_at
                FROM $PAIRED_DEVICES_TABLE
                """.trimIndent(),
                null
            ).use { cursor ->
                val colDeviceId = cursor.getColumnIndexOrThrow("device_id")
                val colName = cursor.getColumnIndexOrThrow("name")
                val colPlatform = cursor.getColumnIndexOrThrow("platform")
                val colCertPem = cursor.getColumnIndexOrThrow("cert_pem")
                val colCertFp = cursor.getColumnIndexOrThrow("cert_fingerprint")
                val colLastIp = cursor.getColumnIndexOrThrow("last_ip")
                val colLastPort = cursor.getColumnIndexOrThrow("last_port")
                val colPairedAt = cursor.getColumnIndexOrThrow("paired_at")

                while (cursor.moveToNext()) {
                    result.add(
                        PairedDeviceRecord(
                            deviceId = cursor.getString(colDeviceId),
                            name = cursor.getString(colName),
                            platform = cursor.getString(colPlatform),
                            certPem = cursor.getString(colCertPem),
                            certFingerprint = cursor.getString(colCertFp),
                            lastIp = if (cursor.isNull(colLastIp)) null else cursor.getString(colLastIp),
                            lastPort = if (cursor.isNull(colLastPort)) null else cursor.getInt(colLastPort),
                            // Drift stores seconds → convert to millis
                            pairedAt = cursor.getLong(colPairedAt) * 1000L
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "getPairedDevices() failed", e)
        }
        return result
    }

    /**
     * Insert or update a paired device row, keyed by `device_id`.
     *
     * [PairedDeviceRecord.pairedAt] is in epoch milliseconds; we convert to
     * seconds before writing because Drift uses epoch seconds.
     */
    fun upsertPairedDevice(device: PairedDeviceRecord): Unit = lock.withLock {
        val database = db ?: return
        try {
            val cv = ContentValues(8).apply {
                put("device_id", device.deviceId)
                put("name", device.name)
                put("platform", device.platform)
                put("cert_pem", device.certPem)
                put("cert_fingerprint", device.certFingerprint)
                if (device.lastIp != null) put("last_ip", device.lastIp) else putNull("last_ip")
                if (device.lastPort != null) put("last_port", device.lastPort) else putNull("last_port")
                // Convert millis → seconds for Drift compatibility
                put("paired_at", device.pairedAt / 1000L)
            }

            // Try update first, keyed on device_id
            val rowsUpdated = database.update(
                PAIRED_DEVICES_TABLE,
                cv,
                "device_id = ?",
                arrayOf(device.deviceId)
            )
            if (rowsUpdated == 0) {
                database.insertWithOnConflict(
                    PAIRED_DEVICES_TABLE,
                    null,
                    cv,
                    SQLiteDatabase.CONFLICT_REPLACE
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "upsertPairedDevice(${device.deviceId}) failed", e)
        }
    }

    // ---------------------------------------------------------------
    // Identity helpers
    // ---------------------------------------------------------------

    /**
     * Reads the device ID from settings; generates and persists a new UUID
     * if one doesn't exist yet.
     */
    fun getDeviceId(): String = lock.withLock {
        val existing = getSettingInternal(KEY_DEVICE_ID)
        if (existing != null) return existing

        val generated = UUID.randomUUID().toString()
        setSettingInternal(KEY_DEVICE_ID, generated)
        Log.i(TAG, "Generated new device ID: $generated")
        return generated
    }

    /**
     * Reads the device name from settings; falls back to [Build.MODEL]
     * if not set.
     */
    fun getDeviceName(): String = lock.withLock {
        val existing = getSettingInternal(KEY_DEVICE_NAME)
        if (existing != null) return existing

        val fallback = Build.MODEL ?: "Android Device"
        setSettingInternal(KEY_DEVICE_NAME, fallback)
        Log.i(TAG, "Using fallback device name: $fallback")
        return fallback
    }

    // ---------------------------------------------------------------
    // Internal helpers (called while lock is already held)
    // ---------------------------------------------------------------

    private fun getSettingInternal(key: String): String? {
        val database = db ?: return null
        return try {
            database.rawQuery(
                "SELECT value FROM $SETTINGS_TABLE WHERE key = ? LIMIT 1",
                arrayOf(key)
            ).use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "getSettingInternal($key) failed", e)
            null
        }
    }

    private fun setSettingInternal(key: String, value: String) {
        val database = db ?: return
        try {
            val cv = ContentValues(2).apply {
                put("key", key)
                put("value", value)
            }
            database.insertWithOnConflict(
                SETTINGS_TABLE,
                null,
                cv,
                SQLiteDatabase.CONFLICT_REPLACE
            )
        } catch (e: Exception) {
            Log.e(TAG, "setSettingInternal($key) failed", e)
        }
    }

    // ---------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------

    /**
     * Close the underlying database. After this the instance is unusable;
     * call [getInstance] again to re-open.
     */
    fun close() = lock.withLock {
        try {
            db?.close()
            Log.i(TAG, "Database closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing database", e)
        } finally {
            db = null
            synchronized(Companion) {
                instance = null
            }
        }
    }
}
