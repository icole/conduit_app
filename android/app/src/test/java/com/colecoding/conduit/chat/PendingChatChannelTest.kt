package com.colecoding.conduit.chat

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class PendingChatChannelTest {
    private var now = 1_000_000L

    @Before
    fun useFakeClock() {
        PendingChatChannel.clock = { now }
        PendingChatChannel.take()
    }

    @After
    fun clear() {
        PendingChatChannel.take()
    }

    @Test
    fun `reads the channel from our own extra first`() {
        assertEquals("team:abc", PendingChatChannel.cidFrom(mapOf("channel_cid" to "team:abc", "cid" to "team:other")))
    }

    @Test
    fun `reads Stream's cid, or builds it from type and id`() {
        assertEquals("team:abc", PendingChatChannel.cidFrom(mapOf("cid" to "team:abc")))
        assertEquals("team:abc", PendingChatChannel.cidFrom(mapOf("channel_type" to "team", "channel_id" to "abc")))
    }

    @Test
    fun `has no channel when the payload doesn't name one`() {
        assertNull(PendingChatChannel.cidFrom(mapOf("channel_id" to "abc")))
        assertNull(PendingChatChannel.cidFrom(mapOf("channel_type" to "team", "channel_id" to "")))
        assertNull(PendingChatChannel.cidFrom(emptyMap()))
    }

    @Test
    fun `hands a requested channel out once`() {
        PendingChatChannel.request("team:abc")
        assertTrue(PendingChatChannel.isRequested)
        assertEquals("team:abc", PendingChatChannel.take())
        assertFalse(PendingChatChannel.isRequested)
        assertNull(PendingChatChannel.take())
    }

    @Test
    fun `a request for Chat without a channel is still a request`() {
        PendingChatChannel.request(null)
        assertTrue(PendingChatChannel.isRequested)
        assertNull(PendingChatChannel.take())
        assertFalse(PendingChatChannel.isRequested)
    }

    @Test
    fun `drops a request that has gone stale`() {
        PendingChatChannel.request("team:abc")
        now += 5 * 60 * 1000L + 1
        assertNull(PendingChatChannel.take())
    }
}
