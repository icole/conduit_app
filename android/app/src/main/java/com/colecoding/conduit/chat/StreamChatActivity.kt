package com.colecoding.conduit.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.logger.ChatLogLevel
import io.getstream.chat.android.models.Channel
import io.getstream.chat.android.models.User
import io.getstream.chat.android.ui.feature.channels.ChannelListActivity
import io.getstream.chat.android.ui.feature.messages.MessageListActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class StreamChatActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "StreamChatActivity"
        private const val EXTRA_CHANNEL_ID = "channel_id"
        private const val EXTRA_CHANNEL_TYPE = "channel_type"

        fun createIntent(context: Context, channelType: String, channelId: String): Intent {
            return Intent(context, StreamChatActivity::class.java).apply {
                putExtra(EXTRA_CHANNEL_TYPE, channelType)
                putExtra(EXTRA_CHANNEL_ID, channelId)
            }
        }

        fun createIntent(context: Context, cid: String): Intent {
            // Parse cid format "type:id"
            val parts = cid.split(":")
            return if (parts.size == 2) {
                createIntent(context, parts[0], parts[1])
            } else {
                createIntent(context)
            }
        }

        fun createIntent(context: Context): Intent {
            return Intent(context, StreamChatActivity::class.java)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID)
        val channelType = intent.getStringExtra(EXTRA_CHANNEL_TYPE)

        if (channelId != null && channelType != null) {
            // Open specific channel
            openMessageList(channelType, channelId)
        } else {
            // Open channel list
            openChannelList()
        }
    }

    private fun openChannelList() {
        // Initialize Stream Chat if needed
        initializeStreamChat {
            startActivity(ChannelListActivity.createIntent(this))
            finish()
        }
    }

    private fun openMessageList(channelType: String, channelId: String) {
        // Initialize Stream Chat if needed
        initializeStreamChat {
            startActivity(
                MessageListActivity.createIntent(
                    context = this,
                    cid = "$channelType:$channelId"
                )
            )
            finish()
        }
    }

    private fun initializeStreamChat(onComplete: () -> Unit) {
        val client = ChatClient.instance()

        // Check if already connected
        if (client.getCurrentUser() != null) {
            onComplete()
            return
        }

        // Get Stream Chat token from Rails
        lifecycleScope.launch {
            try {
                // Fetch token on IO dispatcher
                val token = withContext(Dispatchers.IO) {
                    AuthManager.getStreamChatToken(this@StreamChatActivity)
                }

                val userId = AuthManager.getUserId(this@StreamChatActivity)

                if (token != null && userId != null) {
                    Log.d(TAG, "Connecting to Stream Chat with user ID: $userId")
                    Log.d(TAG, "Token length: ${token.length}")

                    val user = User(
                        id = userId,
                        name = AuthManager.getUserName(this@StreamChatActivity) ?: "User"
                    )

                    client.connectUser(user, token).enqueue { result ->
                        if (result.isSuccess) {
                            Log.d(TAG, "Successfully connected to Stream Chat")
                            onComplete()
                        } else {
                            Log.e(TAG, "Failed to connect: ${result.errorOrNull()}")
                            finish()
                        }
                    }
                } else {
                    Log.e(TAG, "No Stream Chat token available - token: ${token != null}, userId: ${userId != null}")
                    finish()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing Stream Chat", e)
                finish()
            }
        }
    }
}