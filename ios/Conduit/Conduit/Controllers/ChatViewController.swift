import UIKit
import HotwireNative
internal import WebKit
import StreamChat
import StreamChatUI

class ChatViewController: HotwireNativeViewController {

    private var hasLaunchedNativeChat = false
    private var isShowingStreamChat = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure web view for Stream Chat handling
        configureForStreamChat()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Show navigation bar for proper back navigation
        navigationController?.setNavigationBarHidden(false, animated: false)

        // Reset flags when returning to this view
        hasLaunchedNativeChat = false
        isShowingStreamChat = false

        // If returning from Stream Chat, reload the chat page
        if let url = visitableView.webView?.url,
           url.path == "/chat" {
            visitableView.webView?.reload()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Clean up message handler when leaving the view
        if let webView = visitableView.webView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "streamChat")
        }
    }


    private func configureForStreamChat() {
        // Configure web view for Stream Chat
        guard let webView = visitableView.webView else { return }

        // Ensure cookies are preserved for authentication
        webView.configuration.websiteDataStore = .default()

        // Set up message handler for Stream Chat (remove first to avoid duplicates)
        let userContentController = webView.configuration.userContentController
        userContentController.removeScriptMessageHandler(forName: "streamChat")
        userContentController.add(self, name: "streamChat")
    }

    override func visitableDidRender() {
        super.visitableDidRender()

        print("ChatViewController: visitableDidRender - URL: \(visitableView.webView?.url?.absoluteString ?? "nil")")

        // Check if we're on the native prompt page
        if let url = visitableView.webView?.url,
           url.path == "/chat",
           !hasLaunchedNativeChat {
            hasLaunchedNativeChat = true
            print("ChatViewController: Detected chat page, launching native Stream Chat")
            launchNativeStreamChat()
        }
    }

    private func launchNativeStreamChat() {
        print("Launching native Stream Chat")

        // Stop any ongoing web view loading to prevent background errors
        if let webView = visitableView.webView {
            webView.stopLoading()

            // Load a blank page to stop any background activity
            webView.loadHTMLString("<html><body></body></html>", baseURL: nil)
        }

        // Fetch token and user info from the Rails backend
        fetchStreamToken { [weak self] tokenData in
            guard let self = self,
                  let tokenData = tokenData else {
                print("Failed to fetch Stream token")
                return
            }

            DispatchQueue.main.async {
                print("Successfully fetched Stream token for user: \(tokenData.userId)")
                print("API Key: \(tokenData.apiKey)")

                // Create and present Stream Chat view controller
                let streamChatVC = StreamChatViewController(
                    userId: tokenData.userId,
                    userName: tokenData.userName,
                    userAvatar: tokenData.userAvatar,
                    token: tokenData.token,
                    apiKey: tokenData.apiKey,
                    communitySlug: tokenData.communitySlug
                )

                // Mark that we're showing Stream Chat
                self.isShowingStreamChat = true

                // Push Stream Chat view controller instead of replacing
                print("Presenting Stream Chat view controller")
                self.navigationController?.pushViewController(streamChatVC, animated: true)
            }
        }
    }

    private func fetchStreamToken(completion: @escaping ((userId: String, userName: String, userAvatar: String?, token: String, apiKey: String, communitySlug: String?)?) -> Void) {
        // Get token URL from AppConfig - add .json extension for Rails
        let tokenURL = AppConfig.baseURL.appendingPathComponent("chat/token.json")

        // Get cookies from the WebView's cookie store
        let cookieStore = visitableView.webView?.configuration.websiteDataStore.httpCookieStore

        cookieStore?.getAllCookies { cookies in
            // Create request
            var request = URLRequest(url: tokenURL)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            // Debug: print all cookies
            print("All cookies found: \(cookies.count)")
            for cookie in cookies {
                print("Cookie: \(cookie.name) = \(cookie.value.prefix(10))... for domain: \(cookie.domain)")
            }

            // Add cookies to the request
            let relevantCookies = cookies.filter { cookie in
                // Include session cookies for Rails
                return cookie.name == "_conduit_app_session"
            }

            if !relevantCookies.isEmpty {
                let cookieHeaders = HTTPCookie.requestHeaderFields(with: relevantCookies)
                for (header, value) in cookieHeaders {
                    request.setValue(value, forHTTPHeaderField: header)
                    print("Setting header: \(header) = \(value.prefix(50))...")
                }
                print("Added \(relevantCookies.count) cookies to token request")
            } else {
                print("No session cookies found for token request")
            }

            // Continue with the request
            self.performTokenRequest(request, completion: completion)
        }
    }

    private func performTokenRequest(_ request: URLRequest, completion: @escaping ((userId: String, userName: String, userAvatar: String?, token: String, apiKey: String, communitySlug: String?)?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Token fetch error: \(error)")
                completion(nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Token fetch response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("Token fetch failed with status: \(httpResponse.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("Response body: \(body)")
                    }
                    completion(nil)
                    return
                }
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["token"] as? String,
                  let apiKey = json["api_key"] as? String,
                  let user = json["user"] as? [String: Any],
                  let userId = user["id"] as? String,
                  let userName = user["name"] as? String else {
                print("Failed to parse token response")
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("Response body: \(body)")
                }
                completion(nil)
                return
            }

            let userAvatar = user["avatar"] as? String
            let communitySlug = json["community_slug"] as? String
            completion((userId, userName, userAvatar, token, apiKey, communitySlug))
        }.resume()
    }

}

// MARK: - WKScriptMessageHandler

extension ChatViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "streamChat" {
            // Handle message from web page to trigger native chat
            if let body = message.body as? [String: Any],
               let action = body["action"] as? String,
               action == "openChat" {
                launchNativeStreamChat()
            }
        }
    }
}
