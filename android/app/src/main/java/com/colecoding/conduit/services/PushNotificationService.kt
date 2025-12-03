package com.colecoding.conduit.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.R
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.models.Device
import io.getstream.chat.android.models.PushProvider

class PushNotificationService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "PushNotificationService"
        private const val CHANNEL_ID = "chat_messages"

        fun registerPendingToken(context: android.content.Context) {
            val prefs = context.getSharedPreferences("push_prefs", MODE_PRIVATE)
            val pendingToken = prefs.getString("pending_fcm_token", null)

            Log.d(TAG, "registerPendingToken called, pendingToken exists: ${pendingToken != null}")

            pendingToken?.let { token ->
                Log.d(TAG, "Found pending FCM token, registering with Stream: ${token.take(20)}...")
                try {
                    val client = ChatClient.instance()
                    val currentUser = client.getCurrentUser()
                    Log.d(TAG, "ChatClient current user: ${currentUser?.id}")

                    if (currentUser != null) {
                        val device = Device(
                            token = token,
                            pushProvider = PushProvider.FIREBASE,
                            providerName = "Conduit-Android-Chat"
                        )
                        client.addDevice(device).enqueue { result ->
                            if (result.isSuccess) {
                                Log.d(TAG, "Successfully registered FCM token with Stream")
                                prefs.edit().remove("pending_fcm_token").apply()
                            } else {
                                Log.e(TAG, "Failed to register FCM token: ${result.errorOrNull()}")
                            }
                        }
                    } else {
                        Log.e(TAG, "Cannot register token - no current user")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error registering token with Stream", e)
                }
            } ?: Log.d(TAG, "No pending FCM token found")
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
        Log.d(TAG, "Message data payload: ${message.data}")

        // Check if this is a Stream Chat notification
        val sender = message.data["sender"]
        val messageType = message.data["type"]

        if (sender == "stream.chat" || messageType == "message.new") {
            Log.d(TAG, "Stream Chat notification received")
            showStreamNotification(message.data)
            return
        }

        // Handle other notifications here if needed
        Log.d(TAG, "Non-Stream notification, processing normally")
        handleCustomNotification(message)
    }

    private fun showStreamNotification(data: Map<String, String>) {
        val title = data["title"] ?: "New Message"
        val body = data["body"] ?: ""
        val channelId = data["channel_id"] ?: ""
        val channelType = data["channel_type"] ?: "messaging"

        Log.d(TAG, "Showing notification: title=$title, body=$body")

        // Create notification channel for Android O+
        createNotificationChannel()

        // Create intent to open app when notification is tapped
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("channel_cid", "$channelType:$channelId")
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build notification
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        // Show notification
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)

        Log.d(TAG, "Notification displayed")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Chat Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new chat messages"
            }

            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
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
                    providerName = "Conduit-Android-Chat"
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