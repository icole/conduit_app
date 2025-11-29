import UIKit
import HotwireNative
internal import WebKit

class TabBarController: UITabBarController {

    // Callback for logout
    var onLogout: (() -> Void)?

    // Use centralized configuration for base URL
    private let baseURL = AppConfig.baseURL

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
        session.webView.customUserAgent = AppConfig.userAgent
        return session
    }()

    // Track if this is the first appearance
    private var hasInitiallyAppeared = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTabs()
        configureAppearance()
        self.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only load on first appearance after login
        if !hasInitiallyAppeared {
            hasInitiallyAppeared = true

            // Small delay to ensure cookies are fully synced with WebView
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                // Load the home tab now that authentication is ready
                if let homeNav = self.viewControllers?.first as? Navigator {
                    homeNav.route(self.baseURL)
                }
            }
        }
    }

    private func setupTabs() {
        // Home Tab - Main Rails app (delay initial load)
        let homeNavigator = createNavigator(
            for: baseURL,
            title: "Home",
            icon: UIImage(systemName: "house"),
            selectedIcon: UIImage(systemName: "house.fill"),
            delayInitialLoad: true
        )

        // Chat Tab - Rails chat page
        let chatURL = baseURL.appendingPathComponent("chat")
        let chatNavigator = createNavigator(
            for: chatURL,
            title: "Chat",
            icon: UIImage(systemName: "message"),
            selectedIcon: UIImage(systemName: "message.fill"),
            delayInitialLoad: false
        )

        // Profile Tab - Account settings with logout
        let profileURL = baseURL.appendingPathComponent("account")
        let profileNavigator = createProfileNavigator(
            for: profileURL,
            title: "Profile",
            icon: UIImage(systemName: "person.circle"),
            selectedIcon: UIImage(systemName: "person.circle.fill")
        )

        // Set view controllers
        viewControllers = [homeNavigator, chatNavigator, profileNavigator]
    }

    private func createNavigator(for url: URL, title: String, icon: UIImage?, selectedIcon: UIImage?, delayInitialLoad: Bool = false) -> UINavigationController {
        // Use the shared session for all navigators
        let navigator = Navigator(session: sharedSession)

        // Configure tab bar item
        navigator.tabBarItem = UITabBarItem(
            title: title,
            image: icon,
            selectedImage: selectedIcon
        )

        // Start navigation unless delayed
        if !delayInitialLoad {
            navigator.route(url)
        }

        return navigator
    }

    private func createProfileNavigator(for url: URL, title: String, icon: UIImage?, selectedIcon: UIImage?) -> UINavigationController {
        // Use the shared session for profile
        let navigator = Navigator(session: sharedSession)

        // Configure tab bar item
        navigator.tabBarItem = UITabBarItem(
            title: title,
            image: icon,
            selectedImage: selectedIcon
        )

        // Add logout button to navigation bar
        navigator.navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem(
            title: "Logout",
            style: .plain,
            target: self,
            action: #selector(logoutTapped)
        )

        // Start navigation
        navigator.route(url)

        // Set up the logout button after the view loads
        DispatchQueue.main.async {
            if let topVC = navigator.topViewController {
                topVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: "Logout",
                    style: .plain,
                    target: self,
                    action: #selector(self.logoutTapped)
                )
            }
        }

        return navigator
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })

        present(alert, animated: true)
    }

    private func performLogout() {
        // Call the logout callback which will trigger the SceneDelegate to show login
        onLogout?()
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

// MARK: - UITabBarControllerDelegate
extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if let selectedIndex = viewControllers?.firstIndex(of: viewController) {
            print("📊 TabBar: User tapped tab \(selectedIndex)")
        }
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let selectedIndex = viewControllers?.firstIndex(of: viewController) {
            print("✅ TabBar: Switched to tab \(selectedIndex)")

            // Log which tab was selected
            switch selectedIndex {
            case 0:
                print("  → Home tab selected")
            case 1:
                print("  → Chat tab selected")
            case 2:
                print("  → Profile tab selected")
            default:
                break
            }
        }
    }
}
