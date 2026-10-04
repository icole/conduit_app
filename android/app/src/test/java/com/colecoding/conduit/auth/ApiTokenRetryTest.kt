package com.colecoding.conduit.auth

import org.junit.Assert.assertEquals
import org.junit.Test

class ApiTokenRetryTest {
    private val calls = mutableListOf<String>()
    private var refreshes = 0

    private fun call(token: String?, newToken: String?, replies: Map<String, ApiReply<String>>) =
        ApiTokenRetry.call(token, refresh = { refreshes++; newToken }) { used ->
            calls += used
            replies.getValue(used)
        }

    @Test
    fun `a good token is used as is`() {
        assertEquals(ApiReply.Ok("chat"), call("old", "new", mapOf("old" to ApiReply.Ok("chat"))))
        assertEquals(0, refreshes)
    }

    @Test
    fun `an expired token is refreshed once and the call retried`() {
        val reply = call("old", "new", mapOf("old" to ApiReply.Unauthorized, "new" to ApiReply.Ok("chat")))
        assertEquals(ApiReply.Ok("chat"), reply)
        assertEquals(listOf("old", "new"), calls)
    }

    @Test
    fun `when the token can't be refreshed, the member has to sign in again`() {
        assertEquals(ApiReply.Unauthorized, call("old", null, mapOf("old" to ApiReply.Unauthorized)))
        assertEquals(listOf("old"), calls)
    }

    @Test
    fun `it retries only once`() {
        val reply = call("old", "new", mapOf("old" to ApiReply.Unauthorized, "new" to ApiReply.Unauthorized))
        assertEquals(ApiReply.Unauthorized, reply)
        assertEquals(1, refreshes)
    }

    @Test
    fun `no token at all means signing in, without a call`() {
        assertEquals(ApiReply.Unauthorized, call(null, "new", emptyMap()))
        assertEquals(emptyList<String>(), calls)
    }

    @Test
    fun `a server or network failure isn't treated as signed out`() {
        assertEquals(ApiReply.Failed, call("old", "new", mapOf("old" to ApiReply.Failed)))
        assertEquals(0, refreshes)
    }
}
