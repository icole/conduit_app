package com.colecoding.conduit.services

import android.content.Context
import android.util.Log
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.config.AppConfig
import com.google.firebase.messaging.FirebaseMessaging
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONObject
import java.io.IOException

/**
 * Tells the Conduit server which phone to send its own push notifications to
 * (task reminders). Stream gets the same FCM token separately, for chat.
 * Registered while signed in (every launch, and when the token changes) and
 * removed at sign-out.
 */
object PushDeviceRegistrar {
    private const val TAG = "PushDeviceRegistrar"
    private val client = OkHttpClient()
    private val json = "application/json".toMediaType()

    /** Sends [token], or the phone's current FCM token, for whoever is signed in. */
    fun register(context: Context, token: String? = null) {
        val authToken = AuthManager.getAuthToken(context) ?: return
        val baseUrl = AppConfig.getBaseUrl(context)
        withToken(token) { fcmToken ->
            val body = JSONObject(mapOf("token" to fcmToken, "platform" to "google", "name" to "Android"))
            send("POST", baseUrl, authToken, body)
        }
    }

    /** Call before the sign-in token is cleared. */
    fun unregister(context: Context) {
        val authToken = AuthManager.getAuthToken(context) ?: return
        val baseUrl = AppConfig.getBaseUrl(context)
        withToken(null) { fcmToken -> send("DELETE", baseUrl, authToken, JSONObject(mapOf("token" to fcmToken))) }
    }

    private fun withToken(token: String?, use: (String) -> Unit) {
        if (token != null) return use(token)
        try {
            FirebaseMessaging.getInstance().token.addOnSuccessListener { use(it) }
        } catch (e: IllegalStateException) {
            Log.w(TAG, "Firebase isn't set up; no push token", e)
        }
    }

    private fun send(method: String, baseUrl: String, authToken: String, body: JSONObject) {
        val request = Request.Builder()
            .url("${baseUrl.trimEnd('/')}/api/v1/push_devices")
            .header("Authorization", "Bearer $authToken")
            .method(method, body.toString().toRequestBody(json))
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.w(TAG, "Push device $method failed", e)
            }

            override fun onResponse(call: Call, response: Response) {
                Log.d(TAG, "Push device $method: ${response.code}")
                response.close()
            }
        })
    }
}
