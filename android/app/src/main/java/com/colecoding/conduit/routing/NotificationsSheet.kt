package com.colecoding.conduit.routing

import java.net.URI

/** The Notifications sheet (CON-72), and whether it's open, so its links can go to their own tab. */
object NotificationsSheet {
    var isOpen = false

    fun isNotifications(location: String): Boolean = pathOf(location) == "/notifications"

    fun pathOf(location: String): String? = runCatching { URI(location).path }.getOrNull()
}
