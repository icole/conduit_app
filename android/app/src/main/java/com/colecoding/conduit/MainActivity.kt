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
import com.colecoding.conduit.auth.CommunitySelectActivity
import com.colecoding.conduit.auth.LoginActivity
import com.colecoding.conduit.config.CommunityManager
import com.colecoding.conduit.fragments.AccountFragment
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
    private lateinit var homeFragment: HomeFragment
    private lateinit var tasksFragment: TasksFragment
    private lateinit var mealsFragment: MealsFragment
    private lateinit var chatFragment: CustomChatFragment
    private lateinit var accountFragment: AccountFragment
    private lateinit var activeFragment: Fragment

    private companion object {
        const val KEY_ACTIVE_FRAGMENT = "active_fragment_tag"
    }

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

        // Check if community is selected first
        if (!CommunityManager.hasCommunityUrl(this)) {
            Log.d(TAG, "No community selected, redirecting to community selector")
            startActivity(Intent(this, CommunitySelectActivity::class.java))
            finish()
            return
        }

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

        // Initialize or restore fragments
        if (savedInstanceState == null) {
            // First launch - create new fragments
            homeFragment = HomeFragment()
            tasksFragment = TasksFragment()
            mealsFragment = MealsFragment()
            chatFragment = CustomChatFragment()
            accountFragment = AccountFragment()
            activeFragment = homeFragment

            supportFragmentManager.beginTransaction().apply {
                add(R.id.fragment_container, accountFragment, "account").hide(accountFragment)
                add(R.id.fragment_container, chatFragment, "chat").hide(chatFragment)
                add(R.id.fragment_container, mealsFragment, "meals").hide(mealsFragment)
                add(R.id.fragment_container, tasksFragment, "tasks").hide(tasksFragment)
                add(R.id.fragment_container, homeFragment, "home")
                commit()
            }
        } else {
            // Restore fragments from FragmentManager
            homeFragment = supportFragmentManager.findFragmentByTag("home") as? HomeFragment ?: HomeFragment()
            tasksFragment = supportFragmentManager.findFragmentByTag("tasks") as? TasksFragment ?: TasksFragment()
            mealsFragment = supportFragmentManager.findFragmentByTag("meals") as? MealsFragment ?: MealsFragment()
            chatFragment = supportFragmentManager.findFragmentByTag("chat") as? CustomChatFragment ?: CustomChatFragment()
            accountFragment = supportFragmentManager.findFragmentByTag("account") as? AccountFragment ?: AccountFragment()

            // Restore active fragment
            val activeTag = savedInstanceState.getString(KEY_ACTIVE_FRAGMENT, "home")
            activeFragment = supportFragmentManager.findFragmentByTag(activeTag) ?: homeFragment

            // Sync bottom navigation with restored state
            val selectedId = when (activeTag) {
                "home" -> R.id.navigation_home
                "tasks" -> R.id.navigation_tasks
                "meals" -> R.id.navigation_meals
                "chat" -> R.id.navigation_chat
                "account" -> R.id.navigation_account
                else -> R.id.navigation_home
            }
            bottomNavigation.selectedItemId = selectedId
        }

        setupBottomNavigation()

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
                R.id.navigation_account -> accountFragment
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

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        // Save the active fragment tag
        val activeTag = when (activeFragment) {
            homeFragment -> "home"
            tasksFragment -> "tasks"
            mealsFragment -> "meals"
            chatFragment -> "chat"
            accountFragment -> "account"
            else -> "home"
        }
        outState.putString(KEY_ACTIVE_FRAGMENT, activeTag)
    }

    override fun onRestart() {
        super.onRestart()

        // Check community selection on restart
        if (!CommunityManager.hasCommunityUrl(this)) {
            startActivity(Intent(this, CommunitySelectActivity::class.java))
            finish()
            return
        }

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

    fun switchCommunity() {
        AlertDialog.Builder(this)
            .setTitle(R.string.community_switch)
            .setMessage("This will log you out. Continue?")
            .setPositiveButton("Continue") { _, _ ->
                Log.d(TAG, "Switching community")
                AuthManager.logout(this)
                CommunityManager.clearCommunityUrl(this)
                startActivity(Intent(this, CommunitySelectActivity::class.java))
                finish()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}