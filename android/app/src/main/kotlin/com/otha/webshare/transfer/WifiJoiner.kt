package com.otha.webshare.transfer

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * Receiver side: joins the Wi-Fi Direct group's underlying access point
 * using the SSID/passphrase carried in the QR code, as a normal Wi-Fi
 * client connection (not the WifiP2pManager peer-discovery flow, which
 * would require both devices to have discovered each other first).
 *
 * Two code paths because the API for "connect to a specific SSID/PSK
 * programmatically" was redesigned in Android 10:
 *  - API 29+: WifiNetworkSpecifier via ConnectivityManager.requestNetwork.
 *  - API 23-28: legacy WifiManager.addNetwork/enableNetwork. Deprecated,
 *    but there is no replacement on those OS versions, so it's the only
 *    functional path there. Behavior varies more by OEM on this branch —
 *    this is the part most likely to need per-device follow-up fixes.
 */
class WifiJoiner(private val context: Context) {

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var boundNetwork: Network? = null

    fun connect(ssid: String, passphrase: String, onConnected: () -> Unit, onError: (String) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectModern(ssid, passphrase, onConnected, onError)
        } else {
            connectLegacy(ssid, passphrase, onConnected, onError)
        }
    }

    fun disconnect() {
        networkCallback?.let { runCatching { connectivityManager.unregisterNetworkCallback(it) } }
        networkCallback = null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            runCatching { connectivityManager.bindProcessToNetwork(null) }
        } else {
            runCatching { connectivityManager.bindProcessToNetwork(null) }
        }
        boundNetwork = null
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun connectModern(ssid: String, passphrase: String, onConnected: () -> Unit, onError: (String) -> Unit) {
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(passphrase)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Route this app's sockets through the P2P network specifically —
                // otherwise Socket() may still try the phone's normal Wi-Fi/cell path.
                connectivityManager.bindProcessToNetwork(network)
                boundNetwork = network
                onConnected()
            }

            override fun onUnavailable() {
                onError("Could not join $ssid — check both devices are in range")
            }
        }
        networkCallback = callback
        connectivityManager.requestNetwork(request, callback, 20_000)
    }

    @Suppress("DEPRECATION")
    private fun connectLegacy(ssid: String, passphrase: String, onConnected: () -> Unit, onError: (String) -> Unit) {
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val config = WifiConfiguration().apply {
            SSID = "\"$ssid\""
            preSharedKey = "\"$passphrase\""
        }
        val networkId = wifiManager.addNetwork(config)
        if (networkId == -1) {
            onError("Failed to add network configuration for $ssid")
            return
        }
        wifiManager.disconnect()
        val enabled = wifiManager.enableNetwork(networkId, true)
        wifiManager.reconnect()
        if (!enabled) {
            onError("Failed to enable network $ssid")
            return
        }
        // No reliable connected-callback pre-API 29; poll briefly instead.
        Thread {
            var attempts = 0
            while (attempts < 40) {
                val info = wifiManager.connectionInfo
                val currentSsid = info?.ssid?.removeSurrounding("\"")
                if (currentSsid == ssid) {
                    onConnected()
                    return@Thread
                }
                Thread.sleep(250)
                attempts++
            }
            onError("Timed out joining $ssid")
        }.start()
    }
}
