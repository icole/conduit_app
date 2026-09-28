package com.colecoding.conduit.chat

import android.content.Intent
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageButton
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.config.AppConfig
import com.colecoding.conduit.config.CommunityManager
import io.getstream.chat.android.ui.feature.messages.MessageListFragment
import io.getstream.chat.android.ui.feature.messages.header.MessageListHeaderView
import io.getstream.chat.android.ui.feature.messages.list.MessageListView

/**
 * Stream's message list with a search button in the header, just left of the
 * channel avatar, that opens ChannelSearchActivity for this channel; and
 * Conduit links in messages open in the app's tabs rather than the browser.
 */
class TrackingMessageListFragment : MessageListFragment() {

    override fun setupMessageList(messageListView: MessageListView) {
        super.setupMessageList(messageListView)

        // Returning false leaves other links to Stream (the browser)
        messageListView.setOnLinkClickListener { url ->
            val context = requireContext()
            val path = ConduitLinks.inAppPath(url, AppConfig.getBaseUrl(context), CommunityManager.getCommunityUrl(context))
                ?: return@setOnLinkClickListener false

            startActivity(
                Intent(context, MainActivity::class.java)
                    .putExtra(ConduitLinks.EXTRA_OPEN_PATH, path)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            )
            true
        }
    }

    override fun setupMessageListHeader(messageListHeaderView: MessageListHeaderView) {
        super.setupMessageListHeader(messageListHeaderView)

        val cid = requireActivity().intent.getStringExtra("extra_cid") ?: return
        val density = resources.displayMetrics.density
        val size = (40 * density).toInt()
        // The avatar is 40dp with an 8dp end margin; sit to its left
        val marginEnd = (56 * density).toInt()

        val searchButton = ImageButton(requireContext()).apply {
            setImageResource(io.getstream.chat.android.ui.R.drawable.stream_ui_ic_search)
            background = null
            contentDescription = "Search this chat"
            setOnClickListener { startActivity(ChannelSearchActivity.createIntent(requireContext(), cid)) }
        }
        messageListHeaderView.addView(
            searchButton,
            FrameLayout.LayoutParams(size, size, Gravity.END or Gravity.CENTER_VERTICAL).apply {
                this.marginEnd = marginEnd
            }
        )
    }
}
