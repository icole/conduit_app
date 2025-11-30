package com.colecoding.conduit.config

import android.content.Context
import android.util.Log
import com.colecoding.conduit.BuildConfig

object AppConfig {
    private const val TAG = "AppConfig"

    fun getBaseUrl(context: Context): String {
        // Check for runtime configuration file first (similar to iOS Config.plist)
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
        // In production, you might want to fetch this securely
        // For now, using a string resource
        return "psybsap3ftmn"
    }

    fun isDebugBuild(): Boolean {
        return BuildConfig.DEBUG
    }
}