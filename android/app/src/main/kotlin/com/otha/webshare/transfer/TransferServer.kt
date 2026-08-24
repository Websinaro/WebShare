package com.otha.webshare.transfer

import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedOutputStream
import java.io.InputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Sender side. Hosts a plain TCP server on the device's Wi-Fi Direct group
 * IP. Serves:
 *   GET /manifest              -> JSON list of ManifestEntry
 *   GET /file/{id}             -> file bytes (supports "Range: bytes=N-")
 * Every request must carry the session token in X-WebShare-Token or is
 * rejected with 403 — this is what keeps a stray device on the same
 * network from pulling files just by guessing the port.
 */
class TransferServer(
    private val files: List<SendableFile>,
    private val token: String,
    private val onBytesSent: (fileId: String, sentDelta: Long) -> Unit,
    private val onFileStarted: (fileId: String) -> Unit,
    private val onFileCompleted: (fileId: String) -> Unit,
    private val onError: (String) -> Unit,
) {
    data class SendableFile(
        val id: String,
        val name: String,
        val extension: String,
        val sizeBytes: Long,
        val sha256: String,
        val openStream: () -> InputStream,
    )

    private var serverSocket: ServerSocket? = null
    private val pool = Executors.newCachedThreadPool()
    private val running = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private val paused = AtomicBoolean(false)

    fun pause() = paused.set(true)
    fun resume() = paused.set(false)

    /** Starts listening and returns the bound port. */
    fun start(preferredPort: Int = FileTransferProtocol.DEFAULT_PORT): Int {
        val socket = ServerSocket(preferredPort)
        serverSocket = socket
        running.set(true)
        pool.execute { acceptLoop(socket) }
        return socket.localPort
    }

    fun stop() {
        cancelled.set(true)
        running.set(false)
        runCatching { serverSocket?.close() }
        pool.shutdownNow()
    }

    private fun acceptLoop(server: ServerSocket) {
        while (running.get()) {
            val client = try {
                server.accept()
            } catch (e: Exception) {
                if (running.get()) onError("Accept failed: ${e.message}")
                return
            }
            pool.execute { handleClient(client) }
        }
    }

    private fun handleClient(socket: Socket) {
        socket.use { s ->
            s.soTimeout = FileTransferProtocol.SOCKET_TIMEOUT_MS
            try {
                val request = HttpLiteRequest.parse(s.getInputStream())
                    ?: return respondError(s, 400, "Bad request")

                if (request.headers[FileTransferProtocol.TOKEN_HEADER.lowercase()] != token) {
                    return respondError(s, 403, "Invalid token")
                }

                when {
                    request.path == FileTransferProtocol.MANIFEST_PATH -> serveManifest(s)
                    request.path.startsWith(FileTransferProtocol.FILE_PATH_PREFIX) -> {
                        val id = Uri.decode(request.path.removePrefix(FileTransferProtocol.FILE_PATH_PREFIX))
                        serveFile(s, id, request.headers["range"])
                    }
                    else -> respondError(s, 404, "Not found")
                }
            } catch (e: Exception) {
                if (!cancelled.get()) onError("Client handling failed: ${e.message}")
            }
        }
    }

    private fun serveManifest(socket: Socket) {
        val array = JSONArray()
        for (f in files) {
            array.put(JSONObject().apply {
                put("id", f.id)
                put("name", f.name)
                put("extension", f.extension)
                put("sizeBytes", f.sizeBytes)
                put("sha256", f.sha256)
            })
        }
        val body = array.toString().toByteArray(Charsets.UTF_8)
        val out = BufferedOutputStream(socket.getOutputStream())
        out.write(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${body.size}\r\nConnection: close\r\n\r\n"
                .toByteArray(Charsets.US_ASCII)
        )
        out.write(body)
        out.flush()
    }

    private fun serveFile(socket: Socket, fileId: String, rangeHeader: String?) {
        val file = files.find { it.id == fileId } ?: return respondError(socket, 404, "Unknown file")

        val start = parseRangeStart(rangeHeader)
        val length = file.sizeBytes - start
        onFileStarted(fileId)

        val out = BufferedOutputStream(socket.getOutputStream())
        val statusLine = if (start > 0) "HTTP/1.1 206 Partial Content" else "HTTP/1.1 200 OK"
        val headers = buildString {
            append("$statusLine\r\n")
            append("Content-Type: application/octet-stream\r\n")
            append("Content-Length: $length\r\n")
            append("${FileTransferProtocol.CHECKSUM_HEADER}: ${file.sha256}\r\n")
            append("Accept-Ranges: bytes\r\n")
            if (start > 0) append("Content-Range: bytes $start-${file.sizeBytes - 1}/${file.sizeBytes}\r\n")
            append("Connection: close\r\n\r\n")
        }
        out.write(headers.toByteArray(Charsets.US_ASCII))

        file.openStream().use { input ->
            if (start > 0) input.skip(start)
            val buffer = ByteArray(FileTransferProtocol.BUFFER_SIZE)
            var sentSinceLastNotify = 0L
            var read: Int
            while (input.read(buffer).also { read = it } != -1) {
                if (cancelled.get()) break
                while (paused.get() && !cancelled.get()) Thread.sleep(150)
                out.write(buffer, 0, read)
                sentSinceLastNotify += read
                // Coalesce progress callbacks to roughly every 32KB so we
                // don't flood the EventChannel bridge for large files.
                if (sentSinceLastNotify >= 32 * 1024) {
                    onBytesSent(fileId, sentSinceLastNotify)
                    sentSinceLastNotify = 0
                }
            }
            if (sentSinceLastNotify > 0) onBytesSent(fileId, sentSinceLastNotify)
        }
        out.flush()
        onFileCompleted(fileId)
    }

    private fun parseRangeStart(rangeHeader: String?): Long {
        // Expected form: "bytes=12345-"
        val match = Regex("""bytes=(\d+)-""").find(rangeHeader ?: "") ?: return 0
        return match.groupValues[1].toLongOrNull() ?: 0
    }

    private fun respondError(socket: Socket, code: Int, message: String) {
        val out = socket.getOutputStream()
        val body = message.toByteArray(Charsets.UTF_8)
        out.write(
            "HTTP/1.1 $code $message\r\nContent-Length: ${body.size}\r\nConnection: close\r\n\r\n"
                .toByteArray(Charsets.US_ASCII)
        )
        out.write(body)
        out.flush()
    }
}

/** Minimal request-line + headers parser — enough for our own client, not a general HTTP parser. */
data class HttpLiteRequest(val method: String, val path: String, val headers: Map<String, String>) {
    companion object {
        fun parse(input: InputStream): HttpLiteRequest? {
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
            if (lines.isEmpty()) return null
            val requestLine = lines.first().split(" ")
            if (requestLine.size < 2) return null
            val headers = mutableMapOf<String, String>()
            for (line in lines.drop(1)) {
                val idx = line.indexOf(':')
                if (idx == -1) continue
                headers[line.substring(0, idx).trim().lowercase()] = line.substring(idx + 1).trim()
            }
            return HttpLiteRequest(requestLine[0], requestLine[1], headers)
        }
    }
}
