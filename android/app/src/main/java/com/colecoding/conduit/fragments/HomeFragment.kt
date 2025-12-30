package com.colecoding.conduit.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.fragment.app.Fragment
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.config.AppConfig
import android.webkit.CookieManager
import android.util.Log

class HomeFragment : Fragment() {

    companion object {
        private const val TAG = "HomeFragment"
    }

    private lateinit var webView: WebView

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        webView = WebView(requireContext()).apply {
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
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    // Let the WebView handle all URLs in the home tab
                    return false
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "Page loaded: $url")

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

        // Setup cookies after WebView is created
        setupCookies()

        // First establish session, then load home
        establishSessionAndLoad()

        return webView
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