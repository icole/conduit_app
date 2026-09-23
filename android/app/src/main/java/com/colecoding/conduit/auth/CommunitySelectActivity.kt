package com.colecoding.conduit.auth

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.inputmethod.EditorInfo
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.addTextChangedListener
import androidx.lifecycle.lifecycleScope
import com.colecoding.conduit.R
import com.colecoding.conduit.config.AppConfig
import com.colecoding.conduit.config.CommunityLookup
import com.colecoding.conduit.config.CommunityManager
import com.colecoding.conduit.databinding.ActivityCommunitySelectBinding
import com.colecoding.conduit.models.Community
import com.colecoding.conduit.ui.padForSystemBars
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Asks for the community by name and looks up that one community, rather than
 * listing every community on the server.
 */
class CommunitySelectActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCommunitySelectBinding
    private var foundCommunity: Community? = null

    companion object {
        private const val TAG = "CommunitySelectActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityCommunitySelectBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.root.padForSystemBars()

        binding.findButton.setOnClickListener { lookupCommunity() }
        binding.communityInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                lookupCommunity()
                true
            } else {
                false
            }
        }

        // Typing again invalidates the previous result
        binding.communityInput.addTextChangedListener(
            afterTextChanged = { clearResult() }
        )

        binding.signupButton.setOnClickListener { openSignupForm() }
        binding.continueButton.setOnClickListener { continueToLogin() }
    }

    private fun lookupCommunity() {
        val baseUrl = AppConfig.getBaseUrl(this)
        val url = CommunityLookup.lookupUrl(baseUrl, binding.communityInput.text?.toString().orEmpty())
        if (url == null) {
            showError(getString(R.string.community_input_hint))
            return
        }

        clearResult()
        showLoading(true)

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 10_000
                    readTimeout = 10_000
                }

                val code = connection.responseCode
                val body = if (code == HttpURLConnection.HTTP_OK) {
                    connection.inputStream.bufferedReader().use { it.readText() }
                } else {
                    null
                }

                withContext(Dispatchers.Main) {
                    showLoading(false)
                    when {
                        body != null -> showFound(Community.fromJson(JSONObject(body)))
                        code == HttpURLConnection.HTTP_NOT_FOUND -> showError(getString(R.string.community_not_found))
                        else -> showError(getString(R.string.error_network))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Community lookup failed", e)
                withContext(Dispatchers.Main) {
                    showLoading(false)
                    showError(getString(R.string.error_network))
                }
            }
        }
    }

    private fun showFound(community: Community) {
        foundCommunity = community
        binding.foundText.text = if (community.isPending) {
            "${community.name}\n${getString(R.string.community_pending_note)}"
        } else {
            community.name
        }
        binding.foundText.visibility = View.VISIBLE
        binding.continueButton.isEnabled = true
    }

    private fun continueToLogin() {
        val community = foundCommunity ?: return

        // Debug builds talk to the local server; release builds use the community's domain
        val url = if (AppConfig.isDebugBuild()) AppConfig.getBaseUrl(this) else "https://${community.domain}"

        CommunityManager.setCommunityUrl(this, url)
        CommunityManager.setCommunityName(this, community.name)

        Log.d(TAG, "Selected community: ${community.name} at $url")

        startActivity(Intent(this, LoginActivity::class.java))
        finish()
    }

    private fun openSignupForm() {
        val url = CommunityLookup.signupUrl(AppConfig.getBaseUrl(this))
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    private fun clearResult() {
        foundCommunity = null
        binding.continueButton.isEnabled = false
        binding.foundText.visibility = View.GONE
        binding.errorText.visibility = View.GONE
    }

    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show) View.VISIBLE else View.GONE
        binding.findButton.isEnabled = !show
    }

    private fun showError(message: String) {
        binding.errorText.text = message
        binding.errorText.visibility = View.VISIBLE
    }
}
