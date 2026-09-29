import Foundation

/// Tells the Conduit server which phone to send its own push notifications
/// to (task reminders). Stream gets the same APNs token separately, for chat.
/// The token is registered once someone is signed in, again on every launch
/// (harmless), and removed when they sign out.
final class PushDeviceRegistrar {
    static let shared = PushDeviceRegistrar()

    private let tokenKey = "conduitPushDeviceToken"

    private init() {}

    /// The APNs token arrived (every launch, once notifications are allowed).
    func update(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        registerWithServer()
    }

    /// Sends the phone's token for whoever is signed in, if both are known.
    func registerWithServer() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let authToken = AuthenticationManager.shared.getAuthToken() else { return }

        send("POST", body: ["token": token, "platform": "apple", "name": "iPhone"], authToken: authToken)
    }

    /// Call before the sign-in token is cleared, so the server stops sending
    /// this person's notifications to this phone.
    func unregisterFromServer() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey),
              let authToken = AuthenticationManager.shared.getAuthToken() else { return }

        send("DELETE", body: ["token": token], authToken: authToken)
    }

    private func send(_ method: String, body: [String: String], authToken: String) {
        var request = URLRequest(url: AppConfig.baseURL.appendingPathComponent("api/v1/push_devices"))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            print("📱 Push device \(method): \(status.map(String.init) ?? error?.localizedDescription ?? "no response")")
        }.resume()
    }
}
