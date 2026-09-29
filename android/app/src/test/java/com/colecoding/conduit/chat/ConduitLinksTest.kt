package com.colecoding.conduit.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConduitLinksTest {
    private val app = "https://api.conduitcoho.app"
    private val community = "https://conduit.crowwoods.com"

    @Test
    fun `a link to the community's own domain opens in the app, keeping its query`() {
        assertEquals(
            "/tasks?tab=available",
            ConduitLinks.inAppPath("https://conduit.crowwoods.com/tasks?tab=available", app, community)
        )
    }

    @Test
    fun `a link to the app's server opens in the app too`() {
        assertEquals("/meals/12", ConduitLinks.inAppPath("https://api.conduitcoho.app/meals/12", app, community))
        assertEquals("/", ConduitLinks.inAppPath("https://api.conduitcoho.app", app, community))
    }

    @Test
    fun `other sites and odd links stay in the browser`() {
        assertNull(ConduitLinks.inAppPath("https://docs.google.com/spreadsheets/d/abc", app, community))
        assertNull(ConduitLinks.inAppPath("mailto:someone@crowwoods.com", app, community))
        assertNull(ConduitLinks.inAppPath("not a url", app, community))
    }

    @Test
    fun `without a saved community, only the app's server counts`() {
        assertNull(ConduitLinks.inAppPath("https://conduit.crowwoods.com/tasks", app, null))
    }

    @Test
    fun `each page opens in the tab it belongs to`() {
        assertEquals(ConduitLinks.Tab.TASKS, ConduitLinks.tabFor("/tasks"))
        assertEquals(ConduitLinks.Tab.TASKS, ConduitLinks.tabFor("/workstreams/3"))
        assertEquals(ConduitLinks.Tab.MEALS, ConduitLinks.tabFor("/meals/12"))
        assertEquals(ConduitLinks.Tab.HOME, ConduitLinks.tabFor("/calendar"))
        assertEquals(ConduitLinks.Tab.HOME, ConduitLinks.tabFor("/taskboard"))
    }

    @Test
    fun `a notification's path opens in the app only if it's a path on our server`() {
        assertEquals("/tasks?tab=my", ConduitLinks.notificationPath("/tasks?tab=my"))
        assertNull(ConduitLinks.notificationPath(null))
        assertNull(ConduitLinks.notificationPath("https://evil.example/tasks"))
        assertNull(ConduitLinks.notificationPath("//evil.example/tasks"))
    }
}
