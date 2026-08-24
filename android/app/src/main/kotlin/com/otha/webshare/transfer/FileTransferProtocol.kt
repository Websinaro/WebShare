package com.otha.webshare.transfer

/**
 * The wire protocol spoken between two WebShare devices over a plain TCP
 * socket. Deliberately a minimal HTTP/1.1 subset (not a full HTTP server) —
 * just enough for: a file manifest, ranged GETs for resumable transfer,
 * and a token header for session auth. No external HTTP library needed.
 */
object FileTransferProtocol {
    const val DEFAULT_PORT = 8988
    const val TOKEN_HEADER = "X-WebShare-Token"
    const val CHECKSUM_HEADER = "X-WebShare-SHA256"
    const val MANIFEST_PATH = "/manifest"
    const val FILE_PATH_PREFIX = "/file/"
    const val BUFFER_SIZE = 64 * 1024
    const val SOCKET_TIMEOUT_MS = 15_000
}

/** One entry in the manifest the sender exposes at GET /manifest. */
data class ManifestEntry(
    val id: String,
    val name: String,
    val extension: String,
    val sizeBytes: Long,
    val sha256: String
)
