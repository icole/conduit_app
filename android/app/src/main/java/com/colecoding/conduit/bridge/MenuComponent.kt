package com.colecoding.conduit.bridge

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.google.android.material.bottomsheet.BottomSheetDialog
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import com.colecoding.conduit.ui.Palette

/**
 * A page's "more" menu as a bottom sheet. Picking an item replies with its
 * index, and the page clicks the matching link or button.
 */
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
        showSheet(data.title, data.items)
    }

    private fun showSheet(title: String, items: List<Item>) {
        val context = fragment.requireContext()
        val sheet = BottomSheetDialog(context)
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        val ripple = TypedValue().also {
            context.theme.resolveAttribute(android.R.attr.selectableItemBackground, it, true)
        }.resourceId

        val list = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, dp(24))
            background = GradientDrawable().apply {
                setColor(Palette.paper)
                val radius = dp(28).toFloat()
                cornerRadii = floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f)
            }
        }

        // Drag handle
        list.addView(View(context).apply {
            background = GradientDrawable().apply {
                setColor(Palette.divider)
                cornerRadius = dp(2).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(dp(32), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(8)
            }
        })

        list.addView(TextView(context).apply {
            text = title
            textSize = 14f
            setTextColor(Palette.muted)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(24), dp(8), dp(24), dp(8))
        })

        items.forEach { item ->
            list.addView(TextView(context).apply {
                text = item.title
                textSize = 16f
                setTextColor(if (item.destructive) Palette.destructive else Palette.ink)
                gravity = Gravity.CENTER_VERTICAL
                minHeight = dp(56)
                setPadding(dp(24), 0, dp(24), 0)
                setBackgroundResource(ripple)
                setOnClickListener {
                    sheet.dismiss()
                    onItemSelected(item)
                }
            })
        }

        sheet.setContentView(list)
        // Let the rounded corners show instead of the sheet's square backdrop
        sheet.setOnShowListener {
            sheet.findViewById<View>(com.google.android.material.R.id.design_bottom_sheet)
                ?.setBackgroundColor(Color.TRANSPARENT)
        }
        sheet.show()
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
        @SerialName("index") val index: Int,
        @SerialName("destructive") val destructive: Boolean = false
    )

    @Serializable
    data class SelectionMessageData(
        @SerialName("selectedIndex") val selectedIndex: Int
    )
}
