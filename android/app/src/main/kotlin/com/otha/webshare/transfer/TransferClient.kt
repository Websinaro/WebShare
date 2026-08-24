package com.otha.webshare.transfer

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import org.json.JSONArray
import java.io.File
import java.io.RandomAccessFile
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Receiver side. Talks the same lite-HTTP protocol TransferServer speaks:
 * fetches the manifest, then pulls each requested file with a ranged GET
 * so a paused/interrupted transfer can resume from the partial file already
 * on disk instead of restarting.
 */
class TransferClient(
    private val context: Context,
    private val host: String,
    private val port: Int,
    private val token: String,
) {
    private val cancelled = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)

    data class RemoteFile(val id: String, val name: String, val extension: String, val sizeBytes: Long, val sha256: String)

    fun fetchManifest(): List<RemoteFile> {
        Socket(host, port).use { socket ->
            socket.soTimeout = FileTransferProtocol.SOCKET_TIMEOUT_MS
            writeRequest(socket, "GET", FileTransferProtocol.MANIFEST_PATH, emptyMap())
            val response = HttpLiteResponse.parse(socket.getInputStream())
                ?: throw IllegalStateException("Empty manifest response")
            val json = JSONArray(String(response.body, Charsets.UTF_8))
            return (0 until json.length()).map { i ->
                val o = json.getJSONObject(i)
                RemoteFile(
                    id = o.getString("id"),
                    name = o.getString("name"),
                    extension = o.getString("extension"),
                    sizeBytes = o.getLong("sizeBytes"),
                    sha256 = o.getString("sha256"),
                )
            }
        }
    }

    /**
     * Downloads [file] into a staging cache path, resuming if a partial
     * download already exists there, then verifies its SHA-256 and moves
     * it into public storage the correct way for the running API level.
     * [onProgress] receives cumulative bytes written for this file.
     */
    fun downloadFile(
        file: RemoteFile,
        onProgress: (bytesTransferredThisFile: Long) -> Unit,
    ): File {
        val stagingFile = File(context.cacheDir, "webshare_${file.id}")
        var resumeFrom = if (stagingFile.exists()) stagingFile.length() else 0L
        if (resumeFrom >= file.sizeBytes) resumeFrom = 0L // stale/complete leftover; restart clean

        Socket(host, port).use { socket ->
            socket.soTimeout = FileTransferProtocol.SOCKET_TIMEOUT_MS
            val headers = if (resumeFrom > 0) mapOf("Range" to "bytes=$resumeFrom-") else emptyMap()
            writeRequest(socket, "GET", "${FileTransferProtocol.FILE_PATH_PREFIX}${file.id}", headers)

            val response = HttpLiteResponseStream(socket.getInputStream())
            response.readHeaders()
            if (response.statusCode !in intArrayOf(200, 206)) {
                throw IllegalStateException("Server returned ${response.statusCode} for ${file.name}")
            }

            RandomAccessFile(stagingFile, "rw").use { raf ->
                raf.seek(resumeFrom)
                var written = resumeFrom
                val buffer = ByteArray(FileTransferProtocol.BUFFER_SIZE)
                while (true) {
                    if (cancelled.get()) throw CancellationException()
                    while (paused.get()) Thread.sleep(150)

                    val read = response.read(buffer)
                    if (read == -1) break
                    raf.write(buffer, 0, read)
                    written += read
                    onProgress(written)
                }
            }
        }

        val actualHash = ChecksumUtil.sha256(stagingFile)
        if (!actualHash.equals(file.sha256, ignoreCase = true)) {
            stagingFile.delete()
            throw IllegalStateException("Checksum mismatch for ${file.name} — transfer corrupted")
        }

        return persistToPublicStorage(stagingFile, file)
    }

    fun pause() = paused.set(true)
    fun resume() = paused.set(false)
    fun cancel() = cancelled.set(true)

    /** Scoped-storage-correct save: MediaStore on API 29+, direct file path below that. */
    private fun persistToPublicStorage(stagingFile: File, file: RemoteFile): File {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, file.name)
                put(MediaStore.Downloads.MIME_TYPE, mimeTypeFor(file.extension))
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/WebShare")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create MediaStore entry")
            resolver.openOutputStream(uri)?.use { out ->
                stagingFile.inputStream().use { it.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            stagingFile.delete()
            return stagingFile // native side keeps the MediaStore Uri separately if needed
        } else {
            val downloadsDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "WebShare"
            )
            if (!downloadsDir.exists()) downloadsDir.mkdirs()
            val destination = File(downloadsDir, file.name)
            stagingFile.copyTo(destination, overwrite = true)
            stagingFile.delete()
            return destination
        }
    }

    private fun mimeTypeFor(extension: String): String = when (extension.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "mp4" -> "video/mp4"
        "mp3" -> "audio/mpeg"
        "pdf" -> "application/pdf"
        "zip" -> "application/zip"
        "apk" -> "application/vnd.android.package-archive"
        else -> "application/octet-stream"
    }

    private fun writeRequest(socket: Socket, method: String, path: String, extraHeaders: Map<String, String>) {
        val headers = buildString {
            append("$method $path HTTP/1.1\r\n")
            append("Host: $host:$port\r\n")
            append("${FileTransferProtocol.TOKEN_HEADER}: $token\r\n")
            for ((k, v) in extraHeaders) append("$k: $v\r\n")
            append("Connection: close\r\n\r\n")
        }
        socket.getOutputStream().write(headers.toByteArray(Charsets.US_ASCII))
    }

    class CancellationException : Exception("Transfer cancelled")
}

/** Reads a full lite-HTTP response (headers + whole body) — used for the small manifest response. */
private class HttpLiteResponse(val statusCode: Int, val headers: Map<String, String>, val body: ByteArray) {
    companion object {
        fun parse(input: java.io.InputStream): HttpLiteResponse? {
            val stream = HttpLiteResponseStream(input)
            stream.readHeaders()
            val contentLength = stream.headers["content-length"]?.toIntOrNull() ?: 0
            val body = ByteArray(contentLength)
            var offset = 0
            while (offset < contentLength) {
                val read = stream.read(body, offset, contentLength - offset)
                if (read == -1) break
                offset += read
            }
            return HttpLiteResponse(stream.statusCode, stream.headers, body)
        }
    }
}

/** Streaming header parser + pass-through body reader — used for large file bodies. */
private class HttpLiteResponseStream(private val input: java.io.InputStream) {
    var statusCode: Int = 0
        private set
    var headers: Map<String, String> = emptyMap()
        private set

    fun readHeaders() {
        val lines = mutableListOf<String>()
        val lineBuffer = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1) break
            val c = b.toChar()
            if (c == '\n') {
                lines.add(lineBuffer.toString().removeSuffix("\r"))
                lineBuffer.clear()
                if (lines.isNotEmpty() && lines.last().isEmpty()) break
            } else {
                lineBuffer.append(c)
            }
        }
        if (lines.isEmpty()) throw IllegalStateException("Empty response")
        statusCode = lines.first().split(" ").getOrNull(1)?.toIntOrNull() ?: 0
        val map = mutableMapOf<String, String>()
        for (line in lines.drop(1)) {
            val idx = line.indexOf(':')
            if (idx == -1) continue
            map[line.substring(0, idx).trim().lowercase()] = line.substring(idx + 1).trim()
        }
        headers = map
    }

    fun read(buffer: ByteArray): Int = input.read(buffer)
    fun read(buffer: ByteArray, offset: Int, length: Int): Int = input.read(buffer, offset, length)
}
