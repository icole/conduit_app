package com.colecoding.conduit.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class EdgePaddingTest {

    private val noPadding = EdgePadding(0, 0, 0, 0)

    // Typical API 36 phone: 3-button-less gesture nav, status bar at top.
    private val systemBars = EdgePadding(left = 0, top = 84, right = 0, bottom = 48)

    @Test
    fun `applies only the requested edges`() {
        val result = noPadding.plusInsets(systemBars, setOf(Edge.TOP))

        assertEquals(EdgePadding(0, 84, 0, 0), result)
    }

    @Test
    fun `preserves the padding already declared in the layout`() {
        // activity_login.xml declares android:padding="24dp"
        val declared = EdgePadding(24, 24, 24, 24)

        val result = declared.plusInsets(systemBars, setOf(Edge.TOP, Edge.BOTTOM))

        assertEquals(EdgePadding(24, 108, 24, 72), result)
    }

    @Test
    fun `is idempotent across repeated inset dispatches`() {
        // WindowInsets are dispatched again on rotation, keyboard show, gesture
        // mode change. Padding must not accumulate.
        val once = noPadding.plusInsets(systemBars, Edge.ALL)
        val twice = noPadding.plusInsets(systemBars, Edge.ALL)

        assertEquals(once, twice)
    }

    @Test
    fun `applies horizontal insets for display cutouts in landscape`() {
        val landscapeCutout = EdgePadding(left = 66, top = 0, right = 66, bottom = 32)

        val result = noPadding.plusInsets(landscapeCutout, Edge.ALL)

        assertEquals(EdgePadding(66, 0, 66, 32), result)
    }

    @Test
    fun `is a no-op on pre-edge-to-edge devices where insets are already consumed`() {
        // On API 28-34 the decor view consumes system window insets, so the
        // content root receives zeroes and must keep its declared padding.
        val declared = EdgePadding(24, 24, 24, 24)

        val result = declared.plusInsets(noPadding, Edge.ALL)

        assertEquals(declared, result)
    }
}
