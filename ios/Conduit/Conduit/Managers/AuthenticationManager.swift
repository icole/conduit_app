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
        if let userId = userId {
            UserDefaults.standard.set(userId, forKey: userIdKey)
        }
        print("Stored auth token")
    }

    /// Get stored auth token
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: authTokenKey)
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
