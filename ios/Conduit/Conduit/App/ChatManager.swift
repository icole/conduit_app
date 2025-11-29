import Foundation
import StreamChat

/// Singleton manager for Stream Chat client
class ChatManager {
    static let shared = ChatManager()

    private(set) var chatClient: ChatClient?

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

    func disconnect() {
        if let client = chatClient {
            print("🔌 ChatManager: Disconnecting Stream Chat client (user: \(client.currentUserId ?? "unknown"))")
            client.disconnect()
            chatClient = nil
        }
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
