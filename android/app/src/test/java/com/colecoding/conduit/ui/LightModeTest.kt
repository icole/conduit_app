package com.colecoding.conduit.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Chat is drawn by Stream's library, whose colours have dark-mode variants
 * (values-night). The app sets Stream's text and backgrounds to the website's
 * palette for daytime only, so with the phone in dark mode Stream's near-black
 * backgrounds came back under our dark ink: chat names were black on black.
 * The website has no dark mode, so the app keeps to light mode rather than
 * carrying a second palette.
 */
class LightModeTest {
    @Test
    fun `the app stays in light mode whatever the phone is set to`() {
        val app = File("src/main/java/com/colecoding/conduit/MainApplication.kt").readText()
        assertTrue(app.contains("AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)"))
    }

    @Test
    fun `no colours have a dark-mode variant to mix with the light ones`() {
        assertFalse(File("src/main/res/values-night").exists())
    }
}
