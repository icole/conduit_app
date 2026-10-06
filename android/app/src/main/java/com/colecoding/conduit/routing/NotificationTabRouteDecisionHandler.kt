package com.colecoding.conduit.routing

import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.chat.ConduitLinks
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.routing.Router

/**
 * A link in the Notifications sheet for another tab's page (a task, opened
 * from Meals) closes the sheet and opens in that tab, as chat links do,
 * instead of on top of this tab's screens.
 */
class NotificationTabRouteDecisionHandler : Router.RouteDecisionHandler {
    override val name = "notification-tab"

    override fun matches(location: String, configuration: NavigatorConfiguration): Boolean {
        if (!NotificationsSheet.isOpen || NotificationsSheet.isNotifications(location)) return false
        val path = NotificationsSheet.pathOf(location) ?: return false
        val tabPath = NotificationsSheet.pathOf(configuration.startLocation) ?: return false
        return ConduitLinks.tabFor(path) != ConduitLinks.tabFor(tabPath)
    }

    override fun handle(
        location: String,
        configuration: NavigatorConfiguration,
        activity: HotwireActivity
    ): Router.Decision {
        val main = activity as? MainActivity ?: return Router.Decision.NAVIGATE
        main.openFromNotifications(location)
        return Router.Decision.CANCEL
    }
}
