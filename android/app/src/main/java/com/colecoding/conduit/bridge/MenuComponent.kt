package com.colecoding.conduit.bridge

import android.util.Log
import androidx.fragment.app.Fragment
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

class MenuComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    private val fragment: Fragment
        get() = delegate.destination.fragment

    override fun onReceive(message: Message) {
        when (message.event) {
            "display" -> handleDisplayEvent(message)
            else -> Log.w("MenuComponent", "Unknown event for message: $message")
        }
    }

    private fun handleDisplayEvent(message: Message) {
        val data = message.data<MessageData>() ?: return
        showDialog(data.title, data.items)
    }

    private fun showDialog(title: String, items: List<Item>) {
        val context = fragment.requireContext()
        val itemTitles = items.map { it.title }.toTypedArray()

        MaterialAlertDialogBuilder(context)
            .setTitle(title)
            .setItems(itemTitles) { _, which ->
                onItemSelected(items[which])
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun onItemSelected(item: Item) {
        replyTo("display", SelectionMessageData(item.index))
    }

    @Serializable
    data class MessageData(
        @SerialName("title") val title: String,
        @SerialName("items") val items: List<Item>
    )

    @Serializable
    data class Item(
        @SerialName("title") val title: String,
        @SerialName("index") val index: Int
    )

    @Serializable
    data class SelectionMessageData(
        @SerialName("selectedIndex") val selectedIndex: Int
    )
}
