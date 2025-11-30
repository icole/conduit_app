package com.colecoding.conduit.services

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.colecoding.conduit.auth.AuthManager
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.models.Device
import io.getstream.chat.android.models.PushProvider

class PushNotificationService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "PushNotificationService"

        fun registerPendingToken(context: android.content.Context) {
            val prefs = context.getSharedPreferences("push_prefs", MODE_PRIVATE)
            val pendingToken = prefs.getString("pending_fcm_token", null)

            pendingToken?.let { token ->
                Log.d(TAG, "Found pending FCM token, registering with Stream")
                PushNotificationService().registerTokenWithStream(token)
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token received")

        // Register token with Stream Chat if user is logged in
        if (AuthManager.isAuthenticated(this)) {
            registerTokenWithStream(token)
        } else {
            // Store token for later registration
            getSharedPreferences("push_prefs", MODE_PRIVATE)
                .edit()
                .putString("pending_fcm_token", token)
                .apply()
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        Log.d(TAG, "Received FCM message from: ${message.from}")

        // Check if this is a Stream Chat notification by looking for Stream-specific data
        if (message.data.containsKey("stream")) {
            Log.d(TAG, "Stream Chat notification received")
            // Stream Chat SDK will handle this internally when the client is connected
            try {
                // Ensure ChatClient is initialized
                ChatClient.instance()
                Log.d(TAG, "Stream Chat client is active, notification will be handled")
            } catch (e: Exception) {
                Log.e(TAG, "ChatClient not initialized: ${e.message}")
            }
            return
        }

        // Handle other notifications here if needed
        Log.d(TAG, "Non-Stream notification, processing normally")
        handleCustomNotification(message)
    }

    private fun registerTokenWithStream(token: String) {
        try {
            val client = ChatClient.instance()

            // Check if client is initialized and connected
            if (client.getCurrentUser() != null) {
                Log.d(TAG, "Registering FCM token with Stream Chat")

                // Create device with Firebase push provider
                val device = Device(
                    token = token,
                    pushProvider = PushProvider.FIREBASE,
                    providerName = "firebase"
                )

                client.addDevice(device).enqueue { result ->
                    if (result.isSuccess) {
                        Log.d(TAG, "Successfully registered FCM token with Stream")

                        // Clear pending token
                        getSharedPreferences("push_prefs", MODE_PRIVATE)
                            .edit()
                            .remove("pending_fcm_token")
                            .apply()
                    } else {
                        Log.e(TAG, "Failed to register FCM token: ${result.errorOrNull()}")
                    }
                }
            } else {
                Log.d(TAG, "Stream Chat not connected, storing token for later")
                // Store token for later registration
                getSharedPreferences("push_prefs", MODE_PRIVATE)
                    .edit()
                    .putString("pending_fcm_token", token)
                    .apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error registering token with Stream", e)
        }
    }

    private fun handleCustomNotification(message: RemoteMessage) {
        // Handle any custom notifications here
        message.notification?.let {
            Log.d(TAG, "Notification Title: ${it.title}")
            Log.d(TAG, "Notification Body: ${it.body}")
        }

        message.data.isNotEmpty().let {
            Log.d(TAG, "Message data payload: ${message.data}")
        }
    }

}