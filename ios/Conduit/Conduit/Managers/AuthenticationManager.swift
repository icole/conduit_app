import Foundation
internal import WebKit

class AuthenticationManager {
    static let shared = AuthenticationManager()

    private init() {}

    /// Check if user is authenticated by verifying session cookie exists
    func isAuthenticated() -> Bool {
        // Check for Rails session cookie
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let hasSessionCookie = cookies.contains { cookie in
            cookie.name == "_conduit_app_session"
        }

        print("Authentication check - Session cookie found: \(hasSessionCookie)")
        return hasSessionCookie
    }

    /// Check authentication status with the server
    func checkAuthenticationStatus(completion: @escaping (Bool) -> Void) {
        #if DEBUG
        let authCheckURL = URL(string: "http://localhost:3000/api/v1/auth/check")!
        #else
        let authCheckURL = URL(string: "https://your-production-url.com/api/v1/auth/check")!
        #endif

        var request = URLRequest(url: authCheckURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add cookies
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

    /// Clear all authentication data
    func logout() {
        // Clear HTTP cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        // Clear WKWebsiteDataStore cookies
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                for: records,
                completionHandler: {
                    print("Cleared all web data")
                }
            )
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
