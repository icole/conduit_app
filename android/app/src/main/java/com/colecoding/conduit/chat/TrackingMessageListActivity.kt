package com.colecoding.conduit.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.getstream.chat.android.ui.feature.messages.MessageListActivity

/**
 * Wrapper around Stream's MessageListActivity that tracks when user is viewing a channel
 * This is used to suppress push notifications for the currently viewed channel
 */
class TrackingMessageListActivity : MessageListActivity() {

    companion object {
        private const val TAG = "TrackingMessageListActivity"
        private const val EXTRA_CID = "extra_cid"

        fun createIntent(context: Context, cid: String): Intent {
            // Use Stream's public createIntent and change the target class
            return MessageListActivity.createIntent(context, cid).apply {
                setClass(context, TrackingMessageListActivity::class.java)
            }
        }
    }

    private var channelCid: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Extract CID from the intent that Stream's parent class uses
        channelCid = intent.getStringExtra(EXTRA_CID)
        Log.d(TAG, "onCreate - channel: $channelCid")
    }

    override fun onResume() {
        super.onResume()
        // Notify tracker that user is viewing this channel
        channelCid?.let { cid ->
            ChatViewTracker.setCurrentlyViewingChannel(cid)
        }
    }

    override fun onPause() {
        super.onPause()
        // Notify tracker that user left this channel
        ChatViewTracker.setCurrentlyViewingChannel(null)
    }
}
