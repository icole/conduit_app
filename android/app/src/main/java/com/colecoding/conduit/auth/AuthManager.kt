package com.colecoding.conduit.auth

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.Toast
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.webkit.WebView
import org.json.JSONObject

object AuthManager {
    private const val PREF_NAME = "ConduitAuthPrefs"
    private const val KEY_USER_ID = "user_id"
    private const val KEY_USER_NAME = "user_name"
    private const val KEY_USER_EMAIL = "user_email"
    private const val KEY_SESSION_COOKIE = "session_cookie"
    private const val KEY_IS_AUTHENTICATED = "is_authenticated"
    // Older versions kept a chat token that never expired here; cleared on next fetch
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

    /**
     * Attempt to refresh an expired auth token using the server's refresh endpoint.
     * Returns the new token on success, null if refresh fails (token too old or invalid).
     */
    suspend fun refreshAuthToken(context: Context): String? {
        val expiredToken = getAuthToken(context) ?: return null

        return withContext(Dispatchers.IO) {
            try {
                val baseUrl = com.colecoding.conduit.config.AppConfig.getBaseUrl(context)
                val url = java.net.URL("$baseUrl/api/v1/auth/refresh")
                val connection = url.openConnection() as java.net.HttpURLConnection

                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $expiredToken")
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val responseCode = connection.responseCode
                Log.d(TAG, "Token refresh response code: $responseCode")

                if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonObject = org.json.JSONObject(response)
                    val newToken = jsonObject.getString("auth_token")

                    // Store the new token
                    setAuthToken(context, newToken)

                    // Update user data if present
                    if (jsonObject.has("user")) {
                        val userObject = jsonObject.getJSONObject("user")
                        if (userObject.has("id")) {
                            setUserId(context, userObject.getInt("id").toString())
                        }
                        if (userObject.has("name")) {
                            setUserName(context, userObject.getString("name"))
                        }
                    }

                    Log.d(TAG, "Token refreshed successfully")
                    connection.disconnect()
                    newToken
                } else {
                    val errorResponse = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Log.e(TAG, "Token refresh failed: $responseCode - $errorResponse")
                    connection.disconnect()
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error refreshing token", e)
                null
            }
        }
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
        Log.d(TAG, "Logging out user - clearing all data")

        // Stop the server's push notifications to this phone, while still signed in
        com.colecoding.conduit.services.PushDeviceRegistrar.unregister(context)

        // Clear SharedPreferences
        getPrefs(context).edit().clear().apply()

        // Clear all WebView cookies
        val cookieManager = CookieManager.getInstance()
        cookieManager.removeAllCookies { success ->
            Log.d(TAG, "Cookies cleared: $success")
        }
        cookieManager.flush()

        // Clear WebView storage (localStorage, sessionStorage, databases)
        WebStorage.getInstance().deleteAllData()

        // Clear WebView cache
        try {
            // This requires a WebView instance, but we can clear the cache directory
            context.cacheDir.deleteRecursively()
            Log.d(TAG, "Cache directory cleared")
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing cache", e)
        }

        Log.d(TAG, "Logout complete - all data cleared")
    }

    /** A chat token that expires within the hour (CON-80); each call fetches a new one. */
    /** A chat token that expires within the hour (CON-80); each call fetches a new one. */
    suspend fun getStreamChatToken(context: Context): ApiReply<String> =
        withContext(Dispatchers.IO) { fetchStreamToken(context) }

    /** For connectUser: starts with [first], then fetches fresh tokens as Stream needs them. */
    fun streamTokenProvider(context: Context, first: String): StreamTokens {
        val appContext = context.applicationContext
        return StreamTokens(first) { (fetchStreamToken(appContext) as? ApiReply.Ok)?.value }
    }

    /** Signed out by the server: back to the login screen, saying why. */
    fun signInAgain(activity: Activity) {
        logout(activity)
        val intent = Intent(activity, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        activity.startActivity(intent)
        Toast.makeText(activity, "Session expired. Please log in again.", Toast.LENGTH_LONG).show()
    }

    /** Blocks on the network, so call it off the main thread. */
    private fun fetchStreamToken(context: Context): ApiReply<String> {
        getPrefs(context).edit().remove(KEY_STREAM_TOKEN).apply()
        return ApiTokenRetry.call(
            getAuthToken(context),
            refresh = { runBlocking { refreshAuthToken(context) } }
        ) { token -> requestStreamToken(context, token) }
    }

    private fun requestStreamToken(context: Context, authToken: String): ApiReply<String> {
        return try {
            val url = java.net.URL("${com.colecoding.conduit.config.AppConfig.getBaseUrl(context)}/api/v1/stream_token?expiring=1")
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("User-Agent", "Conduit-Android/1.0")
            connection.setRequestProperty("Authorization", "Bearer $authToken")
            connection.connectTimeout = 5000
            connection.readTimeout = 5000

            val responseCode = connection.responseCode
            Log.d(TAG, "Stream token API response code: $responseCode")

            when (responseCode) {
                java.net.HttpURLConnection.HTTP_OK -> {
                    val jsonObject = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                    rememberChatDetails(context, jsonObject)
                    ApiReply.Ok(jsonObject.getString("token"))
                }
                java.net.HttpURLConnection.HTTP_UNAUTHORIZED -> ApiReply.Unauthorized
                else -> {
                    // e.g. 403: chat disabled, community awaiting approval, email unverified
                    val errorResponse = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Log.e(TAG, "Failed to fetch Stream token: $responseCode $errorResponse")
                    ApiReply.Failed
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching Stream token from backend", e)
            ApiReply.Failed
        }
    }

    /** The community slug (for channel filtering) and the member's details that come with a token. */
    private fun rememberChatDetails(context: Context, json: JSONObject) {
        if (json.has("community_slug")) setCommunitySlug(context, json.getString("community_slug"))
        val user = json.optJSONObject("user") ?: return
        if (user.has("id")) setUserId(context, user.getString("id"))
        if (user.has("name")) setUserName(context, user.getString("name"))
        if (user.has("restricted_access")) setRestrictedAccess(context, user.getBoolean("restricted_access"))
    }
}