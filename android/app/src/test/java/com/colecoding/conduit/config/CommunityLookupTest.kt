package com.colecoding.conduit.config

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommunityLookupTest {

    @Test
    fun `builds a lookup url with the query encoded`() {
        assertEquals(
            "https://api.conduitcoho.app/api/v1/communities/lookup?slug=willow-creek",
            CommunityLookup.lookupUrl("https://api.conduitcoho.app", "willow-creek")
        )
    }

    @Test
    fun `trims and lowercases what the user typed`() {
        assertEquals(
            "https://api.conduitcoho.app/api/v1/communities/lookup?slug=crow-woods",
            CommunityLookup.lookupUrl("https://api.conduitcoho.app", "  Crow-Woods  ")
        )
    }

    @Test
    fun `escapes characters that would break the query string`() {
        assertEquals(
            "https://example.test/api/v1/communities/lookup?slug=a+b%26c",
            CommunityLookup.lookupUrl("https://example.test", "a b&c")
        )
    }

    @Test
    fun `tolerates a base url with a trailing slash`() {
        assertEquals(
            "https://example.test/api/v1/communities/lookup?slug=x",
            CommunityLookup.lookupUrl("https://example.test/", "x")
        )
    }

    @Test
    fun `builds the start-a-community url`() {
        assertEquals("https://example.test/communities/new", CommunityLookup.signupUrl("https://example.test/"))
    }

    @Test
    fun `accepts a pasted domain as the query`() {
        assertEquals(
            "https://example.test/api/v1/communities/lookup?slug=willow-creek.conduitcoho.app",
            CommunityLookup.lookupUrl("https://example.test", "willow-creek.conduitcoho.app")
        )
    }

    @Test
    fun `blank input has no lookup url`() {
        assertNull(CommunityLookup.lookupUrl("https://example.test", "   "))
    }
}
