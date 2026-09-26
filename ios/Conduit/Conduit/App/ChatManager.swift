import Foundation
import StreamChat

/// Singleton manager for Stream Chat client
class ChatManager {
    static let shared = ChatManager()

    private(set) var chatClient: ChatClient?
    private var currentlyViewingChannelCid: String?

    /// The channel a tapped notification asked for, kept until the chat screen
    /// is connected and can open it: taps arrive before launch has finished,
    /// before sign-in, or before the Chat tab has ever been shown.
    private var pendingChannel: (cid: String, requestedAt: Date)?

    private init() {}

    func configure(with client: ChatClient) {
        // If we already have a client, disconnect it first
        if let existingClient = chatClient {
            print("⚠️ ChatManager: Disconnecting existing client (user: \(existingClient.currentUserId ?? "unknown")) before configuring new one")
            existingClient.disconnect()
        }
        self.chatClient = client
        print("✅ ChatManager: Configured with new client")

        // Add connection state observer
        client.connectionController().delegate = self
    }

    func registerDeviceToken(_ deviceToken: Data) {
        print("📲 ChatManager.registerDeviceToken called")
        print("  → Token size: \(deviceToken.count) bytes")

        guard let client = chatClient else {
            print("  ❌ No chat client available, storing token for later")
            UserDefaults.standard.set(deviceToken, forKey: "pendingDeviceToken")
            return
        }

        guard let userId = client.currentUserId else {
            print("  ❌ No current user ID, storing token for later")
            UserDefaults.standard.set(deviceToken, forKey: "pendingDeviceToken")
            return
        }

        print("  ✅ Client ready, user: \(userId)")
        print("  📤 Registering device with Stream...")

        // Explicitly specify the provider name we configured in Stream Dashboard
        let providerName = "Stream-Push-Notifications"
        print("  → Attempting registration with provider: '\(providerName)'...")

        client.currentUserController().addDevice(.apn(token: deviceToken, providerName: providerName)) { error in
            if let error = error {
                print("  ❌ Error registering device token with Stream:")
                print("     Error: \(error)")

                // Try to extract more details
                if let streamError = error as? ClientError {
                    print("     Stream error details: \(streamError)")
                }
            } else {
                print("  ✅ Successfully registered device token with Stream Chat!")
                print("     Provider: \(providerName)")
                print("     User: \(userId)")
                print("     Time: \(Date())")

                // Mark as registered and clear pending token
                UserDefaults.standard.set(Date(), forKey: "deviceTokenRegisteredAt")
                UserDefaults.standard.removeObject(forKey: "pendingDeviceToken")

                // Verify registration by checking devices
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.verifyDeviceRegistration()
                }
            }
        }
    }

    private func verifyDeviceRegistration() {
        print("🔍 Verifying device registration...")

        guard let client = chatClient else {
            print("  ❌ No client available for verification")
            return
        }

        let controller = client.currentUserController()
        controller.synchronize { error in
            if let error = error {
                print("  ❌ Error verifying: \(error)")
                return
            }

            let devices = controller.currentUser?.devices ?? []
            print("  ✅ Verification complete: \(devices.count) device(s) registered")

            if devices.isEmpty {
                print("  ⚠️ WARNING: Registration reported success but no devices found!")
                print("  💡 Check Stream Dashboard logs for errors")
            } else {
                print("  ✅ Push notifications should now work!")
            }
        }
    }

    // MARK: - Opening a channel from a notification

    func requestChannel(cid: String) {
        pendingChannel = (cid: cid, requestedAt: Date())
    }

    var hasPendingChannel: Bool {
        pendingChannel != nil
    }

    /// The requested channel, handed out once. A request older than five
    /// minutes is dropped so a stale tap never opens a chat later on.
    func takePendingChannel() -> String? {
        defer { pendingChannel = nil }
        guard let pending = pendingChannel, Date().timeIntervalSince(pending.requestedAt) < 300 else { return nil }
        return pending.cid
    }

    /// "team:abc123" from a Stream push payload ({"stream": {"cid": ...}}).
    static func channelCid(fromNotification userInfo: [AnyHashable: Any]) -> String? {
        guard let stream = userInfo["stream"] as? [String: Any] else { return nil }
        if let cid = stream["cid"] as? String, !cid.isEmpty {
            return cid
        }
        if let type = stream["channel_type"] as? String, let id = stream["channel_id"] as? String, !type.isEmpty, !id.isEmpty {
            return "\(type):\(id)"
        }
        return nil
    }

    func disconnect() {
        if let client = chatClient {
            print("🔌 ChatManager: Disconnecting Stream Chat client (user: \(client.currentUserId ?? "unknown"))")
            client.disconnect()
            chatClient = nil
        }
    }

    // MARK: - Channel Viewing Tracking

    /// Set the channel that the user is currently viewing
    func setCurrentlyViewingChannel(cid: String?) {
        currentlyViewingChannelCid = cid
        if let cid = cid {
            print("👀 ChatManager: User now viewing channel: \(cid)")
        } else {
            print("👀 ChatManager: User left channel")
        }
    }

    /// Check if the user is currently viewing a specific channel
    func isCurrentlyViewingChannel(cid: String) -> Bool {
        return currentlyViewingChannelCid == cid
    }
}

// MARK: - ChatConnectionControllerDelegate
extension ChatManager: ChatConnectionControllerDelegate {
    func connectionController(_ controller: ChatConnectionController, didUpdateConnectionStatus status: ConnectionStatus) {
        print("📡 ChatManager: Connection status changed to: \(status)")

        switch status {
        case .connecting:
            print("  → Connecting...")
        case .connected:
            print("  → Connected successfully")
        case .disconnecting:
            print("  → Disconnecting")
        case .disconnected:
            print("  → Disconnected")
        @unknown default:
            print("  → Unknown connection status")
        }
    }
}
