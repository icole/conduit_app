import Foundation
internal import WebKit

class AuthenticationManager {
    static let shared = AuthenticationManager()

    private let authTokenKey = "auth_token"
    private let userIdKey = "user_id"

    private init() {}

    /// Store auth token from login response
    func storeAuthToken(_ token: String, userId: Int? = nil) {
        UserDefaults.standard.set(token, forKey: authTokenKey)
        // Now signed in: this phone can get the server's push notifications
        defer { PushDeviceRegistrar.shared.registerWithServer() }
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }
        print("Stored auth token")
    }

    /// Get stored auth token
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: authTokenKey)
    }

    /// Sends a request with the API token, refreshing the token once if the
    /// server refuses it (it allows that for a week after expiry). Without a
    /// usable token the request goes with the session cookie alone, as it did
    /// before the app sent its token; CON-89 removes that fallback.
    /// Completes on the main queue.
    func send(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let token = getAuthToken() else {
            Self.dataTask(request, completion)
            return
        }
        Self.dataTask(Self.authorized(request, token)) { data, response, error in
            guard (response as? HTTPURLResponse)?.statusCode == 401 else {
                completion(data, response, error)
                return
            }
            self.refreshAuthToken { newToken in
                Self.dataTask(newToken.map { Self.authorized(request, $0) } ?? request, completion)
            }
        }
    }

    /// A fresh API token for one that has expired, or nil if there isn't one to be had
    func refreshAuthToken(completion: @escaping (String?) -> Void) {
        guard let expired = getAuthToken() else {
            completion(nil)
            return
        }
        var request = URLRequest(url: AppConfig.baseURL.appendingPathComponent("api/v1/auth/refresh"))
        request.httpMethod = "POST"
        Self.dataTask(Self.authorized(request, expired)) { data, response, _ in
            guard (response as? HTTPURLResponse)?.statusCode == 200, let data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let token = json["auth_token"] as? String else {
                completion(nil)
                return
            }
            self.storeAuthToken(token)
            completion(token)
        }
    }

    private static func authorized(_ request: URLRequest, _ token: String) -> URLRequest {
        var request = request
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func dataTask(_ request: URLRequest, _ completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { completion(data, response, error) }
        }.resume()
    }

    /// Check if user is authenticated by verifying auth token or session cookie exists
    func isAuthenticated() -> Bool {
        // First check for auth token (more reliable)
        if let token = getAuthToken(), !token.isEmpty {
            print("Authentication check - Auth token found")
            return true
        }

        // Fallback to checking for Rails session cookie
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let hasSessionCookie = cookies.contains { cookie in
            cookie.name == "_conduit_app_session"
        }

        print("Authentication check - Session cookie found: \(hasSessionCookie)")
        return hasSessionCookie
    }

    /// Check authentication status with the server
    func checkAuthenticationStatus(completion: @escaping (Bool) -> Void) {
        let authCheckURL = AppConfig.baseURL.appendingPathComponent("api/v1/auth/check")

        var request = URLRequest(url: authCheckURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if available
        if let authToken = getAuthToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        // Also add cookies as fallback
        if let cookies = HTTPCookieStorage.shared.cookies(for: authCheckURL) {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, value) in headers {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                let authenticated = httpResponse.statusCode == 200
                print("Auth check response: \(httpResponse.statusCode) - Authenticated: \(authenticated)")
                DispatchQueue.main.async {
                    completion(authenticated)
                }
            } else {
                print("Auth check failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }

    /// Clear all authentication data (synchronous version for backward compatibility)
    func logout() {
        // Stop the server's push notifications to this phone, while still signed in
        PushDeviceRegistrar.shared.unregisterFromServer()

        // Clear auth token
        UserDefaults.standard.removeObject(forKey: authTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)

        // Clear HTTP cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Clear WKWebsiteDataStore - all types including cache
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        // Use semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)

        dataStore.removeData(ofTypes: allTypes, modifiedSince: Date.distantPast) {
            print("Cleared all WebView data (cookies, cache, localStorage, etc.)")
            semaphore.signal()
        }

        // Wait up to 2 seconds for cleanup
        _ = semaphore.wait(timeout: .now() + 2.0)
    }

    /// Clear all authentication data with completion handler
    func logout(completion: @escaping () -> Void) {
        // Stop the server's push notifications to this phone, while still signed in
        PushDeviceRegistrar.shared.unregisterFromServer()

        // Clear auth token
        UserDefaults.standard.removeObject(forKey: authTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)

        // Clear HTTP cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Clear WKWebsiteDataStore - all types including cache
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: allTypes, modifiedSince: Date.distantPast) {
            print("Cleared all WebView data (cookies, cache, localStorage, etc.)")
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    /// Sync cookies from HTTPCookieStorage to WKWebsiteDataStore
    func syncCookiesToWebView(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let cookies = HTTPCookieStorage.shared.cookies ?? []

        let dispatchGroup = DispatchGroup()

        for cookie in cookies {
            dispatchGroup.enter()
            dataStore.httpCookieStore.setCookie(cookie) {
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            print("Synced \(cookies.count) cookies to WebView")
            completion()
        }
    }
}
