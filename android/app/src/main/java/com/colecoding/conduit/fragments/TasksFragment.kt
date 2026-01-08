package com.colecoding.conduit.fragments

import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabsIntent
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import androidx.fragment.app.Fragment
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.config.AppConfig

class TasksFragment : Fragment() {

    companion object {
        private const val TAG = "TasksFragment"
        private const val TASKS_PATH = "/tasks"
    }

    private lateinit var webView: WebView
    private lateinit var swipeRefresh: SwipeRefreshLayout

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        Log.d(TAG, "onCreateView")
        return inflater.inflate(R.layout.fragment_webview, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "onViewCreated")

        webView = view.findViewById(R.id.webview)
        swipeRefresh = view.findViewById(R.id.swipe_refresh)

        setupWebView()
        setupSwipeRefresh()
        // Don't load immediately - wait until fragment becomes visible
        // This ensures the session cookie is established by HomeFragment first
    }

    private fun setupSwipeRefresh() {
        swipeRefresh.setOnRefreshListener {
            Log.d(TAG, "Pull to refresh triggered")
            webView.reload()
        }
    }

    private fun setupWebView() {
        Log.d(TAG, "Setting up WebView")

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            cacheMode = WebSettings.LOAD_NO_CACHE
            userAgentString = "$userAgentString Conduit-Android/1.0 (Turbo Native)"
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Log.d(TAG, "Page loaded: $url")
                swipeRefresh.isRefreshing = false

                // Inject auth token
                val token = AuthManager.getAuthToken(requireContext())
                if (token != null) {
                    val script = """
                        (function() {
                            // Store token for API calls
                            window.localStorage.setItem('authToken', '$token');

                            // Set up auth header for fetch requests
                            const originalFetch = window.fetch;
                            window.fetch = function(...args) {
                                if (args[1] && !args[1].headers) {
                                    args[1].headers = {};
                                }
                                if (args[1] && args[1].headers) {
                                    args[1].headers['Authorization'] = 'Bearer $token';
                                }
                                return originalFetch.apply(this, args);
                            };

                            // Hide navigation elements
                            setTimeout(() => {
                                const navbar = document.querySelector('.navbar');
                                if (navbar) navbar.style.display = 'none';

                                const bottomNav = document.querySelector('.bottom-navigation');
                                if (bottomNav) bottomNav.style.display = 'none';
                            }, 100);
                        })();
                    """.trimIndent()

                    view?.evaluateJavascript(script, null)
                }
            }

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

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                Log.e(TAG, "WebView error: ${error?.description}")
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                Log.d(TAG, "Console: ${consoleMessage?.message()}")
                return super.onConsoleMessage(consoleMessage)
            }
        }

        // Handle cookies
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(webView, true)
    }

    private fun loadTasksPage() {
        val baseUrl = com.colecoding.conduit.config.AppConfig.getBaseUrl(requireContext())

        // Check if session cookie exists
        val cookieManager = CookieManager.getInstance()
        val cookies = cookieManager.getCookie(baseUrl)

        if (cookies != null && cookies.contains("_conduit_app_session")) {
            // Session exists, load directly
            val url = "$baseUrl$TASKS_PATH"
            Log.d(TAG, "Session cookie exists, loading URL: $url")
            webView.loadUrl(url)
        } else {
            // No session cookie, establish session first
            val authToken = AuthManager.getAuthToken(requireContext())
            if (authToken != null) {
                Log.d(TAG, "No session cookie, establishing session first")
                val authUrl = "$baseUrl/auth_login?token=$authToken&redirect_to=$TASKS_PATH"
                webView.loadUrl(authUrl)
            } else {
                // No auth token, just try loading (will redirect to login)
                val url = "$baseUrl$TASKS_PATH"
                Log.d(TAG, "No auth token, loading URL: $url")
                webView.loadUrl(url)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume - resuming WebView")
        webView.onResume()
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause - pausing WebView")
        webView.onPause()
    }

    override fun onHiddenChanged(hidden: Boolean) {
        super.onHiddenChanged(hidden)
        Log.d(TAG, "onHiddenChanged - hidden: $hidden")
        if (!hidden) {
            // Fragment is now visible
            webView.onResume()
            // Load if the WebView hasn't loaded yet
            if (webView.url == null || webView.url == "about:blank") {
                Log.d(TAG, "WebView not loaded yet, loading now")
                loadTasksPage()
            }
        } else {
            // Fragment is hidden
            webView.onPause()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        webView.destroy()
    }
}