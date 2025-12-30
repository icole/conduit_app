package com.colecoding.conduit.auth

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject

object AuthManager {
    private const val PREF_NAME = "ConduitAuthPrefs"
    private const val KEY_USER_ID = "user_id"
    private const val KEY_USER_NAME = "user_name"
    private const val KEY_USER_EMAIL = "user_email"
    private const val KEY_SESSION_COOKIE = "session_cookie"
    private const val KEY_IS_AUTHENTICATED = "is_authenticated"
    private const val KEY_STREAM_TOKEN = "stream_chat_token"
    private const val KEY_AUTH_TOKEN = "auth_token"
    private const val KEY_RESTRICTED_ACCESS = "restricted_access"
    private const val KEY_COMMUNITY_SLUG = "community_slug"

    private const val TAG = "AuthManager"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    }

    fun saveAuthData(
        context: Context,
        userId: String,
        userName: String,
        userEmail: String,
        sessionCookie: String,
        authToken: String? = null
    ) {
        Log.d(TAG, "Saving auth data for user: $userId")
        getPrefs(context).edit().apply {
            putString(KEY_USER_ID, userId)
            putString(KEY_USER_NAME, userName)
            putString(KEY_USER_EMAIL, userEmail)
            putString(KEY_SESSION_COOKIE, sessionCookie)
            authToken?.let { putString(KEY_AUTH_TOKEN, it) }
            putBoolean(KEY_IS_AUTHENTICATED, true)
            apply()
        }
    }

    fun getAuthToken(context: Context): String? {
        return getPrefs(context).getString(KEY_AUTH_TOKEN, null)
    }

    fun setAuthToken(context: Context, token: String) {
        getPrefs(context).edit().putString(KEY_AUTH_TOKEN, token).apply()
    }

    fun isAuthenticated(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_AUTHENTICATED, false)
    }

    fun getUserId(context: Context): String? {
        return getPrefs(context).getString(KEY_USER_ID, null)
    }

    fun getUserName(context: Context): String? {
        return getPrefs(context).getString(KEY_USER_NAME, null)
    }

    fun getUserEmail(context: Context): String? {
        return getPrefs(context).getString(KEY_USER_EMAIL, null)
    }

    fun getSessionCookie(context: Context): String? {
        return getPrefs(context).getString(KEY_SESSION_COOKIE, null)
    }

    fun setUserId(context: Context, userId: String) {
        Log.d(TAG, "Setting user ID: $userId")
        getPrefs(context).edit().putString(KEY_USER_ID, userId).apply()
    }

    fun setUserName(context: Context, userName: String) {
        Log.d(TAG, "Setting user name: $userName")
        getPrefs(context).edit().putString(KEY_USER_NAME, userName).apply()
    }

    fun setStreamChatToken(context: Context, token: String) {
        Log.d(TAG, "Setting Stream Chat token")
        getPrefs(context).edit().putString(KEY_STREAM_TOKEN, token).apply()
    }

    fun setRestrictedAccess(context: Context, restricted: Boolean) {
        Log.d(TAG, "Setting restricted access: $restricted")
        getPrefs(context).edit().putBoolean(KEY_RESTRICTED_ACCESS, restricted).apply()
    }

    fun isRestrictedAccess(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_RESTRICTED_ACCESS, false)
    }

    fun setCommunitySlug(context: Context, slug: String) {
        Log.d(TAG, "Setting community slug: $slug")
        getPrefs(context).edit().putString(KEY_COMMUNITY_SLUG, slug).apply()
    }

    fun getCommunitySlug(context: Context): String? {
        return getPrefs(context).getString(KEY_COMMUNITY_SLUG, null)
    }

    fun logout(context: Context) {
        Log.d(TAG, "Logging out user")
        getPrefs(context).edit().clear().apply()
    }

    suspend fun getStreamChatToken(context: Context): String? {
        // First check if we have a stored Stream Chat token
        val storedToken = getPrefs(context).getString(KEY_STREAM_TOKEN, null)
        if (storedToken != null) {
            Log.d(TAG, "Using cached Stream Chat token")
            return storedToken
        }

        // Fetch from backend if not stored
        Log.d(TAG, "Fetching Stream Chat token from backend")
        return fetchStreamTokenFromBackend(context)
    }

    private suspend fun fetchStreamTokenFromBackend(context: Context): String? {
        return try {
            val url = java.net.URL("${com.colecoding.conduit.config.AppConfig.getBaseUrl(context)}/api/v1/stream_token")
            val connection = url.openConnection() as java.net.HttpURLConnection

            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("User-Agent", "Conduit-Android/1.0")

            // Try auth token first
            val authToken = getAuthToken(context)
            if (authToken != null) {
                connection.setRequestProperty("Authorization", "Bearer $authToken")
                Log.d(TAG, "Using auth token for authentication")
            } else {
                // Fall back to session cookie
                val sessionCookie = getSessionCookie(context)
                if (sessionCookie != null) {
                    connection.setRequestProperty("Cookie", "_conduit_app_session=$sessionCookie")
                    Log.d(TAG, "Using session cookie for authentication")
                } else {
                    Log.e(TAG, "No authentication credentials available for Stream token request")
                    return null
                }
            }

            connection.connectTimeout = 5000
            connection.readTimeout = 5000

            val responseCode = connection.responseCode
            Log.d(TAG, "Stream token API response code: $responseCode")

            if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "Stream token response received")

                // Parse JSON response
                val jsonObject = org.json.JSONObject(response)
                val token = jsonObject.getString("token")

                // Store the token for future use
                setStreamChatToken(context, token)

                // Store community slug for channel filtering
                if (jsonObject.has("community_slug")) {
                    setCommunitySlug(context, jsonObject.getString("community_slug"))
                    Log.d(TAG, "Community slug: ${jsonObject.getString("community_slug")}")
                }

                // Also update user data if present
                if (jsonObject.has("user")) {
                    val userObject = jsonObject.getJSONObject("user")
                    if (userObject.has("id")) {
                        setUserId(context, userObject.getString("id"))
                    }
                    if (userObject.has("name")) {
                        setUserName(context, userObject.getString("name"))
                    }
                    if (userObject.has("restricted_access")) {
                        setRestrictedAccess(context, userObject.getBoolean("restricted_access"))
                        Log.d(TAG, "User restricted access: ${userObject.getBoolean("restricted_access")}")
                    }
                }

                Log.d(TAG, "Stream token successfully fetched and stored")
                token
            } else {
                Log.e(TAG, "Failed to fetch Stream token. Response code: $responseCode")

                // Try to read error response
                try {
                    val errorResponse = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Log.e(TAG, "Error response: $errorResponse")
                } catch (e: Exception) {
                    Log.e(TAG, "Could not read error response", e)
                }

                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching Stream token from backend", e)
            null
        }
    }
}