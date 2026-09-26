package com.colecoding.conduit.chat

import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageButton
import io.getstream.chat.android.ui.feature.messages.MessageListFragment
import io.getstream.chat.android.ui.feature.messages.header.MessageListHeaderView

/**
 * Stream's message list with a search button in the header, just left of the
 * channel avatar, that opens ChannelSearchActivity for this channel.
 */
class TrackingMessageListFragment : MessageListFragment() {

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
