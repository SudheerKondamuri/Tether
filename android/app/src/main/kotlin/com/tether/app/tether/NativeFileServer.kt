package com.tether.app.tether

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.*
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * A native HTTP file server running on Android on port 5282.
 * Uses standard ServerSocket to avoid dependency on com.sun.net.httpserver (absent in Android SDK).
 * Stream-based transfers ensure files of any size (e.g. 5GB+) can be shared without OOMs.
 */
class NativeFileServer(private val context: Context) {

    companion object {
        private const val TAG = "NativeFileServer"
        private const val PORT = 5282
    }

    private var serverSocket: ServerSocket? = null
    private val executor: ExecutorService = Executors.newCachedThreadPool()
    private val sharedDirectory: File
        get() {
            val extStorage = File("/storage/emulated/0")
            return if (extStorage.exists() && extStorage.canRead()) {
                extStorage
            } else {
                context.filesDir
            }
        }
    @Volatile private var isRunning = false

    /**
     * Start the HTTP server.
     */
    fun start() {
        if (isRunning) return
        isRunning = true
        try {
            serverSocket = ServerSocket(PORT)
            Log.i(TAG, "Native HTTP File Server started on port $PORT. Sharing: ${sharedDirectory.absolutePath}")
            
            executor.execute {
                while (isRunning) {
                    try {
                        val socket = serverSocket?.accept() ?: break
                        executor.execute {
                            handleConnection(socket)
                        }
                    } catch (e: Exception) {
                        if (isRunning) {
                            Log.e(TAG, "Error accepting connection: ${e.message}")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start file server: ${e.message}", e)
        }
    }

    /**
     * Stop the HTTP server.
     */
    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
            Log.i(TAG, "Native HTTP File Server stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping file server: ${e.message}", e)
        }
    }

    private fun handleConnection(socket: Socket) {
        var inputStream: BufferedInputStream? = null
        var outputStream: BufferedOutputStream? = null
        try {
            socket.soTimeout = 30000 // 30 seconds timeout
            inputStream = BufferedInputStream(socket.getInputStream())
            outputStream = BufferedOutputStream(socket.getOutputStream())

            // 1. Read request line & headers
            val headers = readHeaders(inputStream) ?: return
            val requestLine = headers.firstOrNull() ?: return
            val parts = requestLine.split(" ")
            if (parts.size < 2) return
            val method = parts[0].uppercase()
            val fullUri = parts[1]
            val path = fullUri.split("?")[0]

            // Parse headers into a map
            val headerMap = HashMap<String, String>()
            for (i in 1 until headers.size) {
                val headerLine = headers[i]
                val idx = headerLine.indexOf(':')
                if (idx != -1) {
                    val key = headerLine.substring(0, idx).trim().lowercase()
                    val value = headerLine.substring(idx + 1).trim()
                    headerMap[key] = value
                }
            }

            // Handle CORS OPTIONS preflight
            if (method == "OPTIONS") {
                sendOptionsResponse(outputStream)
                return
            }

            // Route request
            if (path.startsWith("/api/files")) {
                if (method == "GET") {
                    handleFiles(path, outputStream)
                } else {
                    sendErrorResponse(outputStream, 405, "Method Not Allowed")
                }
            } else if (path.startsWith("/api/download")) {
                if (method == "GET") {
                    handleDownload(path, outputStream)
                } else {
                    sendErrorResponse(outputStream, 405, "Method Not Allowed")
                }
            } else if (path == "/api/upload") {
                if (method == "POST") {
                    handleUpload(headerMap, inputStream, outputStream)
                } else {
                    sendErrorResponse(outputStream, 405, "Method Not Allowed")
                }
            } else {
                sendErrorResponse(outputStream, 404, "Not Found")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling connection: ${e.message}", e)
        } finally {
            try {
                inputStream?.close()
            } catch (_: Exception) {}
            try {
                outputStream?.close()
            } catch (_: Exception) {}
            try {
                socket.close()
            } catch (_: Exception) {}
        }
    }

    private fun readHeaders(inputStream: InputStream): List<String>? {
        val headerBytes = ByteArrayOutputStream()
        var matchState = 0 // 0: none, 1: \r, 2: \r\n, 3: \r\n\r
        val lines = ArrayList<String>()

        while (true) {
            val b = inputStream.read()
            if (b == -1) break
            headerBytes.write(b)
            if (b == '\r'.code) {
                if (matchState == 0) matchState = 1
                else if (matchState == 2) matchState = 3
                else matchState = 0
            } else if (b == '\n'.code) {
                if (matchState == 1) matchState = 2
                else if (matchState == 3) {
                    break
                }
                else matchState = 0
            } else {
                matchState = 0
            }
            if (headerBytes.size() > 8192) {
                return null
            }
        }

        val headerStr = headerBytes.toString("UTF-8")
        val linesRaw = headerStr.split("\r\n")
        for (line in linesRaw) {
            val trimmed = line.trim()
            if (trimmed.isNotEmpty()) {
                lines.add(trimmed)
            }
        }
        return lines
    }

    private fun sendOptionsResponse(output: OutputStream) {
        val response = "HTTP/1.1 204 No Content\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                "Access-Control-Allow-Headers: Content-Type, X-Filename\r\n" +
                "Content-Length: 0\r\n" +
                "Connection: close\r\n\r\n"
        output.write(response.toByteArray(Charsets.UTF_8))
        output.flush()
    }

    private fun sendErrorResponse(output: OutputStream, status: Int, message: String) {
        val body = "{\"error\": \"$message\"}"
        val bodyBytes = body.toByteArray(Charsets.UTF_8)
        val response = "HTTP/1.1 $status $message\r\n" +
                "Content-Type: application/json; charset=utf-8\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Content-Length: ${bodyBytes.size}\r\n" +
                "Connection: close\r\n\r\n"
        output.write(response.toByteArray(Charsets.UTF_8))
        output.write(bodyBytes)
        output.flush()
    }

    private fun sendJsonResponse(output: OutputStream, status: Int, statusMsg: String, json: JSONObject) {
        val bodyBytes = json.toString().toByteArray(Charsets.UTF_8)
        val response = "HTTP/1.1 $status $statusMsg\r\n" +
                "Content-Type: application/json; charset=utf-8\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                "Access-Control-Allow-Headers: Content-Type, X-Filename\r\n" +
                "Content-Length: ${bodyBytes.size}\r\n" +
                "Connection: close\r\n\r\n"
        output.write(response.toByteArray(Charsets.UTF_8))
        output.write(bodyBytes)
        output.flush()
    }

    private fun isSafeFile(file: File): Boolean {
        return try {
            val canonicalShared = sharedDirectory.canonicalPath
            val canonicalFile = file.canonicalPath
            canonicalFile.startsWith(canonicalShared)
        } catch (e: Exception) {
            false
        }
    }

    private fun getRelativePath(uriPath: String, prefix: String): String {
        val pathWithoutPrefix = uriPath.removePrefix(prefix).removePrefix("/")
        return try {
            URLDecoder.decode(pathWithoutPrefix, "UTF-8")
        } catch (e: Exception) {
            pathWithoutPrefix
        }
    }

    private fun handleFiles(path: String, output: OutputStream) {
        try {
            val subpath = getRelativePath(path, "/api/files")
            val targetDir = if (subpath.isEmpty()) sharedDirectory else File(sharedDirectory, subpath)

            if (!targetDir.exists() || !targetDir.isDirectory || !isSafeFile(targetDir)) {
                val err = JSONObject().put("error", "Directory not found or access denied")
                sendJsonResponse(output, 403, "Forbidden", err)
                return
            }

            val filesArray = JSONArray()
            val listFiles = targetDir.listFiles() ?: emptyArray()

            val sortedFiles = listFiles.sortedWith(compareBy({ !it.isDirectory }, { it.name.lowercase() }))

            for (file in sortedFiles) {
                val item = JSONObject().apply {
                    put("name", file.name)
                    put("is_dir", file.isDirectory)
                    put("size", if (file.isDirectory) 0 else file.length())
                    put("modified", file.lastModified())
                }
                filesArray.put(item)
            }

            val response = JSONObject().apply {
                put("path", subpath)
                put("files", filesArray)
            }

            sendJsonResponse(output, 200, "OK", response)
        } catch (e: Exception) {
            Log.e(TAG, "Error listing files: ${e.message}", e)
            val err = JSONObject().put("error", "Internal server error")
            sendJsonResponse(output, 500, "Internal Server Error", err)
        }
    }

    private fun handleDownload(path: String, output: OutputStream) {
        try {
            val subpath = getRelativePath(path, "/api/download")
            val file = File(sharedDirectory, subpath)

            if (!file.exists() || file.isDirectory || !isSafeFile(file)) {
                sendErrorResponse(output, 404, "Not Found")
                return
            }

            val headers = "HTTP/1.1 200 OK\r\n" +
                    "Content-Type: application/octet-stream\r\n" +
                    "Content-Disposition: attachment; filename=\"${file.name}\"\r\n" +
                    "Content-Length: ${file.length()}\r\n" +
                    "Access-Control-Allow-Origin: *\r\n" +
                    "Connection: close\r\n\r\n"
            output.write(headers.toByteArray(Charsets.UTF_8))
            output.flush()

            file.inputStream().use { input ->
                val buffer = ByteArray(65536)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                }
            }
            output.flush()
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading file: ${e.message}", e)
        }
    }

    private fun handleUpload(headerMap: Map<String, String>, inputStream: InputStream, output: OutputStream) {
        try {
            val rawFilename = headerMap["x-filename"] ?: "upload_${System.currentTimeMillis()}"
            val filename = URLDecoder.decode(rawFilename, "UTF-8")
            
            val downloadDir = File(sharedDirectory, "Download")
            val targetDir = if (downloadDir.exists() && downloadDir.isDirectory) downloadDir else sharedDirectory
            val destFile = File(targetDir, filename)
            if (!isSafeFile(destFile)) {
                val err = JSONObject().put("error", "Access denied")
                sendJsonResponse(output, 403, "Forbidden", err)
                return
            }

            val contentLengthStr = headerMap["content-length"]
            val contentLength = contentLengthStr?.toLongOrNull() ?: -1L

            FileOutputStream(destFile).use { fileOutput ->
                val buffer = ByteArray(65536)
                var totalRead = 0L
                var bytesRead: Int

                if (contentLength >= 0) {
                    while (totalRead < contentLength) {
                        val toRead = minOf(buffer.size.toLong(), contentLength - totalRead).toInt()
                        bytesRead = inputStream.read(buffer, 0, toRead)
                        if (bytesRead == -1) {
                            throw EOFException("Unexpected EOF while reading request body")
                        }
                        fileOutput.write(buffer, 0, bytesRead)
                        totalRead += bytesRead
                    }
                } else {
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        fileOutput.write(buffer, 0, bytesRead)
                    }
                }
            }

            val response = JSONObject().apply {
                put("status", "ok")
                put("filename", filename)
                put("size", destFile.length())
            }

            sendJsonResponse(output, 200, "OK", response)
            Log.i(TAG, "Successfully saved uploaded file: $filename (${destFile.length()} bytes)")
        } catch (e: Exception) {
            Log.e(TAG, "Error receiving upload: ${e.message}", e)
            val err = JSONObject().put("error", "Internal server error: ${e.message}")
            sendJsonResponse(output, 500, "Internal Server Error", err)
        }
    }
}
