package com.colecoding.conduit.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BellComponentTest {
    @Test
    fun `TalkBack hears how many need you`() {
        assertEquals("Notifications, 3 need you", BellComponent.label("Notifications", 3))
        assertEquals("Notifications, 1 needs you", BellComponent.label("Notifications", 1))
        assertEquals("Notifications", BellComponent.label("Notifications", 0))
    }

    @Test
    fun `the badge shows the count, capped, and only when there's something`() {
        assertEquals(3, BellComponent.badgeNumber(3))
        assertEquals(99, BellComponent.badgeNumber(250))
        assertNull(BellComponent.badgeNumber(0))
    }
}
