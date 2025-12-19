package com.colecoding.conduit.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import androidx.fragment.app.Fragment
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager

class TasksFragment : Fragment() {

    companion object {
        private const val TAG = "TasksFragment"
        private const val TASKS_PATH = "/tasks"
    }

    private lateinit var webView: WebView

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
        setupWebView()
        loadTasksPage()
    }

    private fun setupWebView() {
        Log.d(TAG, "Setting up WebView")

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            cacheMode = WebSettings.LOAD_NO_CACHE
            userAgentString = "$userAgentString ConduitAndroid/1.0"
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Log.d(TAG, "Page loaded: $url")

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

                                // Add padding to top of content
                                const main = document.querySelector('main');
                                if (main) main.style.paddingTop = '20px';
                            }, 100);
                        })();
                    """.trimIndent()

                    view?.evaluateJavascript(script, null)
                }
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString()
                Log.d(TAG, "shouldOverrideUrlLoading: $url")

                // Keep navigation within the app for conduit URLs
                if (url?.contains("conduit") == true || url?.contains("localhost") == true) {
                    return false
                }

                return true
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

        val url = "$baseUrl$TASKS_PATH"
        Log.d(TAG, "Loading URL: $url")

        val token = AuthManager.getAuthToken(requireContext())
        if (token != null) {
            val headers = HashMap<String, String>()
            headers["Authorization"] = "Bearer $token"
            webView.loadUrl(url, headers)
        } else {
            webView.loadUrl(url)
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
            // Reload if the WebView is blank
            if (webView.url == null || webView.url == "about:blank") {
                Log.d(TAG, "WebView URL is blank, reloading")
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