package com.colecoding.conduit.chat

import io.getstream.chat.android.models.ChannelMute

/**
 * Whether a channel is muted for the signed-in person. Muting is per person
 * in Stream (ChannelClient.mute), so this reads the person's own mutes; the
 * channel's name is shared by everyone and never carries it.
 */
object ChannelMutes {
    fun isMuted(cid: String, mutes: List<ChannelMute>): Boolean = mutes.any { it.channel?.cid == cid }
}
