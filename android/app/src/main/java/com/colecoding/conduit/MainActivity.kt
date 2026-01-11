package com.colecoding.conduit

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.webkit.CookieManager
import android.widget.FrameLayout
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentContainerView
import com.colecoding.conduit.auth.AuthManager
import com.colecoding.conduit.auth.CommunitySelectActivity
import com.colecoding.conduit.auth.LoginActivity
import com.colecoding.conduit.config.AppConfig
import com.colecoding.conduit.config.CommunityManager
import com.colecoding.conduit.fragments.AccountFragment
import com.colecoding.conduit.fragments.CustomChatFragment
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import java.net.URLEncoder

class MainActivity : HotwireActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val KEY_ACTIVE_TAB = "active_tab"
    }

    // Tab identifiers
    private enum class Tab {
        HOME, TASKS, MEALS, CHAT, ACCOUNT
    }

    private lateinit var bottomNavigation: BottomNavigationView

    // NavigatorHost containers for web tabs
    private lateinit var homeNavigatorHost: FragmentContainerView
    private lateinit var tasksNavigatorHost: FragmentContainerView
    private lateinit var mealsNavigatorHost: FragmentContainerView

    // Native fragment containers
    private lateinit var chatContainer: FrameLayout
    private lateinit var accountContainer: FrameLayout

    // Native fragments
    private var chatFragment: CustomChatFragment? = null
    private var accountFragment: AccountFragment? = null

    private var activeTab: Tab = Tab.HOME

    // Store configurations for use in tab switching
    private lateinit var homeConfig: NavigatorConfiguration
    private lateinit var tasksConfig: NavigatorConfiguration
    private lateinit var mealsConfig: NavigatorConfiguration

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

    /**
     * CRITICAL: This must be called before setContentView()
     * Returns navigator configurations with start URLs for web tabs.
     * If no session cookie exists, uses auth_login to establish the session first.
     */
    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        // If no community URL set, return a placeholder config
        // We'll redirect to community select in onCreate(), but HotwireActivityDelegate
        // requires at least one configuration to initialize
        if (!CommunityManager.hasCommunityUrl(this)) {
            Log.d(TAG, "No community URL, returning placeholder navigator config")
            return listOf(
                NavigatorConfiguration(
                    name = "placeholder",
                    startLocation = "about:blank",
                    navigatorHostId = R.id.home_navigator_host
                )
            )
        }

        // Use AppConfig.getBaseUrl() to ensure we use the same server that generated the auth token
        // In debug mode, this returns the local server; in release mode, it returns the production API
        val baseUrl = AppConfig.getBaseUrl(this)

        Log.d(TAG, "Creating navigator configurations with baseUrl: $baseUrl")

        // Check if we have a session cookie
        val cookieManager = CookieManager.getInstance()
        val cookies = cookieManager.getCookie(baseUrl)
        val hasSession = cookies != null && cookies.contains("_conduit_app_session")

        // Get auth token for session establishment
        val authToken = AuthManager.getAuthToken(this)

        // Build URLs - use auth_login to establish session if needed
        val homeUrl = if (!hasSession && authToken != null) {
            val redirectTo = URLEncoder.encode("/", "UTF-8")
            "$baseUrl/auth_login?token=$authToken&redirect_to=$redirectTo"
        } else {
            "$baseUrl/"
        }

        val tasksUrl = if (!hasSession && authToken != null) {
            val redirectTo = URLEncoder.encode("/tasks", "UTF-8")
            "$baseUrl/auth_login?token=$authToken&redirect_to=$redirectTo"
        } else {
            "$baseUrl/tasks"
        }

        val mealsUrl = if (!hasSession && authToken != null) {
            val redirectTo = URLEncoder.encode("/meals", "UTF-8")
            "$baseUrl/auth_login?token=$authToken&redirect_to=$redirectTo"
        } else {
            "$baseUrl/meals"
        }

        // Don't log the full token for security
        val logSafeHomeUrl = if (homeUrl.contains("token=")) {
            homeUrl.substringBefore("token=") + "token=[REDACTED]"
        } else {
            homeUrl
        }
        Log.d(TAG, "Has session: $hasSession, homeUrl: $logSafeHomeUrl")

        homeConfig = NavigatorConfiguration(
            name = "home",
            startLocation = homeUrl,
            navigatorHostId = R.id.home_navigator_host
        )
        tasksConfig = NavigatorConfiguration(
            name = "tasks",
            startLocation = tasksUrl,
            navigatorHostId = R.id.tasks_navigator_host
        )
        mealsConfig = NavigatorConfiguration(
            name = "meals",
            startLocation = mealsUrl,
            navigatorHostId = R.id.meals_navigator_host
        )

        return listOf(homeConfig, tasksConfig, mealsConfig)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Check if community is selected first (before super.onCreate which calls setContentView)
        if (!CommunityManager.hasCommunityUrl(this)) {
            Log.d(TAG, "No community selected, redirecting to community selector")
            super.onCreate(savedInstanceState)
            startActivity(Intent(this, CommunitySelectActivity::class.java))
            finish()
            return
        }

        // Check authentication
        if (!AuthManager.isAuthenticated(this)) {
            Log.d(TAG, "User not authenticated, redirecting to login")
            super.onCreate(savedInstanceState)
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        Log.d(TAG, "User authenticated, loading app")

        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize views
        bottomNavigation = findViewById(R.id.bottom_navigation)
        homeNavigatorHost = findViewById(R.id.home_navigator_host)
        tasksNavigatorHost = findViewById(R.id.tasks_navigator_host)
        mealsNavigatorHost = findViewById(R.id.meals_navigator_host)
        chatContainer = findViewById(R.id.chat_container)
        accountContainer = findViewById(R.id.account_container)

        // Restore active tab if saved
        savedInstanceState?.let {
            activeTab = Tab.entries.getOrNull(it.getInt(KEY_ACTIVE_TAB, 0)) ?: Tab.HOME
        }

        // Set up bottom navigation
        setupBottomNavigation()

        // Sync bottom navigation with restored tab
        bottomNavigation.selectedItemId = when (activeTab) {
            Tab.HOME -> R.id.navigation_home
            Tab.TASKS -> R.id.navigation_tasks
            Tab.MEALS -> R.id.navigation_meals
            Tab.CHAT -> R.id.navigation_chat
            Tab.ACCOUNT -> R.id.navigation_account
        }

        // Request notification permission for Android 13+
        requestNotificationPermission()
    }

    private fun setupBottomNavigation() {
        bottomNavigation.setOnItemSelectedListener { item ->
            val newTab = when (item.itemId) {
                R.id.navigation_home -> Tab.HOME
                R.id.navigation_tasks -> Tab.TASKS
                R.id.navigation_meals -> Tab.MEALS
                R.id.navigation_chat -> Tab.CHAT
                R.id.navigation_account -> Tab.ACCOUNT
                else -> Tab.HOME
            }

            switchToTab(newTab)
            true
        }
    }

    private fun switchToTab(tab: Tab) {
        Log.d(TAG, "Switching from $activeTab to $tab")

        // Hide all containers
        homeNavigatorHost.visibility = View.GONE
        tasksNavigatorHost.visibility = View.GONE
        mealsNavigatorHost.visibility = View.GONE
        chatContainer.visibility = View.GONE
        accountContainer.visibility = View.GONE

        // Show and activate the selected tab
        when (tab) {
            Tab.HOME -> {
                homeNavigatorHost.visibility = View.VISIBLE
                if (::homeConfig.isInitialized) {
                    delegate.setCurrentNavigator(homeConfig)
                }
            }
            Tab.TASKS -> {
                tasksNavigatorHost.visibility = View.VISIBLE
                if (::tasksConfig.isInitialized) {
                    delegate.setCurrentNavigator(tasksConfig)
                }
            }
            Tab.MEALS -> {
                mealsNavigatorHost.visibility = View.VISIBLE
                if (::mealsConfig.isInitialized) {
                    delegate.setCurrentNavigator(mealsConfig)
                }
            }
            Tab.CHAT -> {
                chatContainer.visibility = View.VISIBLE
                ensureChatFragmentAttached()
            }
            Tab.ACCOUNT -> {
                accountContainer.visibility = View.VISIBLE
                ensureAccountFragmentAttached()
            }
        }

        activeTab = tab
    }

    private fun ensureChatFragmentAttached() {
        if (chatFragment == null) {
            chatFragment = CustomChatFragment()
            supportFragmentManager.beginTransaction()
                .add(R.id.chat_container, chatFragment!!, "chat")
                .commit()
            Log.d(TAG, "Chat fragment attached")
        }
    }

    private fun ensureAccountFragmentAttached() {
        if (accountFragment == null) {
            accountFragment = AccountFragment()
            supportFragmentManager.beginTransaction()
                .add(R.id.account_container, accountFragment!!, "account")
                .commit()
            Log.d(TAG, "Account fragment attached")
        }
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

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(KEY_ACTIVE_TAB, activeTab.ordinal)
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
