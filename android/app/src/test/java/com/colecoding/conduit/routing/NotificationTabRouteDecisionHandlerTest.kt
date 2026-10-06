package com.colecoding.conduit.routing

import dev.hotwire.navigation.navigator.NavigatorConfiguration
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationTabRouteDecisionHandlerTest {
    private val handler = NotificationTabRouteDecisionHandler()
    private val mealsTab = NavigatorConfiguration(name = "meals", startLocation = "https://app.test/meals", navigatorHostId = 1)

    @After
    fun closeSheet() {
        NotificationsSheet.isOpen = false
    }

    @Test
    fun `a notification for another tab's page goes to that tab`() {
        NotificationsSheet.isOpen = true

        assertTrue(handler.matches("https://app.test/tasks", mealsTab))
        assertTrue(handler.matches("https://app.test/calendar_events/3", mealsTab))
    }

    @Test
    fun `one for this tab's pages opens here, as usual`() {
        NotificationsSheet.isOpen = true

        assertFalse(handler.matches("https://app.test/meals/5", mealsTab))
    }

    @Test
    fun `only links from the Notifications sheet are sent to other tabs`() {
        assertFalse(handler.matches("https://app.test/tasks", mealsTab))
    }

    @Test
    fun `opening the sheet itself isn't one`() {
        NotificationsSheet.isOpen = true

        assertFalse(handler.matches("https://app.test/notifications", mealsTab))
    }

    @Test
    fun `knows the Notifications page`() {
        assertTrue(NotificationsSheet.isNotifications("https://app.test/notifications"))
        assertFalse(NotificationsSheet.isNotifications("https://app.test/notifications/5"))
    }
}
