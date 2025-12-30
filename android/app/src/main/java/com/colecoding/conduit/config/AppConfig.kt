package com.colecoding.conduit.config

import android.content.Context
import android.util.Log
import com.colecoding.conduit.BuildConfig

object AppConfig {
    private const val TAG = "AppConfig"

    // Communities API URL
    const val COMMUNITIES_API_URL = "https://api.conduitcoho.app"

    fun getBaseUrl(context: Context): String {
        // In debug mode, use build config URL (localhost for emulator)
        if (BuildConfig.DEBUG) {
            val url = BuildConfig.BASE_URL
            Log.d(TAG, "Debug mode - Using build config URL: $url")
            return url
        }

        // In release mode, always use the central API domain
        // The backend determines the tenant from the JWT token
        Log.d(TAG, "Release mode - Using central API URL: $COMMUNITIES_API_URL")
        return COMMUNITIES_API_URL
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