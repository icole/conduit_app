package com.colecoding.conduit

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.auth.LoginActivity
import com.colecoding.conduit.fragments.ChatFragment
import com.colecoding.conduit.fragments.HomeFragment
import com.colecoding.conduit.fragments.ProfileFragment
import com.google.android.material.bottomnavigation.BottomNavigationView

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private lateinit var bottomNavigation: BottomNavigationView

    // Keep fragment instances to avoid recreation
    private val homeFragment = HomeFragment()
    private val chatFragment = ChatFragment()
    private val profileFragment = ProfileFragment()
    private var activeFragment: Fragment = homeFragment

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check authentication
        if (!AuthManager.isAuthenticated(this)) {
            Log.d(TAG, "User not authenticated, redirecting to login")
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        Log.d(TAG, "User authenticated, loading app")

        // Set up the layout
        setContentView(R.layout.activity_main)

        // Set up bottom navigation
        bottomNavigation = findViewById(R.id.bottom_navigation)
        setupBottomNavigation()

        // Add all fragments but hide non-active ones
        if (savedInstanceState == null) {
            supportFragmentManager.beginTransaction().apply {
                add(R.id.fragment_container, profileFragment, "profile").hide(profileFragment)
                add(R.id.fragment_container, chatFragment, "chat").hide(chatFragment)
                add(R.id.fragment_container, homeFragment, "home")
                commit()
            }
        }
    }

    private fun setupBottomNavigation() {
        bottomNavigation.setOnItemSelectedListener { item ->
            val fragment: Fragment = when (item.itemId) {
                R.id.navigation_home -> homeFragment
                R.id.navigation_chat -> chatFragment
                R.id.navigation_profile -> profileFragment
                else -> homeFragment
            }

            // Hide current, show selected
            supportFragmentManager.beginTransaction().apply {
                hide(activeFragment)
                show(fragment)
                commit()
            }
            activeFragment = fragment

            true
        }
    }

    override fun onRestart() {
        super.onRestart()

        // Check authentication on restart
        if (!AuthManager.isAuthenticated(this)) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
        }
    }

    fun logout() {
        AlertDialog.Builder(this)
            .setTitle("Logout")
            .setMessage("Are you sure you want to logout?")
            .setPositiveButton("Logout") { _, _ ->
                Log.d(TAG, "Logging out")
                AuthManager.logout(this)
                startActivity(Intent(this, LoginActivity::class.java))
                finish()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}