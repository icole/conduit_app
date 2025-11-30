package com.colecoding.conduit.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.models.User
import io.getstream.chat.android.ui.viewmodel.channels.bindView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ChatFragment : Fragment() {

    companion object {
        private const val TAG = "ChatFragment"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_chat, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

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
                                // Add the Stream Chat fragment
                                addStreamChatFragment()
                            } else {
                                Log.e(TAG, "Failed to connect: ${result.errorOrNull()}")
                            }
                        }
                    } else {
                        Log.d(TAG, "Stream Chat already connected")
                        // Add the Stream Chat fragment
                        addStreamChatFragment()
                    }
                } else {
                    Log.e(TAG, "Missing Stream Chat credentials")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing Stream Chat", e)
            }
        }
    }

    private fun addStreamChatFragment() {
        // Since we've already connected to Stream Chat,
        // we can directly show the channel list UI
        lifecycleScope.launch(Dispatchers.Main) {
            setupChannelListUI()
        }
    }

    private fun setupChannelListUI() {
        val view = view ?: return
        val container = view.findViewById<android.widget.FrameLayout>(R.id.chat_container)
        val progressBar = view.findViewById<android.widget.ProgressBar>(R.id.progress_bar)

        // Hide progress bar
        progressBar?.visibility = View.GONE

        // Create and add the channel list view directly
        val channelListView = io.getstream.chat.android.ui.feature.channels.list.ChannelListView(requireContext())
        channelListView.layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT
        )

        container.removeAllViews()
        container.addView(channelListView)

        // Setup the channel list
        val userId = AuthManager.getUserId(requireContext()) ?: return

        val filter = io.getstream.chat.android.models.Filters.and(
            io.getstream.chat.android.models.Filters.eq("type", "team"),
            io.getstream.chat.android.models.Filters.`in`("members", listOf(userId))
        )

        val viewModelFactory = io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModelFactory(
            filter = filter,
            sort = io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModel.DEFAULT_SORT,
            limit = 30
        )

        val viewModel = viewModelFactory.create(io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModel::class.java)

        // Bind ViewModel to View
        viewModel.bindView(channelListView, viewLifecycleOwner)

        // Handle channel clicks
        channelListView.setChannelItemClickListener { channel ->
            Log.d(TAG, "Channel clicked: ${channel.cid}")
            // Open the message list for this channel
            val intent = io.getstream.chat.android.ui.feature.messages.MessageListActivity.createIntent(
                context = requireContext(),
                cid = channel.cid
            )
            startActivity(intent)
        }
    }
}