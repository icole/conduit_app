package com.colecoding.conduit.fragments

import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import androidx.appcompat.widget.Toolbar
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment

/**
 * Modal web fragment for presenting forms and dialogs as bottom sheets.
 */
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web_modal")
class WebModalFragment : HotwireWebBottomSheetFragment() {

    companion object {
        private const val TAG = "WebModalFragment"
    }

    // Hide the toolbar for modals
    override fun toolbarForNavigation(): Toolbar? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        Log.d(TAG, "WebModalFragment onViewCreated")

        // Hide the toolbar view if it exists
        view.findViewById<Toolbar>(dev.hotwire.navigation.R.id.toolbar)?.visibility = View.GONE

        // Configure cookies
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
    }

    override fun onColdBootPageCompleted(location: String) {
        super.onColdBootPageCompleted(location)
        Log.d(TAG, "Modal cold boot completed: $location")
        CookieManager.getInstance().flush()
    }
}
