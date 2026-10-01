package com.colecoding.conduit.fragments

import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import androidx.core.view.WindowInsetsControllerCompat
import com.colecoding.conduit.R
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

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "WebFragment onViewCreated")

        // Configure cookies
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)

        styleChrome()
    }

    // Native chrome in the page's own colours, so it reads as one surface
    private fun styleChrome() {
        val surface = Color.parseColor("#FAF7F5")
        toolbarForNavigation()?.apply {
            setBackgroundColor(surface)
            setTitleTextColor(Color.parseColor("#291334"))
            (parent as? View)?.apply {
                setBackgroundColor(surface)
                elevation = 0f
            }
        }
        // The activity's root shows through behind the status bar
        activity?.findViewById<View>(R.id.root)?.setBackgroundColor(surface)
        activity?.window?.let { window ->
            WindowInsetsControllerCompat(window, window.decorView).isAppearanceLightStatusBars = true
        }
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
