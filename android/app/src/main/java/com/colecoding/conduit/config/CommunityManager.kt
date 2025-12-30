package com.colecoding.conduit.config

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Manages the selected community URL for multi-tenant support
 */
object CommunityManager {
    private const val TAG = "CommunityManager"
    private const val PREF_NAME = "ConduitCommunityPrefs"
    private const val KEY_COMMUNITY_URL = "community_url"
    private const val KEY_COMMUNITY_NAME = "community_name"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    }

    fun getCommunityUrl(context: Context): String? {
        return getPrefs(context).getString(KEY_COMMUNITY_URL, null)
    }

    fun setCommunityUrl(context: Context, url: String) {
        Log.d(TAG, "Setting community URL: $url")
        getPrefs(context).edit().putString(KEY_COMMUNITY_URL, url).apply()
    }

    fun hasCommunityUrl(context: Context): Boolean {
        return getCommunityUrl(context) != null
    }

    fun clearCommunityUrl(context: Context) {
        Log.d(TAG, "Clearing community URL")
        getPrefs(context).edit().apply {
            remove(KEY_COMMUNITY_URL)
            remove(KEY_COMMUNITY_NAME)
            apply()
        }
    }

    fun getCommunityName(context: Context): String? {
        return getPrefs(context).getString(KEY_COMMUNITY_NAME, null)
    }

    fun setCommunityName(context: Context, name: String) {
        Log.d(TAG, "Setting community name: $name")
        getPrefs(context).edit().putString(KEY_COMMUNITY_NAME, name).apply()
    }
}
