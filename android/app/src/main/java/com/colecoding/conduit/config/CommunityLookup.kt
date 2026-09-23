package com.colecoding.conduit.config

import java.net.URLEncoder

/**
 * URL building for finding a single community by name, instead of downloading a
 * list of every community on the server. Pure functions so they can be unit tested.
 */
object CommunityLookup {

    /** The lookup endpoint for what the user typed, or null if they typed nothing. */
    fun lookupUrl(baseUrl: String, query: String): String? {
        val normalized = normalize(query)
        if (normalized.isEmpty()) return null

        val encoded = URLEncoder.encode(normalized, "UTF-8")
        return "${trimSlash(baseUrl)}/api/v1/communities/lookup?slug=$encoded"
    }

    /** The web form for starting a new community. */
    fun signupUrl(baseUrl: String): String = "${trimSlash(baseUrl)}/communities/new"

    /** Slugs and domains are lowercase; people paste with stray spaces and capitals. */
    fun normalize(query: String): String = query.trim().lowercase()

    private fun trimSlash(baseUrl: String): String = baseUrl.trimEnd('/')
}
