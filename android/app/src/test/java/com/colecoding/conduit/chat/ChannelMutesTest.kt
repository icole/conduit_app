package com.colecoding.conduit.chat

import io.getstream.chat.android.models.Channel
import io.getstream.chat.android.models.ChannelMute
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

class ChannelMutesTest {
    private fun muteOf(type: String, id: String) =
        ChannelMute(user = null, channel = Channel(type = type, id = id), createdAt = Date(), updatedAt = Date(), expires = null)

    @Test
    fun `a channel is muted when it's in the person's own mutes`() {
        val mutes = listOf(muteOf("team", "crow-woods-general"))
        assertTrue(ChannelMutes.isMuted("team:crow-woods-general", mutes))
        assertFalse(ChannelMutes.isMuted("team:crow-woods-events", mutes))
    }

    @Test
    fun `nothing is muted with no mutes`() {
        assertFalse(ChannelMutes.isMuted("team:crow-woods-general", emptyList()))
    }
}
