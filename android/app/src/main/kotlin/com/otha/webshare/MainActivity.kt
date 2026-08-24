package com.otha.webshare

import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.otha.webshare.transfer.ChecksumUtil
import com.otha.webshare.transfer.ProgressAggregator
import com.otha.webshare.transfer.TransferClient
import com.otha.webshare.transfer.TransferServer
import com.otha.webshare.transfer.WifiDirectHost
import com.otha.webshare.transfer.WifiJoiner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.otha.webshare/transfer"
    private val eventChannelName = "com.otha.webshare/progress"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    private var eventSink: EventChannel.EventSink? = null

    // Sender-side state
    private var wifiDirectHost: WifiDirectHost? = null
    private var transferServer: TransferServer? = null

    // Receiver-side state
    private var wifiJoiner: WifiJoiner? = null
    private var transferClient: TransferClient? = null
    private var remoteManifest: List<TransferClient.RemoteFile> = emptyList()
    private var sessionHost: String = ""
    private var sessionPort: Int = 0
    private var sessionToken: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startHosting" -> startHosting(call.arguments as List<*>, result)
                "connectToSession" -> connectToSession(call.arguments as Map<*, *>, result)
                "receiveFiles" -> receiveFiles(call.arguments as List<*>, result)
                "pause" -> { transferServer?.pause(); transferClient?.pause(); result.success(null) }
                "resume" -> { transferServer?.resume(); transferClient?.resume(); result.success(null) }
                "cancel" -> { cancelActive(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    // ---------------- Sender ----------------

    private fun startHosting(rawFiles: List<*>, result: MethodChannel.Result) {
        val manager = getSystemService(WIFI_P2P_SERVICE) as WifiP2pManager
        val channel = manager.initialize(this, mainLooper, null)
        val host = WifiDirectHost(this, manager, channel)
        wifiDirectHost = host

        val sendableFiles = rawFiles.mapNotNull { it as? Map<*, *> }.mapNotNull { m ->
            val path = m["localPath"] as? String ?: return@mapNotNull null
            val file = File(path)
            if (!file.exists()) return@mapNotNull null
            TransferServer.SendableFile(
                id = m["id"] as String,
                name = m["name"] as String,
                extension = (m["extension"] as? String).orEmpty(),
                sizeBytes = file.length(),
                sha256 = ChecksumUtil.sha256(file),
                openStream = { file.inputStream() },
            )
        }
        if (sendableFiles.isEmpty()) {
            result.error("NO_VALID_FILES", "None of the selected files had a readable path", null)
            return
        }
        val totalBytes = sendableFiles.sumOf { it.sizeBytes }
        val aggregator = ProgressAggregator(totalBytes, sendableFiles.size)

        ioExecutor.execute {
            host.createGroup(
                onReady = { group ->
                    val token = UUID.randomUUID().toString().replace("-", "").take(16)
                    val server = TransferServer(
                        files = sendableFiles,
                        token = token,
                        onBytesSent = { _, delta -> emitProgress(aggregator.onBytes(delta)) },
                        onFileStarted = { id ->
                            val name = sendableFiles.find { it.id == id }?.name
                            if (name != null) aggregator.onFileStarted(name)
                        },
                        onFileCompleted = { emitProgress(aggregator.onFileCompleted()) },
                        onError = { message -> emitProgress(aggregator.errorSnapshot(message)) },
                    )
                    val actualPort = server.start()
                    transferServer = server

                    mainHandler.post {
                        result.success(
                            mapOf(
                                "sessionId" to UUID.randomUUID().toString(),
                                "host" to group.groupOwnerAddress,
                                "port" to actualPort,
                                "token" to token,
                                "deviceName" to (Build.MODEL ?: "Android device"),
                                "ssid" to group.ssid,
                                "passphrase" to group.passphrase,
                            )
                        )
                    }
                },
                onError = { message ->
                    mainHandler.post { result.error("WIFI_DIRECT_FAILED", message, null) }
                }
            )
        }
    }

    // ---------------- Receiver ----------------

    private fun connectToSession(session: Map<*, *>, result: MethodChannel.Result) {
        val ssid = session["ssid"] as? String
        val passphrase = session["passphrase"] as? String
        sessionHost = session["host"] as String
        sessionPort = (session["port"] as Number).toInt()
        sessionToken = session["token"] as String

        val joiner = WifiJoiner(this)
        wifiJoiner = joiner

        if (ssid == null || passphrase == null) {
            result.error("MISSING_CREDENTIALS", "QR code did not contain Wi-Fi credentials", null)
            return
        }

        joiner.connect(
            ssid = ssid,
            passphrase = passphrase,
            onConnected = {
                ioExecutor.execute {
                    try {
                        val client = TransferClient(this, sessionHost, sessionPort, sessionToken)
                        val manifest = client.fetchManifest()
                        transferClient = client
                        remoteManifest = manifest
                        mainHandler.post {
                            result.success(manifest.map {
                                mapOf(
                                    "id" to it.id,
                                    "name" to it.name,
                                    "extension" to it.extension,
                                    "sizeBytes" to it.sizeBytes,
                                )
                            })
                        }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("MANIFEST_FAILED", e.message, null) }
                    }
                }
            },
            onError = { message -> mainHandler.post { result.error("WIFI_JOIN_FAILED", message, null) } }
        )
    }

    private fun receiveFiles(fileIds: List<*>, result: MethodChannel.Result) {
        val client = transferClient ?: return result.error("NOT_CONNECTED", "No active session", null)
        val targets = remoteManifest.filter { fileIds.contains(it.id) }
        val totalBytes = targets.sumOf { it.sizeBytes }
        val aggregator = ProgressAggregator(totalBytes, targets.size)
        result.success(null) // ack; real results stream over the EventChannel

        ioExecutor.execute {
            for (remoteFile in targets) {
                aggregator.onFileStarted(remoteFile.name)
                var lastReportedForThisFile = 0L
                try {
                    client.downloadFile(remoteFile) { bytesThisFile ->
                        val delta = bytesThisFile - lastReportedForThisFile
                        lastReportedForThisFile = bytesThisFile
                        if (delta > 0) emitProgress(aggregator.onBytes(delta))
                    }
                    emitProgress(aggregator.onFileCompleted())
                } catch (e: TransferClient.CancellationException) {
                    emitProgress(aggregator.cancelledSnapshot())
                    return@execute
                } catch (e: Exception) {
                    emitProgress(aggregator.errorSnapshot(e.message ?: "Transfer failed"))
                    return@execute
                }
            }
            emitProgress(aggregator.completedSnapshot())
        }
    }

    private fun cancelActive() {
        transferServer?.stop()
        transferClient?.cancel()
        wifiDirectHost?.removeGroup()
        wifiJoiner?.disconnect()
    }

    private fun emitProgress(snapshot: ProgressAggregator.Snapshot) {
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "phase" to snapshot.phase,
                    "currentFileName" to snapshot.currentFileName,
                    "filesCompleted" to snapshot.filesCompleted,
                    "filesTotal" to snapshot.filesTotal,
                    "bytesTransferred" to snapshot.bytesTransferred,
                    "bytesTotal" to snapshot.bytesTotal,
                    "speedBytesPerSecond" to snapshot.speedBytesPerSecond,
                    "etaSeconds" to snapshot.etaSeconds,
                    "errorMessage" to snapshot.errorMessage,
                )
            )
        }
    }

    override fun onDestroy() {
        cancelActive()
        ioExecutor.shutdownNow()
        super.onDestroy()
    }
}
