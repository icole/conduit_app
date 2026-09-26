package com.colecoding.conduit.chat

import android.content.Intent
import android.os.Bundle
import android.os.SystemClock

/**
 * The chat channel a tapped notification asked for, kept until the chat is
 * connected and can open it. Taps can arrive before sign-in, before the Chat
 * tab exists, or while Stream is still connecting, so nothing opens the
 * channel on a timer; CustomChatFragment takes it once it's ready.
 */
object PendingChatChannel {
    /** Set by PushNotificationService on the notifications it builds. */
    const val EXTRA_CHANNEL_CID = "channel_cid"
    const val EXTRA_OPEN_CHAT = "open_chat"

    // A request older than this is dropped, so a stale tap never opens a chat later.
    private const val MAX_AGE_MS = 5 * 60 * 1000L

    /** Monotonic milliseconds; swapped in tests. */
    internal var clock: () -> Long = { SystemClock.elapsedRealtime() }

    private var requested = false
    private var cid: String? = null
    private var requestedAt = 0L

    val isRequested: Boolean
        @Synchronized get() = requested

    @Synchronized
    fun request(cid: String?) {
        requested = true
        this.cid = cid
        requestedAt = clock()
    }

    /** The requested channel, handed out once (null if none, or too old). */
    @Synchronized
    fun take(): String? {
        val pending = cid?.takeIf { clock() - requestedAt < MAX_AGE_MS }
        requested = false
        cid = null
        return pending
    }

    /**
     * Records a notification tap carried by [intent], then strips it from the
     * intent so recreating the activity doesn't open the channel again.
     * Handles our own notifications (channel_cid) and ones Android draws itself
     * from Stream's data (cid, or channel_type + channel_id, with sender).
     */
    fun recordFrom(intent: Intent?) {
        val extras = intent?.extras ?: return
        val fromChatNotification = extras.containsKey(EXTRA_CHANNEL_CID) ||
            extras.getBoolean(EXTRA_OPEN_CHAT, false) ||
            extras.getString("sender") == "stream.chat"
        if (!fromChatNotification) return

        request(cidFrom(extras))
        listOf(EXTRA_CHANNEL_CID, EXTRA_OPEN_CHAT, "cid", "channel_id", "channel_type", "sender")
            .forEach { intent.removeExtra(it) }
    }

    fun cidFrom(extras: Bundle): String? = cidFrom { key -> extras.getString(key) }

    fun cidFrom(data: Map<String, String>): String? = cidFrom { key -> data[key] }

    /** "team:abc123", from whichever keys the payload has. */
    private fun cidFrom(value: (String) -> String?): String? {
        value(EXTRA_CHANNEL_CID)?.takeIf { it.isNotBlank() }?.let { return it }
        value("cid")?.takeIf { it.isNotBlank() }?.let { return it }
        val type = value("channel_type")?.takeIf { it.isNotBlank() }
        val id = value("channel_id")?.takeIf { it.isNotBlank() }
        return if (type != null && id != null) "$type:$id" else null
    }
}
