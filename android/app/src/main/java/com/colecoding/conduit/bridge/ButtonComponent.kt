package com.colecoding.conduit.bridge

import android.content.res.ColorStateList
import android.graphics.Color
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Menu
import android.view.MenuItem
import androidx.appcompat.widget.Toolbar
import com.colecoding.conduit.R
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A page's main action (e.g. Tasks' "Add") as a native toolbar button.
 * Tapping it replies to the page, which runs the web button's own action.
 */
class ButtonComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    private val buttonItemId = 37
    private val icons = mapOf("plus" to R.drawable.ic_add, "more" to R.drawable.ic_more_vert)

    private val toolbar: Toolbar?
        get() = (delegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()

    override fun onReceive(message: Message) {
        if (message.event != "connect") return
        val data = message.data<MessageData>() ?: return

        val menu = toolbar?.menu ?: return
        menu.removeItem(buttonItemId)
        val title = SpannableString(data.title).apply {
            setSpan(ForegroundColorSpan(Color.parseColor("#00736B")), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        menu.add(Menu.NONE, buttonItemId, 999, title).apply {
            setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            // A known image shows as an icon, with the title read out by TalkBack
            icons[data.image]?.let { icon ->
                setIcon(icon)
                // The page's main action in the brand colour; overflow in the title's
                iconTintList = ColorStateList.valueOf(Color.parseColor(if (data.image == "more") "#291334" else "#00736B"))
                contentDescription = data.title
            }
            setOnMenuItemClickListener {
                replyTo("connect")
                true
            }
        }
    }

    override fun onStop() {
        toolbar?.menu?.removeItem(buttonItemId)
    }

    @Serializable
    data class MessageData(
        @SerialName("title") val title: String,
        @SerialName("image") val image: String? = null
    )
}
