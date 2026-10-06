package com.colecoding.conduit.bridge

import android.content.res.ColorStateList
import android.graphics.Color
import android.view.Menu
import android.view.MenuItem
import androidx.appcompat.widget.Toolbar
import com.colecoding.conduit.R
import com.google.android.material.badge.BadgeDrawable
import com.google.android.material.badge.BadgeUtils
import com.google.android.material.badge.ExperimentalBadgeUtils
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * The notification bell in the top bar (CON-72). Every page sends the count
 * of what needs the member; tapping replies, and the page opens Notifications.
 * It sits left of the page's own button (ButtonComponent).
 */
class BellComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    private val bellItemId = 38
    private var badge: BadgeDrawable? = null

    private val toolbar: Toolbar?
        get() = (delegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()

    override fun onReceive(message: Message) {
        if (message.event != "connect") return
        val data = message.data<MessageData>() ?: return
        val toolbar = toolbar ?: return

        toolbar.menu.removeItem(bellItemId)
        toolbar.menu.add(Menu.NONE, bellItemId, 998, data.title).apply {
            setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            setIcon(R.drawable.ic_notifications)
            iconTintList = ColorStateList.valueOf(Color.parseColor("#291334"))
            contentDescription = label(data.title, data.count)
            setOnMenuItemClickListener {
                replyTo("connect")
                true
            }
        }
        showBadge(toolbar, badgeNumber(data.count))
    }

    // Back on screen (a sheet closed, or back from another screen): ask the
    // page for the current count, which may have changed meanwhile
    override fun onStart() {
        replyTo("connect", """{"refresh":true}""")
    }

    override fun onStop() {
        toolbar?.let { removeBadge(it); it.menu.removeItem(bellItemId) }
    }

    @OptIn(ExperimentalBadgeUtils::class)
    private fun showBadge(toolbar: Toolbar, number: Int?) {
        removeBadge(toolbar)
        number ?: return
        // After layout, once the menu item has a view to anchor to
        toolbar.post {
            val drawable = BadgeDrawable.create(toolbar.context).apply {
                this.number = number
                backgroundColor = Color.parseColor("#F4C430")
                badgeTextColor = Color.parseColor("#291334")
            }
            BadgeUtils.attachBadgeDrawable(drawable, toolbar, bellItemId)
            badge = drawable
        }
    }

    @OptIn(ExperimentalBadgeUtils::class)
    private fun removeBadge(toolbar: Toolbar) {
        badge?.let { BadgeUtils.detachBadgeDrawable(it, toolbar, bellItemId) }
        badge = null
    }

    @Serializable
    data class MessageData(
        @SerialName("title") val title: String,
        @SerialName("count") val count: Int = 0
    )

    companion object {
        fun label(title: String, count: Int): String = when {
            count <= 0 -> title
            count == 1 -> "$title, 1 needs you"
            else -> "$title, $count need you"
        }

        fun badgeNumber(count: Int): Int? = if (count > 0) count.coerceAtMost(99) else null
    }
}
