package com.colecoding.conduit.models

import org.json.JSONArray
import org.json.JSONObject

/**
 * Data class representing a community from the API
 */
data class Community(
    val id: Int,
    val name: String,
    val domain: String,
    val slug: String
) {
    companion object {
        fun fromJson(json: JSONObject): Community {
            return Community(
                id = json.getInt("id"),
                name = json.getString("name"),
                domain = json.getString("domain"),
                slug = json.getString("slug")
            )
        }

        fun listFromJson(jsonArray: JSONArray): List<Community> {
            val communities = mutableListOf<Community>()
            for (i in 0 until jsonArray.length()) {
                communities.add(fromJson(jsonArray.getJSONObject(i)))
            }
            return communities
        }
    }
}
