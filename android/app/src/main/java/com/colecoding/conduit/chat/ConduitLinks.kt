package com.colecoding.conduit.chat

import java.net.URI

/**
 * Links to Conduit pages in chat (like the Chores & Coverage "pick it up"
 * link to the Available queue) open in the app's own tabs, not the browser.
 * A link is Conduit's when it's on the app's server or the community's own
 * domain; either way the app opens its path on the app's server, where the
 * user is signed in.
 */
object ConduitLinks {
    /** Set on the MainActivity intent: the path to open in its tab. */
    const val EXTRA_OPEN_PATH = "open_path"

    enum class Tab { HOME, TASKS, MEALS }

    /** "/tasks?tab=available" for a Conduit link; null for anything else. */
    fun inAppPath(url: String, appBaseUrl: String, communityUrl: String?): String? {
        val link = parse(url) ?: return null
        if (link.scheme?.lowercase() !in setOf("http", "https")) return null

        val ours = listOfNotNull(appBaseUrl, communityUrl).mapNotNull { parse(it)?.host?.lowercase() }
        if (link.host?.lowercase() !in ours) return null

        val path = link.rawPath.orEmpty().ifEmpty { "/" }
        return link.rawQuery?.let { "$path?$it" } ?: path
    }

    fun tabFor(path: String): Tab = when {
        path.isUnder("/tasks") || path.isUnder("/workstreams") -> Tab.TASKS
        path.isUnder("/meals") -> Tab.MEALS
        else -> Tab.HOME
    }

    private fun String.isUnder(section: String) = this == section || startsWith("$section/")

    private fun parse(url: String): URI? = runCatching { URI(url.trim()) }.getOrNull()
}
