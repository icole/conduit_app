package com.colecoding.conduit.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.R

class AccountFragment : Fragment() {

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val layout = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Title
        val titleText = TextView(requireContext()).apply {
            text = "Account"
            textSize = 24f
            setPadding(0, 0, 0, 48)
        }
        layout.addView(titleText)

        // Logout button
        val logoutButton = Button(requireContext()).apply {
            text = getString(R.string.logout)
            setOnClickListener { showLogoutConfirmation() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 24
            }
        }
        layout.addView(logoutButton)

        // Switch Community button
        val switchCommunityButton = Button(requireContext()).apply {
            text = getString(R.string.community_switch)
            setOnClickListener { showSwitchCommunityConfirmation() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        layout.addView(switchCommunityButton)

        return layout
    }

    private fun showLogoutConfirmation() {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.logout)
            .setMessage("Are you sure you want to logout?")
            .setPositiveButton(R.string.logout) { _, _ ->
                (activity as? MainActivity)?.logout()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun showSwitchCommunityConfirmation() {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.community_switch)
            .setMessage("This will log you out. Continue?")
            .setPositiveButton(android.R.string.ok) { _, _ ->
                (activity as? MainActivity)?.switchCommunity()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
}
