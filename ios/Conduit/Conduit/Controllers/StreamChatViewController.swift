import UIKit
import StreamChat
import StreamChatUI

class StreamChatViewController: UIViewController {

    // Stream Chat components
    private var channelListController: CustomChannelListVC?

    // User info passed from Rails
    private let userId: String
    private let userName: String
    private let userAvatar: String?
    private let token: String?
    private let apiKey: String?

    init(userId: String, userName: String, userAvatar: String? = nil, token: String? = nil, apiKey: String? = nil) {
        self.userId = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.token = token
        self.apiKey = apiKey
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add a back button to allow navigation back
        setupNavigationBar()

        // Set up Stream Chat
        setupStreamChat()
    }

    private func setupNavigationBar() {
        // Show navigation bar without back button (accessed via tabs)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.title = "Community Chat"
        // No back button needed - this is accessed via tab bar
        navigationItem.hidesBackButton = true

        // Create the plus button for channel creation
        let createButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(createChannelTapped)
        )

        #if DEBUG
        // In debug mode, add both debug and create buttons
        let debugButton = UIBarButtonItem(
            title: "Debug",
            style: .plain,
            target: self,
            action: #selector(showDebugMenu)
        )
        navigationItem.rightBarButtonItems = [createButton, debugButton]
        #else
        // In release mode, just add the create button
        navigationItem.rightBarButtonItem = createButton
        #endif
    }

    @objc private func createChannelTapped() {
        // Delegate to the CustomChannelListVC
        channelListController?.createChannelTapped()
    }

    @objc private func showDebugMenu() {
        let alert = UIAlertController(title: "Push Notification Debug", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Check Device Registration", style: .default) { _ in
            self.checkRegisteredDevices()
            self.checkPushProviders()
        })

        alert.addAction(UIAlertAction(title: "Re-register Device Token", style: .default) { _ in
            print("🔄 Manually re-registering device token...")
            if let token = UserDefaults.standard.data(forKey: "pendingDeviceToken") {
                let tokenHex = token.map { String(format: "%02.2hhx", $0) }.joined()
                print("  → Found stored token: \(tokenHex.prefix(20))...")
                print("  → Forcing registration with Stream...")

                // Force registration even if it was already tried
                UserDefaults.standard.removeObject(forKey: "deviceTokenRegistered")
                ChatManager.shared.registerDeviceToken(token)
            } else {
                print("  ❌ No stored device token found")
                print("  💡 Requesting new token from iOS...")
                UIApplication.shared.registerForRemoteNotifications()
            }
        })

        alert.addAction(UIAlertAction(title: "Show Stream User ID", style: .default) { _ in
            if let client = ChatManager.shared.chatClient {
                print("📊 Stream Chat Debug Info:")
                print("  → User ID: \(client.currentUserId ?? "none")")
                print("  → Connection status: \(client.connectionStatus)")
                print("  → API Key: \(client.config.apiKey.apiKeyString)")

                // Check notification settings
                print("\n📱 iOS Notification Settings:")
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    print("  → Authorization: \(settings.authorizationStatus.rawValue)")
                    print("  → Alert: \(settings.alertSetting.rawValue)")
                    print("  → Sound: \(settings.soundSetting.rawValue)")
                    print("  → Badge: \(settings.badgeSetting.rawValue)")
                    print("  → Critical Alert: \(settings.criticalAlertSetting.rawValue)")
                    print("  → Notification Center: \(settings.notificationCenterSetting.rawValue)")
                    print("  → Lock Screen: \(settings.lockScreenSetting.rawValue)")
                }

                print("\n🔧 Build Configuration:")
                #if DEBUG
                print("  → Build: DEBUG (Development)")
                #else
                print("  → Build: RELEASE (Production)")
                #endif

                print("\n💡 Testing Tips:")
                print("  1. Send message from DIFFERENT user (not User ID: \(client.currentUserId ?? "?"))")
                print("  2. Put app in BACKGROUND first")
                print("  3. Check Stream Dashboard > Push Notifications > Logs")
                print("  4. Verify APNs certificate is for Production environment")
            }
        })

        alert.addAction(UIAlertAction(title: "Test Local Notification", style: .default) { _ in
            self.testLocalNotification()
        })

        alert.addAction(UIAlertAction(title: "Send Test Message", style: .default) { _ in
            self.sendTestMessage()
        })

        alert.addAction(UIAlertAction(title: "Unregister All Devices", style: .destructive) { _ in
            self.unregisterAllDevices()
        })

        alert.addAction(UIAlertAction(title: "Clear Device Token", style: .destructive) { _ in
            print("🗑️ Clearing stored device token...")
            UserDefaults.standard.removeObject(forKey: "pendingDeviceToken")
            UserDefaults.standard.removeObject(forKey: "deviceTokenRegistered")
            UserDefaults.standard.removeObject(forKey: "deviceTokenRegisteredAt")
            print("  → Cleared. Delete and reinstall app for fresh start.")
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func testLocalNotification() {
        print("🔔 Testing local notification...")

        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "If you see this, notifications are working locally"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("  ❌ Error scheduling local notification: \(error)")
            } else {
                print("  ✅ Local notification scheduled (will show in 2 seconds)")
            }
        }
    }

    private func unregisterAllDevices() {
        print("🗑️ Unregistering all devices from Stream...")

        guard let client = ChatManager.shared.chatClient else {
            print("  ❌ No chat client available")
            return
        }

        let controller = client.currentUserController()
        controller.synchronize { error in
            if let error = error {
                print("  ❌ Error fetching devices: \(error)")
                return
            }

            let devices = controller.currentUser?.devices ?? []
            print("  📱 Found \(devices.count) device(s) to unregister")

            if devices.isEmpty {
                print("  ℹ️ No devices to unregister")
                return
            }

            // Unregister each device
            for (index, device) in devices.enumerated() {
                print("  Unregistering device \(index + 1): \(device.id)")

                controller.removeDevice(id: device.id) { error in
                    if let error = error {
                        print("    ❌ Failed: \(error)")
                    } else {
                        print("    ✅ Unregistered successfully")
                    }
                }
            }

            // Clear local storage
            UserDefaults.standard.removeObject(forKey: "pendingDeviceToken")
            UserDefaults.standard.removeObject(forKey: "deviceTokenRegistered")
            UserDefaults.standard.removeObject(forKey: "deviceTokenRegisteredAt")

            print("\n  💡 Next steps:")
            print("     1. Force quit the app")
            print("     2. Relaunch to get fresh token")
            print("     3. Token will auto-register with correct environment")
        }
    }

    private func sendTestMessage() {
        print("💬 Sending test message to general channel...")

        guard let client = ChatManager.shared.chatClient else {
            print("  ❌ No chat client available")
            return
        }

        // Get or create the general channel
        let channelId = ChannelId(type: .team, id: "general")
        let channelController = client.channelController(for: channelId)

        // Create channel if it doesn't exist
        channelController.synchronize { error in
            if let error = error {
                print("  ❌ Error getting channel: \(error)")
                return
            }

            // Send a test message
            let text = "Push notification test at \(Date())"
            channelController.createNewMessage(text: text) { result in
                switch result {
                case .success(let messageId):
                    print("  ✅ Test message sent successfully!")
                    print("     Message ID: \(messageId)")
                    print("     Channel: general")
                    print("     Text: \(text)")
                    print("\n  💡 Instructions:")
                    print("     1. Now close the app (swipe up to app switcher)")
                    print("     2. Have another user reply to this message")
                    print("     3. You should receive a push notification")
                    print("     4. Check Stream Dashboard > Push Logs for attempts")

                case .failure(let error):
                    print("  ❌ Failed to send message: \(error)")
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        print("📱 StreamChatViewController: viewWillAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Don't disconnect Stream Chat - keep the connection alive for push notifications
        // The ChatManager maintains the singleton connection
    }

    private func setupStreamChat() {
        print("StreamChatViewController: setupStreamChat called")
        print("Token provided: \(token != nil)")
        print("API Key provided: \(apiKey != nil)")

        // Show loading indicator
        showLoading()

        // Move initialization to background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Check if we already have an existing connection
            if self.token == nil && self.apiKey == nil,
               let existingClient = ChatManager.shared.chatClient,
               existingClient.currentUserId == self.userId {
                print("Using existing Stream Chat connection without fetching new token")
                // Already connected, just setup the UI
                DispatchQueue.main.async { [weak self] in
                    self?.setupChannelList()
                    self?.registerPendingDeviceToken()
                    self?.hideLoading()
                }
            } else if let token = self.token, let apiKey = self.apiKey {
                // If token and API key were provided, use them directly
                print("Using provided token and API key")
                let userData = UserData(
                    id: self.userId,
                    name: self.userName,
                    avatar: self.userAvatar
                )
                let tokenData = TokenData(
                    token: token,
                    user: userData,
                    apiKey: apiKey
                )
                self.initializeStreamChat(with: tokenData)
            } else {
                print("No token provided, fetching from backend")
                // Otherwise, fetch Stream token from Rails backend
                self.fetchStreamToken { [weak self] result in
                    switch result {
                    case .success(let tokenData):
                        self?.initializeStreamChat(with: tokenData)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self?.showError(error)
                        }
                    }
                }
            }
        }
    }

    private func fetchStreamToken(completion: @escaping (Result<TokenData, Error>) -> Void) {
        // Get base URL from AppConfig
        let baseURL = AppConfig.baseURL
        let tokenURL = baseURL.appendingPathComponent("chat/token.json")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "GET"

        // Include cookies for authentication
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, value) in headers {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(StreamChatError.noData))
                }
                return
            }

            do {
                let tokenData = try JSONDecoder().decode(TokenData.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(tokenData))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func initializeStreamChat(with tokenData: TokenData) {
        print("StreamChatViewController: initializeStreamChat called at \(Date())")
        print("User ID: \(tokenData.user.id)")
        print("User Name: \(tokenData.user.name)")
        print("API Key: \(tokenData.apiKey)")

        // Check if ChatManager already has a connected client for this user
        if let existingClient = ChatManager.shared.chatClient {
            print("Found existing client. Current user: \(existingClient.currentUserId ?? "nil")")

            if existingClient.currentUserId == tokenData.user.id {
                print("✅ Reusing existing Stream Chat connection for user: \(tokenData.user.id)")
                // Just setup the channel list with existing connection
                DispatchQueue.main.async { [weak self] in
                    self?.setupChannelList()
                    self?.registerPendingDeviceToken()
                }
                return
            } else {
                print("⚠️ Different user detected. Current: \(existingClient.currentUserId ?? "nil"), New: \(tokenData.user.id)")
                // Need to disconnect and reconnect with new user
                ChatManager.shared.disconnect()
            }
        }

        print("🔄 Creating new Stream Chat connection...")

        // Configure Stream Chat with push notifications support
        var config = ChatClientConfig(apiKey: .init(tokenData.apiKey))

        // Enable push notifications in the SDK
        config.isLocalStorageEnabled = true
        config.staysConnectedInBackground = true

        // Initialize chat client through ChatManager
        let chatClient = ChatClient(config: config)
        ChatManager.shared.configure(with: chatClient)
        print("Chat client initialized and registered with ChatManager")

        // Connect user
        let userInfo = UserInfo(
            id: tokenData.user.id,
            name: tokenData.user.name,
            imageURL: tokenData.user.avatar.flatMap { URL(string: $0) }
        )

        print("Connecting user to Stream Chat...")
        chatClient.connectUser(
            userInfo: userInfo,
            token: Token(stringLiteral: tokenData.token)
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Stream Chat connection error: \(error)")
                    self?.showError(error)
                } else {
                    print("✅ Stream Chat connected successfully at \(Date())")
                    self?.setupChannelList()

                    // Register pending device token after connection (only once)
                    print("🔄 Checking for pending device token after connection...")
                    self?.registerPendingDeviceToken()
                }
            }
        }
    }

    private func registerPendingDeviceToken() {
        print("📱 registerPendingDeviceToken called")

        // Check current Stream client status
        if let client = ChatManager.shared.chatClient {
            print("  → Stream client exists, user: \(client.currentUserId ?? "none")")
            print("  → Connection status: \(client.connectionStatus)")
        } else {
            print("  ❌ No Stream client available yet")
            return
        }

        // Check if there's a pending device token from push notification registration
        if let deviceToken = UserDefaults.standard.data(forKey: "pendingDeviceToken") {
            let tokenHex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            print("  ✅ Found pending device token: \(tokenHex.prefix(20))...")
            print("  📤 Registering with Stream Chat...")

            // Use ChatManager's registerDeviceToken which has the correct provider name
            ChatManager.shared.registerDeviceToken(deviceToken)
        } else {
            print("  ℹ️ No pending device token found in UserDefaults")

            // Check if we need to request a new token
            print("  🔄 Requesting fresh device token from iOS...")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func checkRegisteredDevices() {
        print("🔍 Checking registered devices for push notifications...")

        guard let client = ChatManager.shared.chatClient else {
            print("  ❌ No chat client available")
            return
        }

        let controller = client.currentUserController()
        controller.synchronize { error in
            if let error = error {
                print("  ❌ Error fetching current user: \(error)")
                return
            }

            let devices = controller.currentUser?.devices ?? []
            print("  📱 Registered devices count: \(devices.count)")

            for (index, device) in devices.enumerated() {
                print("  Device \(index + 1):")
                print("    → ID: \(device.id)")
                print("    → Created: \(device.createdAt)")
                // Note: Push provider details are not exposed in the Device model
            }

            if devices.isEmpty {
                print("  ⚠️ No devices registered! Push notifications won't work.")
                print("  💡 Make sure device token is being registered with Stream")
            } else {
                print("  ✅ Device(s) registered successfully")
                print("  💡 Check Stream Dashboard > Push Notifications for provider details")
            }
        }
    }

    private func checkPushProviders() {
        print("\n🔧 Checking Stream push provider configuration...")

        print("📱 Current iOS Build Environment:")
        #if targetEnvironment(simulator)
        print("  → Running on: SIMULATOR (no push support)")
        #else
        print("  → Running on: PHYSICAL DEVICE")
        #endif

        #if DEBUG
        print("  → Build Config: DEBUG")
        print("  → Token Type: Development APNs tokens")
        #else
        print("  → Build Config: RELEASE")
        print("  → Token Type: Production APNs tokens")
        #endif

        print("\n💡 Environment Mismatch Fix:")
        print("  'BadEnvironmentKeyInToken' means:")
        print("  → Your app: Sending PRODUCTION tokens (Release build)")
        print("  → Stream expects: DEVELOPMENT tokens")
        print("\n  Solution:")
        print("  1. In Xcode: Click 'Conduit' scheme → Edit Scheme")
        print("  2. Run → Info → Build Configuration → Change to 'Debug'")
        print("  3. Delete app from phone and rebuild")
    }

    private func setupChannelList() {
        print("StreamChatViewController: setupChannelList called")

        // Ensure we're on the main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let client = ChatManager.shared.chatClient else {
                print("Chat client is nil in ChatManager, cannot setup channel list")
                self.hideLoading()
                return
            }

            // Debug: List registered devices (on background queue to avoid blocking)
            DispatchQueue.global(qos: .background).async {
                self.checkRegisteredDevices()
            }

            // Create channel list query
            let query = ChannelListQuery(
                filter: .and([
                    .equal(.type, to: .team),
                    .containMembers(userIds: [self.userId])
                ])
            )
            print("Created channel list query for user: \(self.userId)")

            // Create channel list controller
            let channelList = client.channelListController(query: query)
            print("Created channel list controller")

            // Customize appearance - assign the types, not instances
            Components.default.channelListRouter = ConduitChannelListRouter.self
            // Note: Channel list item customization would require more setup with Stream Chat UI v4
            // For now, the mute indicator is shown in the channel name

            // Create custom channel list view controller with channel creation support
            let channelListVC = CustomChannelListVC()
            channelListVC.controller = channelList
            print("Created CustomChannelListVC with channel creation support")

            // Add as child view controller
            print("Adding channel list as child view controller")
            self.addChild(channelListVC)
            self.view.addSubview(channelListVC.view)
            channelListVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                channelListVC.view.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                channelListVC.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                channelListVC.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                channelListVC.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            channelListVC.didMove(toParent: self)

            self.channelListController = channelListVC

            // Hide loading
            self.hideLoading()
        }
    }

    private func showLoading() {
        // Add loading indicator
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.tag = 999
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadingView.startAnimating()
    }

    private func hideLoading() {
        view.viewWithTag(999)?.removeFromSuperview()
    }

    private func showError(_ error: Error) {
        hideLoading()

        let alert = UIAlertController(
            title: "Chat Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            self.setupStreamChat()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }
}

// MARK: - Supporting Types

struct TokenData: Decodable {
    let token: String
    let user: UserData
    let apiKey: String

    enum CodingKeys: String, CodingKey {
        case token
        case user
        case apiKey = "api_key"
    }
}

struct UserData: Decodable {
    let id: String
    let name: String
    let avatar: String?
}

enum StreamChatError: LocalizedError {
    case noData

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received from server"
        }
    }
}

// MARK: - Custom Router

class ConduitChannelListRouter: ChatChannelListRouter {
    override func showChannel(for cid: ChannelId) {
        // Get the chat client from the root view controller's channel list
        guard let channelListVC = rootViewController as? ChatChannelListVC else {
            return
        }

        guard let client = channelListVC.controller?.client else {
            return
        }

        // Create channel controller with the client on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let channelController = client.channelController(for: cid)

            DispatchQueue.main.async {
                // Create and configure optimized channel view controller
                let channelVC = CustomChannelVC()
                channelVC.channelController = channelController

                // Push to navigation controller
                self.rootViewController.navigationController?.pushViewController(channelVC, animated: true)
            }
        }
    }
}