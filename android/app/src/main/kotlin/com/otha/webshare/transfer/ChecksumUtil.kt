package com.otha.webshare.transfer

import java.io.File
import java.io.InputStream
import java.security.MessageDigest

object ChecksumUtil {

    /**
     * Streams the file through SHA-256 without loading it into memory.
     * Used after a download completes — including after a resume — so the
     * check always covers the whole file rather than trying to carry
     * digest state across a paused/resumed transfer (which MessageDigest
     * cannot do safely across process restarts).
     */
    fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input -> updateDigest(digest, input) }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun updateDigest(digest: MessageDigest, input: InputStream) {
        val buffer = ByteArray(FileTransferProtocol.BUFFER_SIZE)
        var read: Int
        while (input.read(buffer).also { read = it } != -1) {
            digest.update(buffer, 0, read)
        }
    }
}
