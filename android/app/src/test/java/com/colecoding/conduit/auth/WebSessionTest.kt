package com.colecoding.conduit.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WebSessionTest {
    @Test
    fun `the web views need signing in until they have a session cookie`() {
        assertTrue(WebSession.needsSignIn(null))
        assertTrue(WebSession.needsSignIn("theme=dark"))
        assertFalse(WebSession.needsSignIn("theme=dark; _conduit_app_session=abc123"))
    }

    @Test
    fun `picks the session cookie out of what the server set`() {
        val headers = listOf(
            "theme=dark; path=/",
            "_conduit_app_session=abc123; path=/; secure; httponly; samesite=lax"
        )
        assertEquals(
            "_conduit_app_session=abc123; path=/; secure; httponly; samesite=lax",
            WebSession.sessionCookie(headers)
        )
        assertNull(WebSession.sessionCookie(listOf("theme=dark; path=/")))
    }

    @Test
    fun `the code is redeemed at auth_login, escaped`() {
        assertEquals(
            "https://example.com/auth_login?token=a.b%2Bc",
            WebSession.redeemUrl("https://example.com/", "a.b+c")
        )
    }
}
