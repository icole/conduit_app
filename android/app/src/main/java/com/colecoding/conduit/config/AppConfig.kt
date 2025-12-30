package com.colecoding.conduit.config

import android.content.Context
import android.util.Log
import com.colecoding.conduit.BuildConfig

object AppConfig {
    private const val TAG = "AppConfig"

    // Communities API URL
    const val COMMUNITIES_API_URL = "https://api.conduitcoho.app"

    fun getBaseUrl(context: Context): String {
        // Check for user-selected community URL first
        val communityUrl = CommunityManager.getCommunityUrl(context)
        if (communityUrl != null) {
            Log.d(TAG, "Using selected community URL: $communityUrl")
            return communityUrl
        }

        // Check for runtime configuration file (similar to iOS Config.plist)
        val configUrl = loadUrlFromConfig(context)
        if (configUrl != null) {
            Log.d(TAG, "Using URL from config: $configUrl")
            return configUrl
        }

        // Fall back to build configuration
        val url = BuildConfig.BASE_URL
        Log.d(TAG, "Using build config URL: $url")
        return url
    }

    private fun loadUrlFromConfig(context: Context): String? {
        try {
            // Try to load from a config file in assets
            if (context.assets.list("")?.contains("config.properties") == true) {
                val properties = context.assets.open("config.properties").use { input ->
                    java.util.Properties().apply { load(input) }
                }
                return properties.getProperty("base_url")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load config", e)
        }
        return null
    }

    fun getStreamApiKey(context: Context): String {
        // Use BuildConfig for better security
        return BuildConfig.STREAM_API_KEY
    }

    fun isDebugBuild(): Boolean {
        return BuildConfig.DEBUG
    }
}