package com.colecoding.conduit

import android.app.Application
import android.graphics.Color
import android.util.Log
import android.webkit.CookieManager
import androidx.appcompat.app.AppCompatDelegate
import com.colecoding.conduit.fragments.WebFragment
import com.colecoding.conduit.fragments.WebModalFragment
import com.colecoding.conduit.routing.NotificationTabRouteDecisionHandler
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.config.registerRouteDecisionHandlers
import dev.hotwire.navigation.routing.AppNavigationRouteDecisionHandler
import dev.hotwire.navigation.routing.BrowserTabRouteDecisionHandler
import dev.hotwire.navigation.routing.SystemNavigationRouteDecisionHandler
import com.colecoding.conduit.bridge.BellComponent
import com.colecoding.conduit.bridge.ButtonComponent
import com.colecoding.conduit.bridge.MenuComponent
import com.colecoding.conduit.chat.ChannelHashAvatar
import io.getstream.chat.android.ui.ChatUI
import io.getstream.chat.android.ui.helper.StyleTransformer
import io.getstream.chat.android.ui.helper.TransformStyle
import io.getstream.chat.android.client.ChatClient
import io.getstream.chat.android.client.logger.ChatLogLevel
import io.getstream.chat.android.offline.plugin.factory.StreamOfflinePluginFactory
import io.getstream.chat.android.state.plugin.config.StatePluginConfig
import io.getstream.chat.android.state.plugin.factory.StreamStatePluginFactory
import com.colecoding.conduit.ui.Palette

class MainApplication : Application() {

    companion object {
        private const val TAG = "MainApplication"
        lateinit var instance: MainApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Light, whatever the phone is set to: the website has no dark mode, and
        // chat's colours are the website's. In dark mode Stream's own night
        // backgrounds came back under our dark text (LightModeTest)
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)

        // Configure Hotwire Native
        configureHotwire()

        // Configure cookies for WebView session persistence
        configureCookies()

        // Initialize Firebase
        FirebaseApp.initializeApp(this)
        Log.d(TAG, "Firebase initialized")

        // Fetch FCM token and store it for later registration with Stream
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result
                Log.d(TAG, "FCM Token received: ${token.take(20)}...")
                // Store token for later registration when Stream connects
                getSharedPreferences("push_prefs", MODE_PRIVATE)
                    .edit()
                    .putString("pending_fcm_token", token)
                    .apply()
                Log.d(TAG, "FCM Token stored as pending")
            } else {
                Log.e(TAG, "Failed to get FCM token", task.exception)
            }
        }

        // Initialize Stream Chat (but don't connect yet - will connect after login)
        initializeStreamChat()
    }

    private fun configureHotwire() {
        // Load path configuration from assets
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json"
            )
        )

        // Register fragment destinations
        Hotwire.registerFragmentDestinations(
            WebFragment::class,
            WebModalFragment::class
        )

        // Set default fragment
        Hotwire.defaultFragmentDestination = WebFragment::class

        // Ours first; the rest are Hotwire's defaults
        Hotwire.registerRouteDecisionHandlers(
            NotificationTabRouteDecisionHandler(),
            AppNavigationRouteDecisionHandler(),
            BrowserTabRouteDecisionHandler(),
            SystemNavigationRouteDecisionHandler()
        )

        // Register bridge components
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("menu", ::MenuComponent),
            BridgeComponentFactory("button", ::ButtonComponent),
            BridgeComponentFactory("bell", ::BellComponent)
        )

        // Configure JSON converter for bridge message serialization
        Hotwire.config.jsonConverter = KotlinXJsonConverter()

        Log.d(TAG, "Hotwire configured")
    }

    private fun configureCookies() {
        // Configure cookies for session persistence
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        Log.d(TAG, "Cookie manager configured for session persistence")
    }

    private fun initializeStreamChat() {
        try {
            val apiKey = BuildConfig.STREAM_API_KEY
            Log.d(TAG, "Initializing Stream Chat with API key: ${apiKey.take(10)}...")

            // Create offline plugin for better UX
            val offlinePlugin = StreamOfflinePluginFactory(this)

            // Create state plugin
            val statePlugin = StreamStatePluginFactory(
                config = StatePluginConfig(),
                appContext = this
            )

            // Initialize ChatClient
            val client = ChatClient.Builder(apiKey, this)
                .withPlugins(offlinePlugin, statePlugin)
                .logLevel(if (BuildConfig.DEBUG) ChatLogLevel.ALL else ChatLogLevel.NOTHING)
                .build()

            // "#" instead of a collage of member photos, in the list and chat header
            ChatUI.channelAvatarRenderer = ChannelHashAvatar.renderer

            // Bubbles in the app's palette: yours a soft green, everyone else's
            // the surface colour on the paper page, neither outlined
            TransformStyle.messageListItemStyleTransformer = StyleTransformer { style ->
                style.copy(
                    messageBackgroundColorMine = Palette.greenTint,
                    messageBackgroundColorTheirs = Palette.surface,
                    messageStrokeColorMine = Color.TRANSPARENT,
                    messageStrokeWidthMine = 0f,
                    messageStrokeColorTheirs = Color.TRANSPARENT,
                    messageStrokeWidthTheirs = 0f,
                    // A quiet "Today" pill rather than a dark one
                    dateSeparatorBackgroundColor = Palette.line,
                    textStyleDateSeparator = style.textStyleDateSeparator.copy(color = Palette.muted)
                )
            }
            // The paper page under the channel list, not white past the last row
            TransformStyle.channelListStyleTransformer = StyleTransformer { style ->
                style.copy(backgroundColor = Palette.paper)
            }

            Log.d(TAG, "Stream Chat initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Stream Chat", e)
        }
    }
}