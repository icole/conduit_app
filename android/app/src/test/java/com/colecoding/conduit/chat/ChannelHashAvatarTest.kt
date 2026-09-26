package com.colecoding.conduit.chat

import io.getstream.chat.android.models.Channel
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChannelHashAvatarTest {
    @Test
    fun `a channel without its own image shows the hash`() {
        assertTrue(ChannelHashAvatar.showsHash(Channel(image = "")))
        assertTrue(ChannelHashAvatar.showsHash(Channel(image = "  ")))
    }

    @Test
    fun `a channel with its own image shows that image`() {
        assertFalse(ChannelHashAvatar.showsHash(Channel(image = "https://example.com/garden.jpg")))
    }
}
