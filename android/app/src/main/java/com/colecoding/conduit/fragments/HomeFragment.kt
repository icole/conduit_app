package com.colecoding.conduit.fragments

import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import androidx.browser.customtabs.CustomTabsIntent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebResourceRequest
import android.widget.FrameLayout
import android.widget.ProgressBar
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.config.AppConfig
import android.webkit.CookieManager
import android.util.Log

class HomeFragment : Fragment() {

    companion object {
        private const val TAG = "HomeFragment"
    }

    private lateinit var webView: WebView
    private lateinit var swipeRefresh: SwipeRefreshLayout
    private lateinit var loadingIndicator: ProgressBar
    private lateinit var rootContainer: FrameLayout

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Create a FrameLayout as root to hold SwipeRefresh and loading indicator
        rootContainer = FrameLayout(requireContext()).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Set background color to match theme
            setBackgroundColor(ContextCompat.getColor(requireContext(), android.R.color.background_light))
        }

        // Create SwipeRefreshLayout
        swipeRefresh = SwipeRefreshLayout(requireContext()).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        webView = WebView(requireContext()).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            // Set background to match app theme while loading
            setBackgroundColor(ContextCompat.getColor(requireContext(), android.R.color.background_light))

            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                userAgentString = "$userAgentString Conduit-Android/1.0 (Turbo Native)"

                // Allow mixed content for local development
                mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

                // Allow file access
                allowFileAccess = true
                allowContentAccess = true
            }

            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val url = request?.url?.toString() ?: return false
                    Log.d(TAG, "shouldOverrideUrlLoading: $url")

                    // Check if this is an internal URL (our app)
                    val baseUrl = AppConfig.getBaseUrl(requireContext())
                    val isInternalUrl = url.startsWith(baseUrl) ||
                            url.contains("localhost") ||
                            url.contains("10.0.2.2") ||
                            url.contains("conduit")

                    return if (isInternalUrl) {
                        // Let WebView handle internal URLs
                        false
                    } else {
                        // Open external URLs in Chrome Custom Tab (in-app browser)
                        Log.d(TAG, "Opening external URL in Custom Tab: $url")
                        try {
                            val customTabsIntent = CustomTabsIntent.Builder()
                                .setShowTitle(true)
                                .build()
                            customTabsIntent.launchUrl(requireContext(), Uri.parse(url))
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to open Custom Tab: ${e.message}")
                        }
                        true
                    }
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "Page loaded: $url")
                    swipeRefresh.isRefreshing = false

                    // Hide loading indicator
                    loadingIndicator.visibility = View.GONE

                    // Flush cookies after each page load to ensure they persist
                    CookieManager.getInstance().flush()

                    // Log current cookies for debugging
                    val baseUrl = AppConfig.getBaseUrl(requireContext())
                    val cookies = CookieManager.getInstance().getCookie(baseUrl)
                    Log.d(TAG, "Current cookies for $baseUrl: $cookies")

                    // Check if we just finished auth_login
                    if (url?.contains("auth_login") == true) {
                        Log.d(TAG, "Auth login page loaded, session should be established")
                    }
                }
            }
        }

        // Add WebView to SwipeRefreshLayout
        swipeRefresh.addView(webView)

        // Create loading indicator
        loadingIndicator = ProgressBar(requireContext()).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
            isIndeterminate = true
        }

        // Add views to root container
        rootContainer.addView(swipeRefresh)
        rootContainer.addView(loadingIndicator)

        // Setup pull to refresh
        swipeRefresh.setOnRefreshListener {
            Log.d(TAG, "Pull to refresh triggered")
            webView.reload()
        }

        // Setup cookies after WebView is created
        setupCookies()

        // First establish session, then load home
        establishSessionAndLoad()

        return rootContainer
    }

    private fun setupCookies() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(webView, true)

        // Don't clear cookies - we want to maintain the session!
        // Only clear on logout

        // Flush to ensure cookies are saved
        cookieManager.flush()

        Log.d(TAG, "Cookie manager configured, maintaining existing session")
    }

    private fun createSessionFromAuthToken() {
        // If we don't have a session cookie but have an auth token,
        // we need to create a session on Rails
        val authToken = AuthManager.getAuthToken(requireContext())
        if (authToken.isNullOrEmpty()) {
            Log.e(TAG, "No auth token available either - authentication failed")
            return
        }

        // The WebView will use the auth token via JavaScript to create a session
        // This will be handled after the page loads
        Log.d(TAG, "Will create session using auth token after page loads")
    }

    private fun establishSessionAndLoad() {
        val authToken = AuthManager.getAuthToken(requireContext())

        if (authToken.isNullOrEmpty()) {
            Log.e(TAG, "No auth token available - loading without session")
            loadHome()
            return
        }

        // Check if we've already established session (check for session cookie)
        val cookieManager = CookieManager.getInstance()
        val baseUrl = AppConfig.getBaseUrl(requireContext())
        val cookies = cookieManager.getCookie(baseUrl)

        if (cookies != null && cookies.contains("_conduit_app_session")) {
            Log.d(TAG, "Session cookie exists, loading home directly")
            loadHome()
            return
        }

        // No session cookie, establish session with auth token
        Log.d(TAG, "No session cookie found, establishing session with auth token")

        // Setup cookies
        setupCookies()

        // Load the auth_login URL with the token to establish session
        val authUrl = "$baseUrl/auth_login?token=${authToken}"

        Log.d(TAG, "Loading auth URL to establish session")
        webView.loadUrl(authUrl)
    }


    private fun loadHome() {
        val baseUrl = AppConfig.getBaseUrl(requireContext())
        Log.d(TAG, "Loading home from: $baseUrl")
        webView.loadUrl(baseUrl)
    }
}