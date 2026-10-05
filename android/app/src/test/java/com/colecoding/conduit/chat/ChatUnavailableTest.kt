package com.colecoding.conduit.chat

import org.junit.Assert.assertEquals
import org.junit.Test

class ChatUnavailableTest {
    @Test
    fun `each reason the server gives has its own explanation`() {
        assertEquals("Chat opens once your community is approved.", ChatUnavailable.message("community_not_active"))
        assertEquals("Chat isn't turned on for your community.", ChatUnavailable.message("chat_disabled"))
        assertEquals(
            "Verify your email address to use chat: use the link we emailed you, or send a new one from Account.",
            ChatUnavailable.message("email_unverified")
        )
    }

    @Test
    fun `anything else, or no reason, says to try again`() {
        assertEquals("Chat couldn't load. Check your connection and try again.", ChatUnavailable.message(null))
        assertEquals("Chat couldn't load. Check your connection and try again.", ChatUnavailable.message("something_new"))
    }

    @Test
    fun `the reason is read from the server's refusal`() {
        assertEquals("chat_disabled", ChatUnavailable.reasonFrom("""{"error":"chat_disabled"}"""))
        assertEquals(null, ChatUnavailable.reasonFrom("not json"))
        assertEquals(null, ChatUnavailable.reasonFrom(null))
    }
}
