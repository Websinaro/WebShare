package com.otha.webshare.transfer

import java.util.concurrent.atomic.AtomicLong

/**
 * Turns raw byte-delta callbacks from the server/client into the
 * phase/speed/ETA shape the Flutter side expects. Speed is smoothed over
 * a short rolling window so it doesn't jump around on every 32KB chunk.
 */
class ProgressAggregator(private val totalBytes: Long, private val totalFiles: Int) {
    private val transferred = AtomicLong(0)
    private var filesCompleted = 0
    private var currentFileName: String? = null

    private var windowStartMs = System.currentTimeMillis()
    private var windowStartBytes = 0L
    private var lastSpeedBps = 0.0

    data class Snapshot(
        val phase: String,
        val currentFileName: String?,
        val filesCompleted: Int,
        val filesTotal: Int,
        val bytesTransferred: Long,
        val bytesTotal: Long,
        val speedBytesPerSecond: Double,
        val etaSeconds: Long,
        val errorMessage: String? = null,
    )

    @Synchronized
    fun onFileStarted(name: String) {
        currentFileName = name
    }

    @Synchronized
    fun onBytes(delta: Long): Snapshot {
        val total = transferred.addAndGet(delta)
        val now = System.currentTimeMillis()
        val elapsed = now - windowStartMs
        if (elapsed >= 400) {
            lastSpeedBps = ((total - windowStartBytes).toDouble() / elapsed) * 1000.0
            windowStartMs = now
            windowStartBytes = total
        }
        val remaining = (totalBytes - total).coerceAtLeast(0)
        val eta = if (lastSpeedBps > 0) (remaining / lastSpeedBps).toLong() else 0L
        return Snapshot(
            phase = "transferring",
            currentFileName = currentFileName,
            filesCompleted = filesCompleted,
            filesTotal = totalFiles,
            bytesTransferred = total,
            bytesTotal = totalBytes,
            speedBytesPerSecond = lastSpeedBps,
            etaSeconds = eta,
        )
    }

    @Synchronized
    fun onFileCompleted(): Snapshot {
        filesCompleted += 1
        return onBytes(0)
    }

    @Synchronized
    fun completedSnapshot(): Snapshot = Snapshot(
        phase = "completed",
        currentFileName = null,
        filesCompleted = totalFiles,
        filesTotal = totalFiles,
        bytesTransferred = totalBytes,
        bytesTotal = totalBytes,
        speedBytesPerSecond = lastSpeedBps,
        etaSeconds = 0,
    )

    fun errorSnapshot(message: String): Snapshot = Snapshot(
        phase = "failed",
        currentFileName = currentFileName,
        filesCompleted = filesCompleted,
        filesTotal = totalFiles,
        bytesTransferred = transferred.get(),
        bytesTotal = totalBytes,
        speedBytesPerSecond = 0.0,
        etaSeconds = 0,
        errorMessage = message,
    )

    fun cancelledSnapshot(): Snapshot = Snapshot(
        phase = "cancelled",
        currentFileName = currentFileName,
        filesCompleted = filesCompleted,
        filesTotal = totalFiles,
        bytesTransferred = transferred.get(),
        bytesTotal = totalBytes,
        speedBytesPerSecond = 0.0,
        etaSeconds = 0,
    )
}
