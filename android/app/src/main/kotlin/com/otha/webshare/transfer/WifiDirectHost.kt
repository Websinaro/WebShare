package com.otha.webshare.transfer

import android.content.Context
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pGroup
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build

/**
 * Sender side of the Wi-Fi Direct handshake: stands up a P2P group with
 * this device as group owner. Once formed, the group owner's address is
 * always 192.168.49.1 on stock AOSP Wi-Fi Direct — that's what lets the
 * server bind a known address without waiting on DHCP first.
 */
class WifiDirectHost(
    private val context: Context,
    private val manager: WifiP2pManager,
    private val channel: WifiP2pManager.Channel,
) {
    data class GroupInfo(val ssid: String, val passphrase: String, val groupOwnerAddress: String)

    @Suppress("MissingPermission") // caller verifies NEARBY_WIFI_DEVICES/ACCESS_FINE_LOCATION first
    fun createGroup(onReady: (GroupInfo) -> Unit, onError: (String) -> Unit) {
        removeGroup {
            manager.createGroup(channel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    manager.requestGroupInfo(channel) { group: WifiP2pGroup? ->
                        if (group == null) {
                            onError("Group formed but info unavailable")
                            return@requestGroupInfo
                        }
                        val ssid = group.networkName
                        val passphrase = group.passphrase
                        if (ssid == null || passphrase == null) {
                            onError("Group owner did not expose SSID/passphrase")
                            return@requestGroupInfo
                        }
                        onReady(GroupInfo(ssid, passphrase, GROUP_OWNER_ADDRESS))
                    }
                }

                override fun onFailure(reason: Int) {
                    onError("createGroup failed: ${describeFailure(reason)}")
                }
            })
        }
    }

    @Suppress("MissingPermission")
    fun removeGroup(then: () -> Unit = {}) {
        manager.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = then()
            override fun onFailure(reason: Int) = then() // no existing group is fine
        })
    }

    private fun describeFailure(reason: Int): String = when (reason) {
        WifiP2pManager.P2P_UNSUPPORTED -> "Wi-Fi Direct not supported on this device"
        WifiP2pManager.BUSY -> "Wi-Fi Direct busy — try again"
        WifiP2pManager.ERROR -> "Internal Wi-Fi Direct error"
        else -> "Unknown ($reason)"
    }

    companion object {
        const val GROUP_OWNER_ADDRESS = "192.168.49.1"
    }
}
