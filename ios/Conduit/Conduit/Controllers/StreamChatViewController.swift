import UIKit
import StreamChat
import StreamChatUI

class StreamChatViewController: UIViewController {

    // Stream Chat components
    private var chatClient: ChatClient?
    private var channelListController: ChatChannelListVC?

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Clean up Stream Chat connection if needed
    }

    private func setupStreamChat() {
        print("StreamChatViewController: setupStreamChat called")
        print("Token provided: \(token != nil)")
        print("API Key provided: \(apiKey != nil)")

        // Show loading indicator
        showLoading()

        // If token and API key were provided, use them directly
        if let token = self.token, let apiKey = self.apiKey {
            print("Using provided token and API key")
            let userData = UserData(
                id: userId,
                name: userName,
                avatar: userAvatar
            )
            let tokenData = TokenData(
                token: token,
                user: userData,
                apiKey: apiKey
            )
            initializeStreamChat(with: tokenData)
        } else {
            print("No token provided, fetching from backend")
            // Otherwise, fetch Stream token from Rails backend
            fetchStreamToken { [weak self] result in
                switch result {
                case .success(let tokenData):
                    self?.initializeStreamChat(with: tokenData)
                case .failure(let error):
                    self?.showError(error)
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
        print("StreamChatViewController: initializeStreamChat called")
        print("User ID: \(tokenData.user.id)")
        print("User Name: \(tokenData.user.name)")
        print("API Key: \(tokenData.apiKey)")

        // Configure Stream Chat
        let config = ChatClientConfig(apiKey: .init(tokenData.apiKey))

        // Initialize chat client
        chatClient = ChatClient(config: config)
        print("Chat client initialized")

        // Connect user
        let userInfo = UserInfo(
            id: tokenData.user.id,
            name: tokenData.user.name,
            imageURL: tokenData.user.avatar.flatMap { URL(string: $0) }
        )

        print("Connecting user to Stream Chat...")
        chatClient?.connectUser(
            userInfo: userInfo,
            token: Token(stringLiteral: tokenData.token)
        ) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Stream Chat connection error: \(error)")
                    self?.showError(error)
                } else {
                    print("Stream Chat connected successfully")
                    self?.setupChannelList()
                }
            }
        }
    }

    private func setupChannelList() {
        print("StreamChatViewController: setupChannelList called")
        guard let client = chatClient else {
            print("Chat client is nil, cannot setup channel list")
            return
        }

        // Create channel list query
        let query = ChannelListQuery(
            filter: .and([
                .equal(.type, to: .team),
                .containMembers(userIds: [userId])
            ])
        )
        print("Created channel list query for user: \(userId)")

        // Create channel list controller
        let channelList = client.channelListController(query: query)
        print("Created channel list controller")

        // Customize appearance - assign the type, not an instance
        Components.default.channelListRouter = ConduitChannelListRouter.self

        // Create channel list view controller
        let channelListVC = ChatChannelListVC()
        channelListVC.controller = channelList
        print("Created ChatChannelListVC")

        // Add as child view controller
        print("Adding channel list as child view controller")
        addChild(channelListVC)
        view.addSubview(channelListVC.view)
        channelListVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            channelListVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            channelListVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            channelListVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            channelListVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        channelListVC.didMove(toParent: self)

        self.channelListController = channelListVC

        // Hide loading (ensure we're on main thread)
        DispatchQueue.main.async { [weak self] in
            self?.hideLoading()
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

        // Create channel controller with the client
        let channelController = client.channelController(for: cid)

        // Create and configure channel view controller
        let channelVC = ChatChannelVC()
        channelVC.channelController = channelController

        // Push to navigation controller
        rootViewController.navigationController?.pushViewController(channelVC, animated: true)
    }
}