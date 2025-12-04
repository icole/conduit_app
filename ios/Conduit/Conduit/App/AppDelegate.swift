import UIKit
internal import WebKit
import HotwireNative
import GoogleSignIn
import UserNotifications
import StreamChat

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire Native
        configureHotwireNative()

        // Register for push notifications
        registerForPushNotifications()

        // Restore Google Sign-In previous session if available
        // Note: This will fail with error -4 if no previous session or URL scheme not configured
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == -4 {
                    // Expected error when no previous session exists or URL scheme missing
                    print("No previous Google Sign-In session to restore (this is normal on first launch)")
                } else {
                    print("Error restoring Google Sign-In: \(error.localizedDescription)")
                }
            } else if let user = user {
                print("Google Sign-In restored for user: \(user.profile?.email ?? "")")
            }
        }

        return true
    }

    // MARK: - Google Sign-In

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    private func configureHotwireNative() {
        // Configure custom web view with user agent
        Hotwire.config.makeCustomWebView = { (configuration: WKWebViewConfiguration) -> WKWebView in
            // Use different user agents for different purposes
            // Rails pages need "Turbo Native", Element needs desktop Safari
            configuration.applicationNameForUserAgent = "Conduit iOS (Turbo Native)"

            let webView = WKWebView(frame: .zero, configuration: configuration)

            // We'll override this per-page for Element
            return webView
        }

        // Configure path configuration if needed
        // This can be extended to load remote configuration
    }

    // MARK: - Push Notifications

    private func registerForPushNotifications() {
        print("🔔 Starting push notification registration...")
        UNUserNotificationCenter.current().delegate = self

        // Check current authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("📊 Current notification settings:")
            print("  → Authorization status: \(self.authStatusString(settings.authorizationStatus))")
            print("  → Alert setting: \(self.settingString(settings.alertSetting))")
            print("  → Sound setting: \(self.settingString(settings.soundSetting))")
            print("  → Badge setting: \(self.settingString(settings.badgeSetting))")

            switch settings.authorizationStatus {
            case .notDetermined:
                // Request permission
                print("🔔 Requesting notification permissions...")
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("❌ Error requesting push notification authorization: \(error)")
                        return
                    }

                    print("✅ Push notification authorization granted: \(granted)")

                    guard granted else {
                        print("⚠️ User denied push notifications")
                        return
                    }

                    DispatchQueue.main.async {
                        print("📱 Registering for remote notifications...")
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }

            case .authorized, .provisional:
                // Already authorized, just register
                print("✅ Already authorized, registering for remote notifications...")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }

            case .denied:
                print("❌ Push notifications are denied. User needs to enable in Settings.")

            @unknown default:
                print("❓ Unknown authorization status")
            }
        }
    }

    private func authStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func settingString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 APNS Device Token Received:")
        print("  → Raw token: \(deviceToken.base64EncodedString())")
        print("  → Hex token: \(token)")
        print("  → Token length: \(deviceToken.count) bytes")

        // Check build environment
        print("\n🔧 Token Environment Check:")
        #if DEBUG
        print("  ✅ Build: DEBUG - Should generate DEVELOPMENT tokens")
        #else
        print("  ❌ Build: RELEASE - Will generate PRODUCTION tokens")
        #endif

        #if targetEnvironment(simulator)
        print("  ⚠️ Running on SIMULATOR - This shouldn't happen!")
        #else
        print("  ✅ Running on PHYSICAL DEVICE")
        #endif

        // Check if this is a different token than before
        if let oldToken = UserDefaults.standard.data(forKey: "pendingDeviceToken") {
            if oldToken == deviceToken {
                print("  ℹ️ Same token as before")
            } else {
                print("  🔄 NEW TOKEN - Different from previous!")
                print("  💡 This suggests environment changed")
            }
        } else {
            print("  🆕 First time token registration")
        }

        // Store token first in case Stream isn't ready yet
        UserDefaults.standard.set(deviceToken, forKey: "pendingDeviceToken")
        print("  → Stored token in UserDefaults for later use")

        // Register device token with Stream Chat via ChatManager
        print("📤 Sending token to ChatManager...")
        ChatManager.shared.registerDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📬 Received remote notification (background/silent):")
        print("  → Full payload: \(userInfo)")

        // Check application state
        switch application.applicationState {
        case .active:
            print("  → App state: ACTIVE (foreground)")
        case .inactive:
            print("  → App state: INACTIVE (transitioning)")
        case .background:
            print("  → App state: BACKGROUND")
        @unknown default:
            print("  → App state: UNKNOWN")
        }

        // Handle Stream Chat push notifications
        if let streamPayload = userInfo["stream"] as? [String: Any] {
            print("  → Stream payload found: \(streamPayload)")
        } else {
            print("  → No Stream payload in notification")
        }

        // Check for aps payload
        if let aps = userInfo["aps"] as? [String: Any] {
            print("  → APS payload: \(aps)")
        }

        completionHandler(.newData)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📬 Notification received while app in FOREGROUND:")
        print("  → Title: \(notification.request.content.title)")
        print("  → Body: \(notification.request.content.body)")
        let userInfo = notification.request.content.userInfo
        print("  → UserInfo: \(userInfo)")

        // Check if this is a Stream Chat notification
        if let streamPayload = userInfo["stream"] as? [String: Any],
           let channelId = streamPayload["channel_id"] as? String,
           let channelType = streamPayload["channel_type"] as? String {
            let cid = "\(channelType):\(channelId)"
            print("  → Stream channel: \(cid)")

            // Check if user is currently viewing this channel
            // If they are, suppress the notification
            if ChatManager.shared.isCurrentlyViewingChannel(cid: cid) {
                print("  ✅ User is viewing this channel - suppressing notification")
                completionHandler([]) // Don't show notification
                return
            }
        }

        // Show notification for other channels or non-chat notifications
        print("  → Showing notification")
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📬 User tapped notification:")
        let userInfo = response.notification.request.content.userInfo
        print("  → UserInfo: \(userInfo)")

        // Handle Stream Chat notification tap
        if let streamPayload = userInfo["stream"] as? [String: Any] {
            print("  → Stream payload found: \(streamPayload)")
            // Navigate to chat tab when notification is tapped
            NotificationCenter.default.post(name: Notification.Name("OpenChatTab"), object: nil)
        } else {
            print("  → No Stream payload found")
        }

        completionHandler()
    }
}
