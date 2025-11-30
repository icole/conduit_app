package com.colecoding.conduit.chat

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.config.AppConfig
import com.colecoding.conduit.databinding.FragmentStreamChatBinding
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.models.Filters
import io.getstream.chat.android.models.User
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModel
import io.getstream.chat.android.ui.viewmodel.channels.ChannelListViewModelFactory
import io.getstream.chat.android.ui.viewmodel.channels.bindView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class StreamChatFragment : Fragment() {

    companion object {
        private const val TAG = "StreamChatFragment"

        fun newInstance(): StreamChatFragment {
            return StreamChatFragment()
        }
    }

    private var _binding: FragmentStreamChatBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentStreamChatBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Show loading indicator
        binding.progressBar.visibility = View.VISIBLE
        binding.channelListView.visibility = View.GONE

        // Initialize Stream Chat
        initializeStreamChat()
    }

    private fun initializeStreamChat() {
        lifecycleScope.launch {
            try {
                // Fetch Stream token from backend
                val tokenData = fetchStreamToken()
                if (tokenData != null) {
                    connectToStreamChat(tokenData)
                } else {
                    showError("Failed to get chat token")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Stream Chat", e)
                showError("Failed to connect to chat")
            }
        }
    }

    private suspend fun fetchStreamToken(): StreamTokenData? = withContext(Dispatchers.IO) {
        try {
            val url = URL("${AppConfig.getBaseUrl(requireContext())}/chat/token.json")
            val connection = url.openConnection() as HttpURLConnection

            connection.apply {
                requestMethod = "GET"
                setRequestProperty("Accept", "application/json")

                // Add session cookie if available
                AuthManager.getSessionCookie(requireContext())?.let { cookie ->
                    setRequestProperty("Cookie", "_conduit_app_session=$cookie")
                }
            }

            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = BufferedReader(InputStreamReader(connection.inputStream))
                    .use { it.readText() }

                val json = JSONObject(response)
                return@withContext StreamTokenData(
                    token = json.getString("token"),
                    apiKey = json.getString("api_key"),
                    userId = json.getJSONObject("user").getString("id"),
                    userName = json.getJSONObject("user").getString("name"),
                    userAvatar = json.getJSONObject("user").optString("avatar")
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching Stream token", e)
        }
        return@withContext null
    }

    private fun connectToStreamChat(tokenData: StreamTokenData) {
        Log.d(TAG, "Connecting to Stream Chat for user: ${tokenData.userId}")

        // Initialize ChatClient
        val client = ChatClient.instance()

        // Create user
        val user = User(
            id = tokenData.userId,
            name = tokenData.userName,
            image = tokenData.userAvatar ?: ""
        )

        // Connect user
        client.connectUser(
            user = user,
            token = tokenData.token
        ).enqueue { result ->
            if (result.isSuccess) {
                Log.d(TAG, "Successfully connected to Stream Chat")
                requireActivity().runOnUiThread {
                    setupChannelList()
                }
            } else {
                Log.e(TAG, "Failed to connect to Stream Chat: ${result.errorOrNull()}")
                requireActivity().runOnUiThread {
                    showError("Failed to connect to chat")
                }
            }
        }
    }

    private fun setupChannelList() {
        // Hide loading, show channel list
        binding.progressBar.visibility = View.GONE
        binding.channelListView.visibility = View.VISIBLE

        // Create channel filter - show channels where user is a member
        val filter = Filters.and(
            Filters.eq("type", "team"),
            Filters.`in`("members", listOf(AuthManager.getUserId(requireContext()) ?: ""))
        )

        // Create ViewModel
        val viewModelFactory = ChannelListViewModelFactory(
            filter = filter,
            sort = ChannelListViewModel.DEFAULT_SORT,
            limit = 30
        )

        val viewModel = viewModelFactory.create(ChannelListViewModel::class.java)

        // Bind ViewModel to View
        viewModel.bindView(binding.channelListView, viewLifecycleOwner)

        // Handle channel clicks
        binding.channelListView.setChannelItemClickListener { channel ->
            // Navigate to channel messages
            val parts = channel.cid.split(":")
            if (parts.size == 2) {
                startActivity(StreamChatActivity.createIntent(requireContext(), parts[0], parts[1]))
            }
        }
    }

    private fun showError(message: String) {
        binding.progressBar.visibility = View.GONE
        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}

data class StreamTokenData(
    val token: String,
    val apiKey: String,
    val userId: String,
    val userName: String,
    val userAvatar: String?
)