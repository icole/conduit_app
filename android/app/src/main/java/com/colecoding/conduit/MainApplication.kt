package com.colecoding.conduit

import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.logger.ChatLogLevel
import io.getstream.chat.android.offline.plugin.factory.StreamOfflinePluginFactory
import io.getstream.chat.android.state.plugin.config.StatePluginConfig
import io.getstream.chat.android.state.plugin.factory.StreamStatePluginFactory

class MainApplication : Application() {

    companion object {
        private const val TAG = "MainApplication"
        lateinit var instance: MainApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Initialize Firebase
        FirebaseApp.initializeApp(this)
        Log.d(TAG, "Firebase initialized")

        // Fetch FCM token and store it for later registration with Stream
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
                Log.d(TAG, "FCM Token received: ${token.take(20)}...")
                // Store token for later registration when Stream connects
                getSharedPreferences("push_prefs", MODE_PRIVATE)
                    .edit()
                    .putString("pending_fcm_token", token)
                    .apply()
                Log.d(TAG, "FCM Token stored as pending")
            } else {
                Log.e(TAG, "Failed to get FCM token", task.exception)
            }
        }

        // Initialize Stream Chat (but don't connect yet - will connect after login)
        initializeStreamChat()
    }

    private fun initializeStreamChat() {
        try {
            val apiKey = BuildConfig.STREAM_API_KEY
            Log.d(TAG, "Initializing Stream Chat with API key: ${apiKey.take(10)}...")

            // Create offline plugin for better UX
            val offlinePlugin = StreamOfflinePluginFactory(this)

            // Create state plugin
            val statePlugin = StreamStatePluginFactory(
                config = StatePluginConfig(),
                appContext = this
            )

            // Initialize ChatClient
            val client = ChatClient.Builder(apiKey, this)
                .withPlugins(offlinePlugin, statePlugin)
                .logLevel(if (BuildConfig.DEBUG) ChatLogLevel.ALL else ChatLogLevel.NOTHING)
                .build()

            Log.d(TAG, "Stream Chat initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Stream Chat", e)
        }
    }
}