package com.colecoding.conduit

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.auth.LoginActivity
import com.colecoding.conduit.fragments.CustomChatFragment
import com.colecoding.conduit.fragments.HomeFragment
import com.colecoding.conduit.fragments.TasksFragment
import com.colecoding.conduit.fragments.MealsFragment
import com.google.android.material.bottomnavigation.BottomNavigationView

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private lateinit var bottomNavigation: BottomNavigationView

    // Keep fragment instances to avoid recreation
    private val homeFragment = HomeFragment()
    private val tasksFragment = TasksFragment()
    private val mealsFragment = MealsFragment()
    private val chatFragment = CustomChatFragment()
    private var activeFragment: Fragment = homeFragment

    // Permission request launcher for notifications
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            Log.d(TAG, "Notification permission granted")
        } else {
            Log.d(TAG, "Notification permission denied")
        }
    }

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
                add(R.id.fragment_container, chatFragment, "chat").hide(chatFragment)
                add(R.id.fragment_container, mealsFragment, "meals").hide(mealsFragment)
                add(R.id.fragment_container, tasksFragment, "tasks").hide(tasksFragment)
                add(R.id.fragment_container, homeFragment, "home")
                commit()
            }
        }

        // Request notification permission for Android 13+
        requestNotificationPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when {
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED -> {
                    Log.d(TAG, "Notification permission already granted")
                }
                else -> {
                    Log.d(TAG, "Requesting notification permission")
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        }
    }

    private fun setupBottomNavigation() {
        bottomNavigation.setOnItemSelectedListener { item ->
            val fragment: Fragment = when (item.itemId) {
                R.id.navigation_home -> homeFragment
                R.id.navigation_tasks -> tasksFragment
                R.id.navigation_meals -> mealsFragment
                R.id.navigation_chat -> chatFragment
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