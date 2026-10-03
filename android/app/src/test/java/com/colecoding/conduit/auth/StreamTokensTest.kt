package com.colecoding.conduit.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.IOException

class StreamTokensTest {
    @Test
    fun `connects with the token already in hand, then fetches a fresh one each time Stream asks`() {
        var fetches = 0
        val tokens = StreamTokens(first = "first") { "fresh-${++fetches}" }

        assertEquals("first", tokens.loadToken())
        assertEquals("fresh-1", tokens.loadToken())
        assertEquals("fresh-2", tokens.loadToken())
    }

    @Test
    fun `a failed fetch is an error, not an empty token`() {
        val tokens = StreamTokens(first = "first") { null }
        tokens.loadToken()
        assertThrows(IOException::class.java) { tokens.loadToken() }
    }
}
