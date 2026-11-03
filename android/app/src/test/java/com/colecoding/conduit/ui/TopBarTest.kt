package com.colecoding.conduit.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The top bar on Home, Tasks and Meals held the screen's name, which the tab
 * strip already shows, and sat under a status-bar-sized gap: Hotwire's app bar
 * pads itself for the status bar (fitsSystemWindows) while MainActivity
 * already pads the whole screen for it, so on Android 15+ the gap came twice.
 * Chat likewise opened with a "Chat" heading above its search bar.
 */
class TopBarTest {
    private val webFragment =
        File("src/main/java/com/colecoding/conduit/fragments/WebFragment.kt").readText()
    private val chatFragment =
        File("src/main/java/com/colecoding/conduit/fragments/CustomChatFragment.kt").readText()

    @Test
    fun `the app bar leaves the status bar to MainActivity`() {
        assertTrue(webFragment.contains("fitsSystemWindows = false"))
    }

    @Test
    fun `a tab's first screen shows no title`() {
        assertTrue(webFragment.contains("override fun shouldObserveTitleChanges()"))
        assertTrue(webFragment.contains("isAtStartDestination()"))
    }

    @Test
    fun `chat opens on its search bar, with no heading`() {
        assertFalse(chatFragment.contains("text = \"Chat\""))
    }
}
