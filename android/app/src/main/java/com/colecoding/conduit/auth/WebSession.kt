package com.colecoding.conduit.auth

import android.content.Context
import android.util.Log
import android.webkit.CookieManager
import com.colecoding.conduit.config.AppConfig
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Signs the web views in without putting the app's 30-day API token in a URL
 * (CON-54): trade it for a code that lasts a minute and works once, redeem the
 * code here, and hand the session cookie to the web views.
 */
object WebSession {
    private const val TAG = "WebSession"
    private const val COOKIE = "_conduit_app_session"

    enum class Result { SIGNED_IN, REJECTED, OFFLINE }

    fun needsSignIn(cookies: String?): Boolean =
        cookies?.split(";")?.none { it.trim().startsWith("$COOKIE=") } ?: true

    fun needsSignIn(context: Context): Boolean =
        needsSignIn(CookieManager.getInstance().getCookie(AppConfig.getBaseUrl(context)))

    fun sessionCookie(setCookieHeaders: List<String>): String? =
        setCookieHeaders.firstOrNull { it.startsWith("$COOKIE=") }

    fun redeemUrl(baseUrl: String, code: String): String =
        "${baseUrl.trimEnd('/')}/auth_login?token=${URLEncoder.encode(code, "UTF-8")}"

    /** Blocks on the network, so call it off the main thread. */
    fun establish(context: Context): Result {
        return try {
            val code = exchangeCode(context) ?: return Result.REJECTED
            val cookie = redeem(context, code) ?: return Result.REJECTED
            val cookies = CookieManager.getInstance()
            cookies.setCookie(AppConfig.getBaseUrl(context), cookie)
            cookies.flush()
            Log.d(TAG, "Web views signed in")
            Result.SIGNED_IN
        } catch (e: IOException) {
            Log.e(TAG, "Couldn't reach the server to sign the web views in", e)
            Result.OFFLINE
        }
    }

    /** The one-time code, or null if the API token is no good (even refreshed). */
    private fun exchangeCode(context: Context, isRetry: Boolean = false): String? {
        val token = AuthManager.getAuthToken(context) ?: return null
        val connection = URL("${AppConfig.getBaseUrl(context).trimEnd('/')}/api/v1/session_exchange")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            return when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> {
                    val body = connection.inputStream.bufferedReader().use { it.readText() }
                    JSONObject(body).getString("token")
                }
                HttpURLConnection.HTTP_UNAUTHORIZED -> {
                    if (isRetry) return null
                    runBlocking { AuthManager.refreshAuthToken(context) } ?: return null
                    exchangeCode(context, isRetry = true)
                }
                else -> {
                    Log.e(TAG, "Session exchange failed: ${connection.responseCode}")
                    if (connection.responseCode >= 500) throw IOException("Server error ${connection.responseCode}")
                    null
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    /** The session cookie auth_login sets for the code, or null if it was turned down. */
    private fun redeem(context: Context, code: String): String? {
        val connection = URL(redeemUrl(AppConfig.getBaseUrl(context), code)).openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects = false // a redirect means the code was turned down
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                Log.e(TAG, "Code redemption failed: ${connection.responseCode}")
                return null
            }
            val setCookies = connection.headerFields
                .filterKeys { it.equals("Set-Cookie", ignoreCase = true) }
                .values.flatten()
            return sessionCookie(setCookies)
        } finally {
            connection.disconnect()
        }
    }
}
