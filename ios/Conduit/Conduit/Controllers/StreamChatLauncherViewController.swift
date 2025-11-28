import UIKit
internal import WebKit
import StreamChat
import StreamChatUI

/// A simple view controller that launches Stream Chat without participating in Hotwire Native session
class StreamChatLauncherViewController: UIViewController {

    private let chatURL: URL
    private var hasLaunchedChat = false

    init(url: URL) {
        self.chatURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up a simple loading view
        view.backgroundColor = .systemBackground

        let loadingView = createLoadingView()
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Show navigation bar
        navigationController?.setNavigationBarHidden(false, animated: false)

        // Launch Stream Chat if we haven't already
        if !hasLaunchedChat {
            hasLaunchedChat = true
            // Delay slightly to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.launchStreamChat()
            }
        }
    }

    private func createLoadingView() -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Chat icon
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = .systemBlue
        iconContainer.layer.cornerRadius = 40
        containerView.addSubview(iconContainer)

        let iconImageView = UIImageView(image: UIImage(systemName: "message.fill"))
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconContainer.addSubview(iconImageView)

        // Title label
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Community Chat"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)

        // Status label
        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Loading chat..."
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        containerView.addSubview(statusLabel)

        // Activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)

        // Layout constraints
        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconContainer.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    private func launchStreamChat() {
        print("StreamChatLauncherViewController: Launching Stream Chat")

        fetchStreamToken { [weak self] tokenData in
            guard let self = self,
                  let tokenData = tokenData else {
                print("Failed to fetch Stream token")
                // Show error to user
                DispatchQueue.main.async {
                    self?.showError("Failed to load chat. Please try again.")
                }
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
                    apiKey: tokenData.apiKey
                )

                // Push Stream Chat view controller
                print("Presenting Stream Chat view controller")
                self.navigationController?.pushViewController(streamChatVC, animated: true)
            }
        }
    }

    private func fetchStreamToken(completion: @escaping ((userId: String, userName: String, userAvatar: String?, token: String, apiKey: String)?) -> Void) {
        // Get token URL from AppConfig - add .json extension for Rails
        let tokenURL = AppConfig.baseURL.appendingPathComponent("chat/token.json")

        // Get cookies from shared cookie storage
        let cookies = HTTPCookieStorage.shared.cookies(for: tokenURL) ?? []

        // Create request
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add cookies to the request
        let relevantCookies = cookies.filter { cookie in
            // Include session cookies for Rails
            return cookie.name == "_conduit_app_session"
        }

        if !relevantCookies.isEmpty {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: relevantCookies)
            for (header, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: header)
                print("Setting header: \(header)")
            }
            print("Added \(relevantCookies.count) cookies to token request")
        } else {
            print("Warning: No session cookies found for token request")
        }

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
                completion(nil)
                return
            }

            let userAvatar = user["avatar"] as? String
            completion((userId, userName, userAvatar, token, apiKey))
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Chat Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            self.launchStreamChat()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }
}
