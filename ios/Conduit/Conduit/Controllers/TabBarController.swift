import UIKit
import HotwireNative
internal import WebKit

class TabBarController: UITabBarController {

    // Define base URLs - adjust for production
    #if DEBUG
    private let baseURL = URL(string: "http://localhost:3000")!
    #else
    private let baseURL = URL(string: "https://your-production-url.com")!
    #endif

    // Shared configuration for all tabs to maintain authentication state
    private lazy var sharedWebViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        configuration.websiteDataStore = .default()  // Share cookies/session
        return configuration
    }()

    // Shared session for all tabs
    private lazy var sharedSession: Session = {
        let session = Session(webViewConfiguration: sharedWebViewConfiguration)
        session.webView.customUserAgent = "Conduit iOS (Turbo Native)"
        return session
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTabs()
        configureAppearance()
    }

    private func setupTabs() {
        // Home Tab - Main Rails app
        let homeNavigator = createNavigator(
            for: baseURL,
            title: "Home",
            icon: UIImage(systemName: "house"),
            selectedIcon: UIImage(systemName: "house.fill")
        )

        // Chat Tab - Rails chat page
        let chatURL = baseURL.appendingPathComponent("chat")
        let chatNavigator = createNavigator(
            for: chatURL,
            title: "Chat",
            icon: UIImage(systemName: "message"),
            selectedIcon: UIImage(systemName: "message.fill")
        )

        // Set view controllers
        viewControllers = [homeNavigator, chatNavigator]
    }

    private func createNavigator(for url: URL, title: String, icon: UIImage?, selectedIcon: UIImage?) -> UINavigationController {
        // Use the shared session for all navigators
        let navigator = Navigator(session: sharedSession)

        // Configure tab bar item
        navigator.tabBarItem = UITabBarItem(
            title: title,
            image: icon,
            selectedImage: selectedIcon
        )

        // Start navigation
        navigator.route(url)

        return navigator
    }

    private func configureAppearance() {
        // Configure tab bar appearance
        tabBar.backgroundColor = .systemBackground
        tabBar.tintColor = .systemBlue

        // Configure tab bar for iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground

            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
