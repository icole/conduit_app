package com.colecoding.conduit.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.colecoding.conduit.MainActivity
import com.colecoding.conduit.auth.AuthManager

class ProfileFragment : Fragment() {

    companion object {
        private const val TAG = "ProfileFragment"
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Create a simple profile layout
        val layout = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
        }

        val titleText = TextView(requireContext()).apply {
            text = "Profile"
            textSize = 24f
            setPadding(0, 16, 0, 16)
        }

        // Get user info
        val userName = AuthManager.getUserName(requireContext()) ?: "User"
        val userEmail = AuthManager.getUserEmail(requireContext()) ?: ""

        val nameText = TextView(requireContext()).apply {
            text = "Name: $userName"
            textSize = 18f
            setPadding(0, 8, 0, 8)
        }

        val emailText = TextView(requireContext()).apply {
            text = "Email: $userEmail"
            textSize = 18f
            setPadding(0, 8, 0, 32)
        }

        val logoutButton = Button(requireContext()).apply {
            text = "Logout"
            setOnClickListener {
                Log.d(TAG, "Logout button clicked")
                (activity as? MainActivity)?.logout()
            }
        }

        layout.addView(titleText)
        layout.addView(nameText)
        layout.addView(emailText)
        layout.addView(logoutButton)

        return layout
    }
}