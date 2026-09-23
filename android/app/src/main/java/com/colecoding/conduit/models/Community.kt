package com.colecoding.conduit.models

import org.json.JSONObject

/**
 * Data class representing a community from the API
 */
data class Community(
    val id: Int,
    val name: String,
    val domain: String,
    val slug: String,
    /** "pending", "active" or null on responses from older servers. */
    val status: String? = null
) {
    val isPending: Boolean get() = status == "pending"

    companion object {
        fun fromJson(json: JSONObject): Community {
            return Community(
                id = json.getInt("id"),
                name = json.getString("name"),
                domain = json.getString("domain"),
                slug = json.getString("slug"),
                status = if (json.isNull("status")) null else json.optString("status", null)
            )
        }
    }
}
