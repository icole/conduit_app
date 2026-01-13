package com.colecoding.conduit.fragments

import android.app.AlertDialog
import android.os.Bundle
import android.util.Log
import android.view.*
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ProgressBar
import androidx.core.view.MenuProvider
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import com.google.android.material.floatingactionbutton.FloatingActionButton
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.extensions.currentUserUnreadCount
import io.getstream.chat.android.models.*
import io.getstream.chat.android.ui.feature.channels.list.ChannelListView
import io.getstream.chat.android.ui.feature.channels.list.adapter.ChannelListItem
import com.colecoding.conduit.chat.TrackingMessageListActivity
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModel
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModelFactory
import io.getstream.chat.android.ui.viewmodel.channels.bindView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class CustomChatFragment : Fragment() {

    companion object {
        private const val TAG = "CustomChatFragment"
    }

    private lateinit var channelListView: ChannelListView
    private lateinit var viewModel: ChannelListViewModel
    private var fabCreateChannel: FloatingActionButton? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_custom_chat, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Setup FAB for channel creation
        fabCreateChannel = view.findViewById(R.id.fab_create_channel)
        fabCreateChannel?.setOnClickListener {
            showCreateChannelDialog()
        }

        // Initialize Stream Chat when fragment is created
        initializeStreamChat()
    }

    private fun initializeStreamChat() {
        lifecycleScope.launch {
            try {
                // Fetch token on IO dispatcher
                val token = withContext(Dispatchers.IO) {
                    AuthManager.getStreamChatToken(requireContext())
                }

                val userId = AuthManager.getUserId(requireContext())
                val userName = AuthManager.getUserName(requireContext())

                if (token != null && userId != null) {
                    val client = ChatClient.instance()

                    // Check if already connected
                    if (client.getCurrentUser() == null) {
                        Log.d(TAG, "Connecting to Stream Chat with user ID: $userId")

                        val user = User(
                            id = userId,
                            name = userName ?: "User"
                        )

                        client.connectUser(user, token).enqueue { result ->
                            if (result.isSuccess) {
                                Log.d(TAG, "Successfully connected to Stream Chat")
                                // Register FCM token for push notifications
                                com.colecoding.conduit.services.PushNotificationService.registerPendingToken(requireContext())
                                // Setup the Stream Chat UI
                                setupChannelListUI()
                            } else {
                                Log.e(TAG, "Failed to connect: ${result.errorOrNull()}")
                            }
                        }
                    } else {
                        Log.d(TAG, "Stream Chat already connected")
                        // Register FCM token for push notifications (in case it wasn't registered before)
                        com.colecoding.conduit.services.PushNotificationService.registerPendingToken(requireContext())
                        // Setup the Stream Chat UI
                        setupChannelListUI()
                    }
                } else {
                    Log.e(TAG, "Missing Stream Chat credentials")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing Stream Chat", e)
            }
        }
    }

    private fun setupChannelListUI() {
        val view = view ?: return
        val container = view.findViewById<FrameLayout>(R.id.chat_container)
        val progressBar = view.findViewById<ProgressBar>(R.id.progress_bar)

        // Hide progress bar
        progressBar?.visibility = View.GONE

        // Create and add the channel list view directly
        channelListView = ChannelListView(requireContext())
        channelListView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )

        // Note: Visual muted indicators will be shown through channel naming
        // The Stream SDK will automatically show channels with updated names

        container.removeAllViews()
        container.addView(channelListView)

        // Setup the channel list - filter by membership
        // This is more reliable than filtering by community_slug extraData
        // since all community members are added to channels
        val userId = AuthManager.getUserId(requireContext()) ?: return
        Log.d(TAG, "Filtering channels where user is a member")
        val filter = Filters.and(
            Filters.eq("type", "team"),
            Filters.`in`("members", listOf(userId))
        )

        val viewModelFactory = ChannelListViewModelFactory(
            filter = filter,
            sort = ChannelListViewModel.DEFAULT_SORT,
            limit = 30
        )

        viewModel = viewModelFactory.create(ChannelListViewModel::class.java)

        // Bind ViewModel to View
        viewModel.bindView(channelListView, viewLifecycleOwner)

        // Setup channel interactions
        setupChannelInteractions()

        // Show FAB for channel creation
        fabCreateChannel?.visibility = View.VISIBLE
    }

    private fun setupChannelInteractions() {
        // Handle channel clicks
        channelListView.setChannelItemClickListener { channel ->
            Log.d(TAG, "Channel clicked: ${channel.cid}")

            // Auto-join channel if not a member
            val currentUserId = ChatClient.instance().getCurrentUser()?.id
            val isMember = channel.members.any { it.user.id == currentUserId }

            if (!isMember && currentUserId != null) {
                Log.d(TAG, "User not a member, auto-joining channel...")
                val channelClient = ChatClient.instance().channel(channel.cid)

                // Add user as member with member role for send message permissions
                channelClient.addMembers(
                    memberIds = listOf(currentUserId),
                    systemMessage = Message(text = "joined the channel")
                ).enqueue { result ->
                    if (result.isSuccess) {
                        Log.d(TAG, "Successfully joined channel")

                        // Watch the channel to ensure we have all permissions and state
                        channelClient.watch().enqueue { watchResult ->
                            if (watchResult.isSuccess) {
                                Log.d(TAG, "Now watching channel for notifications")

                                // Open the message list after watching is confirmed
                                val intent = TrackingMessageListActivity.createIntent(
                                    context = requireContext(),
                                    cid = channel.cid
                                )
                                startActivity(intent)
                            } else {
                                Log.e(TAG, "Failed to watch channel: ${watchResult.errorOrNull()}")
                                // Still try to open even if watch fails
                                val intent = TrackingMessageListActivity.createIntent(
                                    context = requireContext(),
                                    cid = channel.cid
                                )
                                startActivity(intent)
                            }
                        }
                    } else {
                        Log.e(TAG, "Failed to join channel: ${result.errorOrNull()}")
                        // Still try to open the channel
                        val intent = TrackingMessageListActivity.createIntent(
                            context = requireContext(),
                            cid = channel.cid
                        )
                        startActivity(intent)
                    }
                }
            } else {
                // Already a member or couldn't get user ID, just open
                val intent = TrackingMessageListActivity.createIntent(
                    context = requireContext(),
                    cid = channel.cid
                )
                startActivity(intent)
            }
        }

        // Handle long clicks for channel options
        channelListView.setChannelLongClickListener { channel ->
            showChannelOptionsDialog(channel)
            true
        }

        // Handle swipe actions
        channelListView.setMoreOptionsClickListener { channel ->
            showChannelOptionsDialog(channel)
        }
    }

    private fun showCreateChannelDialog() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_create_channel, null)
        val etChannelName = dialogView.findViewById<EditText>(R.id.et_channel_name)
        val etChannelDescription = dialogView.findViewById<EditText>(R.id.et_channel_description)

        AlertDialog.Builder(requireContext())
            .setTitle("Create New Channel")
            .setView(dialogView)
            .setPositiveButton("Create") { _, _ ->
                val name = etChannelName.text.toString().trim()
                val description = etChannelDescription.text.toString().trim()

                if (name.isNotEmpty()) {
                    createChannel(name, description)
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun createChannel(name: String, description: String) {
        lifecycleScope.launch {
            try {
                // Use server endpoint to create channel with all community members
                val channelId = createChannelViaServer(name)

                if (channelId != null) {
                    Log.d(TAG, "Channel created successfully via server: $channelId")

                    // Watch the channel on the client
                    val client = ChatClient.instance()
                    val channelClient = client.channel(channelType = "team", channelId = channelId)

                    channelClient.watch().enqueue { result ->
                        if (result.isSuccess) {
                            Log.d(TAG, "Now watching new channel")
                            // Channel list will auto-refresh via Stream SDK
                            showToast("Channel created: $name")
                        } else {
                            Log.e(TAG, "Failed to watch channel: ${result.errorOrNull()}")
                            showToast("Channel created: $name")
                        }
                    }
                } else {
                    showToast("Failed to create channel")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error creating channel", e)
                showToast("Error creating channel")
            }
        }
    }

    private suspend fun createChannelViaServer(name: String): String? {
        return withContext(Dispatchers.IO) {
            try {
                val baseUrl = com.colecoding.conduit.config.AppConfig.getBaseUrl(requireContext())
                val url = java.net.URL("$baseUrl/chat/channels")
                val connection = url.openConnection() as java.net.HttpURLConnection

                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")

                // Use JWT auth token (preferred for mobile API)
                val authToken = AuthManager.getAuthToken(requireContext())
                if (authToken != null) {
                    connection.setRequestProperty("Authorization", "Bearer $authToken")
                    Log.d(TAG, "Using auth token for channel creation")
                } else {
                    // Fall back to session cookie
                    val sessionCookie = AuthManager.getSessionCookie(requireContext())
                    if (sessionCookie != null) {
                        connection.setRequestProperty("Cookie", sessionCookie)
                        Log.d(TAG, "Using session cookie for channel creation")
                    }
                }

                connection.doOutput = true

                // Create request body
                val requestBody = org.json.JSONObject().apply {
                    put("name", name)
                }
                connection.outputStream.write(requestBody.toString().toByteArray())

                val responseCode = connection.responseCode
                if (responseCode == 200) {
                    val response = connection.inputStream.bufferedReader().readText()
                    val jsonResponse = org.json.JSONObject(response)
                    val channelId = jsonResponse.getString("channel_id")
                    Log.d(TAG, "Server created channel with ID: $channelId")
                    connection.disconnect()
                    channelId
                } else {
                    val errorResponse = connection.errorStream?.bufferedReader()?.readText()
                    Log.e(TAG, "Failed to create channel via server, status: $responseCode, error: $errorResponse")
                    connection.disconnect()
                    null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error creating channel via server", e)
                null
            }
        }
    }

    private fun showChannelOptionsDialog(channel: Channel) {
        val options = mutableListOf<String>()
        val actions = mutableListOf<() -> Unit>()

        // Mute/Unmute option
        val currentUser = ChatClient.instance().getCurrentUser()
        val userId = currentUser?.id
        val currentMember = channel.members.find { it.user.id == userId }
        // Check if channel is muted - use the channel name prefix as indicator
        val isMuted = channel.name.startsWith("🔇") || currentMember?.banned == true
        options.add(if (isMuted) "Unmute Channel" else "Mute Channel")
        actions.add { toggleMuteChannel(channel) }

        // Mark as read
        val unreadCount = channel.currentUserUnreadCount
        if (unreadCount > 0) {
            options.add("Mark as Read")
            actions.add { markChannelAsRead(channel) }
        }

        // Channel info
        options.add("Channel Info")
        actions.add { showChannelInfo(channel) }

        // Leave channel
        options.add("Leave Channel")
        actions.add { confirmLeaveChannel(channel) }

        // Delete channel (if admin/owner)
        val membership = channel.members.find { it.user.id == userId }
        val memberRole = membership?.channelRole
        if (memberRole == "owner" || memberRole == "admin" || memberRole == "channel_moderator") {
            options.add("Delete Channel")
            actions.add { confirmDeleteChannel(channel) }
        }

        AlertDialog.Builder(requireContext())
            .setTitle(channel.name)
            .setItems(options.toTypedArray()) { _, which ->
                actions[which].invoke()
            }
            .show()
    }

    private fun toggleMuteChannel(channel: Channel) {
        val client = ChatClient.instance()
        val channelClient = client.channel(channel.cid)
        // Check if channel is muted - use the channel name prefix as indicator
        val isMuted = channel.name.startsWith("🔇")

        if (isMuted) {
            // Unmute the channel - remove the mute emoji from name
            val cleanName = channel.name.removePrefix("🔇 ").removePrefix("🔇")
            channelClient.update(message = Message(text = "Channel unmuted")).enqueue { updateResult ->
                if (updateResult.isSuccess) {
                    // Actually unmute the channel
                    channelClient.unmute().enqueue { result ->
                        if (result.isSuccess) {
                            // Update channel name to remove mute indicator
                            val extraData = mapOf("name" to cleanName)
                            channelClient.updatePartial(set = extraData).enqueue()
                            showToast("Channel unmuted 🔔")
                        } else {
                            showToast("Failed to unmute channel")
                        }
                    }
                }
            }
        } else {
            // Mute the channel - add the mute emoji to name
            channelClient.mute().enqueue { result ->
                if (result.isSuccess) {
                    // Update channel name to add mute indicator
                    val mutedName = "🔇 ${channel.name}"
                    val extraData = mapOf("name" to mutedName)
                    channelClient.updatePartial(set = extraData).enqueue()
                    showToast("Channel muted 🔇")
                } else {
                    showToast("Failed to mute channel")
                }
            }
        }
    }

    private fun markChannelAsRead(channel: Channel) {
        val client = ChatClient.instance()
        val channelClient = client.channel(channel.cid)

        channelClient.markRead().enqueue { result ->
            if (result.isSuccess) {
                showToast("Marked as read")
            }
        }
    }

    private fun showChannelInfo(channel: Channel) {
        val info = """
            Channel: ${channel.name}
            Type: ${channel.type}
            Members: ${channel.memberCount}
            Created: ${channel.createdAt}
        """.trimIndent()

        AlertDialog.Builder(requireContext())
            .setTitle("Channel Information")
            .setMessage(info)
            .setPositiveButton("OK", null)
            .show()
    }

    private fun confirmLeaveChannel(channel: Channel) {
        AlertDialog.Builder(requireContext())
            .setTitle("Leave Channel?")
            .setMessage("Are you sure you want to leave '${channel.name}'?")
            .setPositiveButton("Leave") { _, _ ->
                leaveChannel(channel)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun leaveChannel(channel: Channel) {
        val client = ChatClient.instance()
        val userId = client.getCurrentUser()?.id ?: return
        val channelClient = client.channel(channel.cid)

        channelClient.removeMembers(listOf(userId)).enqueue { result ->
            if (result.isSuccess) {
                showToast("Left channel")
            } else {
                showToast("Failed to leave channel")
            }
        }
    }

    private fun confirmDeleteChannel(channel: Channel) {
        AlertDialog.Builder(requireContext())
            .setTitle("Delete Channel?")
            .setMessage("Are you sure you want to delete '${channel.name}'? This action cannot be undone.")
            .setPositiveButton("Delete") { _, _ ->
                deleteChannel(channel)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun deleteChannel(channel: Channel) {
        val client = ChatClient.instance()
        val channelClient = client.channel(channel.cid)

        channelClient.delete().enqueue { result ->
            if (result.isSuccess) {
                showToast("Channel deleted")
            } else {
                showToast("Failed to delete channel")
            }
        }
    }

    private fun showToast(message: String) {
        activity?.runOnUiThread {
            android.widget.Toast.makeText(requireContext(), message, android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    /**
     * Open a specific channel by CID (called from notification tap)
     */
    fun openChannel(channelCid: String) {
        Log.d(TAG, "Opening channel from notification: $channelCid")

        // Check if the chat client is connected
        val client = ChatClient.instance()
        if (client.getCurrentUser() == null) {
            Log.w(TAG, "Chat client not connected yet, waiting...")
            // If not connected, retry after a delay
            view?.postDelayed({
                openChannel(channelCid)
            }, 500)
            return
        }

        // Open the channel in TrackingMessageListActivity
        val intent = TrackingMessageListActivity.createIntent(
            context = requireContext(),
            cid = channelCid
        )
        startActivity(intent)
    }

}