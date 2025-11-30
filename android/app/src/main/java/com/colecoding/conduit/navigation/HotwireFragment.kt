package com.colecoding.conduit.navigation

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.colecoding.conduit.R
import com.colecoding.conduit.auth.AuthManager
import dev.hotwire.turbo.fragments.TurboWebFragment
import dev.hotwire.turbo.session.TurboSession
import dev.hotwire.turbo.visit.TurboVisitAction
import dev.hotwire.turbo.visit.TurboVisitOptions

class HotwireFragment : TurboWebFragment() {

    companion object {
        private const val TAG = "HotwireFragment"

        fun newInstance(url: String): HotwireFragment {
            return HotwireFragment().apply {
                arguments = Bundle().apply {
                    // TurboWebFragment expects the URL with the key "location"
                    putString("location", url)
                }
            }
        }
    }

    private val currentUrl: String
        get() = arguments?.getString("location") ?: ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? {
        return inflater.inflate(R.layout.fragment_hotwire, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Configure the session with authentication
        configureSession()

        // Load the URL - this will be handled by Turbo automatically
        // The URL is loaded via the sessionName and Turbo's internal routing
    }


    override fun shouldNavigateTo(newLocation: String): Boolean {
        // Handle special navigation cases
        Log.d(TAG, "shouldNavigateTo: $newLocation")

        // Check if this is a chat URL that should open native chat
        if (newLocation.contains("/chat") && !newLocation.contains("token")) {
            // Let the activity handle switching to native chat
            return false
        }

        // Allow navigation for most URLs
        return true
    }

    override fun onVisitErrorReceived(location: String, errorCode: Int) {
        when (errorCode) {
            401 -> {
                // Unauthorized - need to login
                Log.e(TAG, "Unauthorized access to: $location")
                handleAuthenticationError()
            }
            else -> {
                Log.e(TAG, "Visit error for $location: $errorCode")
                super.onVisitErrorReceived(location, errorCode)
            }
        }
    }

    private fun configureSession() {
        // Add session cookie if available
        context?.let { ctx ->
            AuthManager.getSessionCookie(ctx)?.let { cookie ->
                val cookieManager = android.webkit.CookieManager.getInstance()
                cookieManager.setAcceptCookie(true)

                // Set cookie for the domain
                val url = currentUrl
                if (url.isNotEmpty()) {
                    val domain = android.net.Uri.parse(url).host
                    cookieManager.setCookie(domain, "_conduit_app_session=$cookie")
                    Log.d(TAG, "Session cookie set for domain: $domain")
                }
            }
        }

        // Configure WebView settings
        session.webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            userAgentString = "$userAgentString Conduit-Android/1.0 (Turbo Native)"
        }
    }

    private fun handleAuthenticationError() {
        // Clear auth data and return to login
        activity?.let { act ->
            AuthManager.logout(act)
            (act as? com.colecoding.conduit.MainActivity)?.logout()
        }
    }

}