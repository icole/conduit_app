package com.colecoding.conduit.auth

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.colecoding.conduit.R
import com.colecoding.conduit.config.CommunityManager
import com.colecoding.conduit.databinding.ActivityCommunitySelectBinding
import com.colecoding.conduit.models.Community
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

class CommunitySelectActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCommunitySelectBinding
    private var communities: List<Community> = emptyList()
    private var selectedCommunity: Community? = null
    private lateinit var adapter: CommunityAdapter

    companion object {
        private const val TAG = "CommunitySelectActivity"
        private const val COMMUNITIES_API_URL = "https://api.conduitcoho.app/api/v1/communities"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityCommunitySelectBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupRecyclerView()
        setupContinueButton()
        fetchCommunities()
    }

    private fun setupRecyclerView() {
        adapter = CommunityAdapter(
            communities = communities,
            selectedCommunity = selectedCommunity,
            onCommunitySelected = { community ->
                selectedCommunity = community
                adapter.setSelectedCommunity(community)
                binding.continueButton.isEnabled = true
            }
        )
        binding.communitiesList.layoutManager = LinearLayoutManager(this)
        binding.communitiesList.adapter = adapter
    }

    private fun setupContinueButton() {
        binding.continueButton.setOnClickListener {
            selectedCommunity?.let { community ->
                // Build the full URL with https://
                val url = "https://${community.domain}"

                // Save the selected community
                CommunityManager.setCommunityUrl(this, url)
                CommunityManager.setCommunityName(this, community.name)

                Log.d(TAG, "Selected community: ${community.name} at $url")

                // Navigate to login
                startActivity(Intent(this, LoginActivity::class.java))
                finish()
            }
        }
    }

    private fun fetchCommunities() {
        showLoading(true)
        hideError()

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val url = URL(COMMUNITIES_API_URL)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Accept", "application/json")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                val responseCode = connection.responseCode
                Log.d(TAG, "Communities API response code: $responseCode")

                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val jsonArray = JSONArray(response)
                    val fetchedCommunities = Community.listFromJson(jsonArray)

                    withContext(Dispatchers.Main) {
                        showLoading(false)
                        communities = fetchedCommunities
                        adapter.updateCommunities(communities)

                        if (communities.isEmpty()) {
                            showError("No communities available")
                        }
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        showLoading(false)
                        showError("Failed to load communities (Error $responseCode)")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching communities", e)
                withContext(Dispatchers.Main) {
                    showLoading(false)
                    showError("Failed to load communities: ${e.localizedMessage}")
                }
            }
        }
    }

    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show) View.VISIBLE else View.GONE
        binding.communitiesList.visibility = if (show) View.GONE else View.VISIBLE
    }

    private fun showError(message: String) {
        binding.errorText.text = message
        binding.errorText.visibility = View.VISIBLE
    }

    private fun hideError() {
        binding.errorText.visibility = View.GONE
    }

    // RecyclerView Adapter
    private class CommunityAdapter(
        private var communities: List<Community>,
        private var selectedCommunity: Community?,
        private val onCommunitySelected: (Community) -> Unit
    ) : RecyclerView.Adapter<CommunityAdapter.ViewHolder>() {

        class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val nameText: TextView = view.findViewById(android.R.id.text1)
            val domainText: TextView = view.findViewById(android.R.id.text2)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(android.R.layout.simple_list_item_2, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val community = communities[position]
            holder.nameText.text = community.name
            holder.domainText.text = community.domain

            // Show selection state
            val isSelected = selectedCommunity?.id == community.id
            holder.itemView.isActivated = isSelected

            // Update background based on selection
            if (isSelected) {
                holder.itemView.setBackgroundResource(android.R.color.holo_blue_light)
            } else {
                holder.itemView.setBackgroundResource(android.R.color.transparent)
            }

            holder.itemView.setOnClickListener {
                onCommunitySelected(community)
            }
        }

        override fun getItemCount() = communities.size

        fun updateCommunities(newCommunities: List<Community>) {
            communities = newCommunities
            notifyDataSetChanged()
        }

        fun setSelectedCommunity(community: Community) {
            selectedCommunity = community
            notifyDataSetChanged()
        }
    }
}
