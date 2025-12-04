package com.colecoding.conduit.chat

import android.util.Log

/**
 * Singleton to track which channel the user is currently viewing
 * Used to suppress push notifications for the active channel
 */
object ChatViewTracker {
    private const val TAG = "ChatViewTracker"
    private var currentlyViewingChannelCid: String? = null

    /**
     * Set the channel that the user is currently viewing
     */
    fun setCurrentlyViewingChannel(cid: String?) {
        currentlyViewingChannelCid = cid
        if (cid != null) {
            Log.d(TAG, "👀 User now viewing channel: $cid")
        } else {
            Log.d(TAG, "👀 User left channel")
        }
    }

    /**
     * Check if the user is currently viewing a specific channel
     */
    fun isCurrentlyViewingChannel(cid: String): Boolean {
        return currentlyViewingChannelCid == cid
    }
}
