package com.colecoding.conduit.fragments

import android.app.AlertDialog
import android.os.Bundle
import android.util.Log
import android.view.*
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.colecoding.conduit.chat.ChatUnavailable
import androidx.core.view.MenuProvider
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.ApiReply
import com.colecoding.conduit.auth.AuthManager
import com.google.android.material.floatingactionbutton.FloatingActionButton
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.extensions.currentUserUnreadCount
import io.getstream.chat.android.models.*
import io.getstream.chat.android.ui.feature.channels.list.ChannelListView
import io.getstream.chat.android.ui.feature.channels.list.adapter.ChannelListItem
import io.getstream.chat.android.state.extensions.globalState
import com.colecoding.conduit.chat.ChannelMutes
import com.colecoding.conduit.chat.PendingChatChannel
import com.colecoding.conduit.chat.TrackingMessageListActivity
import io.getstream.chat.android.ui.feature.search.SearchInputView
import io.getstream.chat.android.ui.feature.search.list.SearchResultListView
import io.getstream.chat.android.ui.viewmodel.search.SearchViewModel
import io.getstream.chat.android.ui.viewmodel.search.bindView as bindSearchView
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModel
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModelFactory
import io.getstream.chat.android.ui.viewmodel.channels.bindView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import com.colecoding.conduit.ui.Palette

class CustomChatFragment : Fragment() {

    companion object {
        private const val TAG = "CustomChatFragment"
    }

    private lateinit var channelListView: ChannelListView
    private lateinit var viewModel: ChannelListViewModel
    private var fabCreateChannel: FloatingActionButton? = null

    /** Connected and showing the list, so a requested channel can be opened. */
    private var isChannelListReady = false

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
                val reply = withContext(Dispatchers.IO) {
                    AuthManager.getStreamChatToken(requireContext())
                }
                if (reply == ApiReply.Unauthorized) {
                    activity?.let { AuthManager.signInAgain(it) }
                    return@launch
                }
                if (reply !is ApiReply.Ok) {
                    showUnavailable(ChatUnavailable.message((reply as? ApiReply.Refused)?.reason))
                    return@launch
                }
                val token = reply.value

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

                        client.connectUser(user, AuthManager.streamTokenProvider(requireContext(), token)).enqueue { result ->
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

    /** Why chat can't load (CON-76), in place of the spinner */
    private fun showUnavailable(message: String) {
        val view = view ?: return
        view.findViewById<ProgressBar>(R.id.progress_bar)?.visibility = View.GONE
        val container = view.findViewById<FrameLayout>(R.id.chat_container) ?: return
        container.removeAllViews()
        val padding = (24 * resources.displayMetrics.density).toInt()
        container.addView(TextView(requireContext()).apply {
            text = message
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
        }, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
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


        // Search every chat the user is in. While there's a query the results
        // replace the channel list; clearing it brings the list back.
        val searchInput = SearchInputView(requireContext())
        val searchResults = SearchResultListView(requireContext()).apply {
            visibility = View.GONE
        }
        val listArea = FrameLayout(requireContext()).apply {
            addView(channelListView)
            addView(searchResults, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
        }
        val margin = (8 * resources.displayMetrics.density).toInt()
        // A screen title like Account's, since the Chat tab has no toolbar
        val title = android.widget.TextView(requireContext()).apply {
            text = "Chat"
            textSize = 28f
            setTextColor(Palette.ink)
            setPadding(margin * 2 + margin / 2, margin * 3, margin * 2, margin / 2)
        }
        val column = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Palette.paper)
            addView(title)
            addView(searchInput, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(margin, margin, margin, margin) })
            addView(listArea, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        }

        container.removeAllViews()
        container.addView(column)

        val searchViewModel = ViewModelProvider(this)[SearchViewModel::class.java]
        searchViewModel.bindSearchView(searchResults, viewLifecycleOwner)
        searchInput.setDebouncedInputChangedListener { query ->
            if (query.isBlank()) {
                searchResults.visibility = View.GONE
                channelListView.visibility = View.VISIBLE
            } else {
                searchViewModel.setQuery(query)
                searchResults.visibility = View.VISIBLE
                channelListView.visibility = View.GONE
            }
        }
        searchInput.setSearchStartedListener { query ->
            searchViewModel.setQuery(query)
            searchResults.visibility = View.VISIBLE
            channelListView.visibility = View.GONE
        }
        searchResults.setLoadMoreListener { searchViewModel.loadMore() }
        searchResults.setSearchResultSelectedListener { message ->
            // Open the chat scrolled to the message that matched
            startActivity(TrackingMessageListActivity.createIntent(requireContext(), message.cid, message.id))
        }

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

        // A notification may have asked for a channel while we connected
        isChannelListReady = true
        openPendingChannel()
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
            attemptCreateChannel(name)
        }
    }

    private suspend fun attemptCreateChannel(name: String, isRetry: Boolean = false): String? {
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
                return channelId
            } else if (responseCode == 401 && !isRetry) {
                // Check if it's a token_expired error
                val errorResponse = connection.errorStream?.bufferedReader()?.readText()
                connection.disconnect()

                if (errorResponse != null) {
                    try {
                        val errorJson = org.json.JSONObject(errorResponse)
                        if (errorJson.optString("error") == "token_expired") {
                            Log.d(TAG, "Token expired, attempting refresh...")
                            val newToken = AuthManager.refreshAuthToken(requireContext())
                            if (newToken != null) {
                                Log.d(TAG, "Token refreshed, retrying channel creation")
                                return attemptCreateChannel(name, isRetry = true)
                            } else {
                                Log.e(TAG, "Token refresh failed, redirecting to login")
                                withContext(Dispatchers.Main) {
                                    redirectToLogin()
                                }
                                return null
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing error response", e)
                    }
                }

                Log.e(TAG, "Authentication failed, redirecting to login")
                withContext(Dispatchers.Main) {
                    redirectToLogin()
                }
                return null
            } else {
                val errorResponse = connection.errorStream?.bufferedReader()?.readText()
                Log.e(TAG, "Failed to create channel via server, status: $responseCode, error: $errorResponse")
                connection.disconnect()
                return null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating channel via server", e)
            return null
        }
    }

    private fun redirectToLogin() {
        activity?.let { AuthManager.signInAgain(it) }
    }

    private fun showChannelOptionsDialog(channel: Channel) {
        val options = mutableListOf<String>()
        val actions = mutableListOf<() -> Unit>()

        // Mute/Unmute option: muting is per person, so it's read from their own mutes
        val currentUser = ChatClient.instance().getCurrentUser()
        val userId = currentUser?.id
        val isMuted = isMutedForMe(channel)
        options.add(if (isMuted) "Unmute Channel" else "Mute Channel")
        actions.add { toggleMuteChannel(channel, isMuted) }

        // Mark as read
        val unreadCount = channel.currentUserUnreadCount()
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

    private fun isMutedForMe(channel: Channel): Boolean =
        ChannelMutes.isMuted(channel.cid, ChatClient.instance().globalState.channelMutes.value)

    /**
     * Mutes or unmutes the channel for this person only. It used to also rename
     * the channel ("🔇 General") and post "Channel unmuted", which everyone in
     * the community saw (CON-79); iOS never did.
     */
    private fun toggleMuteChannel(channel: Channel, isMuted: Boolean) {
        val channelClient = ChatClient.instance().channel(channel.cid)

        if (isMuted) {
            channelClient.unmute().enqueue { result ->
                showToast(if (result.isSuccess) "Channel unmuted 🔔" else "Failed to unmute channel")
            }
        } else {
            channelClient.mute().enqueue { result ->
                showToast(if (result.isSuccess) "Channel muted 🔇" else "Failed to mute channel")
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
     * Open the channel a tapped notification asked for (PendingChatChannel),
     * if the chat is connected. Called once the list is set up, and by
     * MainActivity when a notification is tapped while Chat is already loaded.
     */
    fun openPendingChannel() {
        if (!isChannelListReady || !isAdded || ChatClient.instance().getCurrentUser() == null) return
        val channelCid = PendingChatChannel.take() ?: return

        Log.d(TAG, "Opening channel from notification: $channelCid")
        startActivity(TrackingMessageListActivity.createIntent(requireContext(), channelCid))
    }

}