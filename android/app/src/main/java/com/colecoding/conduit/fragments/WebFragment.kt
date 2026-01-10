package com.colecoding.conduit.fragments

import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import androidx.appcompat.widget.Toolbar
import dev.hotwire.core.turbo.errors.VisitError
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

/**
 * Main web fragment that uses Hotwire Native for Turbo Drive navigation.
 */
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
open class WebFragment : HotwireWebFragment() {

    companion object {
        private const val TAG = "WebFragment"
    }

    // Hide the toolbar since we use bottom navigation
    override fun toolbarForNavigation(): Toolbar? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "WebFragment onViewCreated")

        // Hide the toolbar view if it exists
        view.findViewById<Toolbar>(dev.hotwire.navigation.R.id.toolbar)?.visibility = View.GONE

        // Configure cookies
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
    }

    override fun onColdBootPageCompleted(location: String) {
        super.onColdBootPageCompleted(location)
        Log.d(TAG, "Cold boot completed: $location")

        // Flush cookies after navigation
        CookieManager.getInstance().flush()
    }

    override fun onVisitErrorReceived(location: String, error: VisitError) {
        super.onVisitErrorReceived(location, error)
        Log.e(TAG, "Visit error at $location: $error")
    }
}
