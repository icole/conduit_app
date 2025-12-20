import UIKit
import HotwireNative
internal import WebKit

class TabBarController: UITabBarController {

    // Callback for logout
    var onLogout: (() -> Void)?

    // Use centralized configuration for base URL
    private let baseURL = AppConfig.baseURL

    // Shared website data store to maintain authentication state across tabs
    private let sharedWebsiteDataStore = WKWebsiteDataStore.default()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTabs()
        configureAppearance()
        self.delegate = self
    }

    private func setupTabs() {
        // Home Tab - Main Rails app
        let homeNavigator = createNavigator(
            for: baseURL,
            title: "Home",
            icon: UIImage(systemName: "house"),
            selectedIcon: UIImage(systemName: "house.fill")
        )

        // Tasks Tab - Tasks page
        let tasksURL = baseURL.appendingPathComponent("tasks")
        let tasksNavigator = createNavigator(
            for: tasksURL,
            title: "Tasks",
            icon: UIImage(systemName: "checklist"),
            selectedIcon: UIImage(systemName: "checklist")
        )

        // Meals Tab - Meals page
        let mealsURL = baseURL.appendingPathComponent("meals")
        let mealsNavigator = createNavigator(
            for: mealsURL,
            title: "Meals",
            icon: UIImage(systemName: "fork.knife"),
            selectedIcon: UIImage(systemName: "fork.knife")
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
        viewControllers = [homeNavigator, tasksNavigator, mealsNavigator, chatNavigator]
    }

    private func createNavigator(for url: URL, title: String, icon: UIImage?, selectedIcon: UIImage?) -> UINavigationController {
        // Create a new configuration for each tab, but share the website data store for cookies
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = sharedWebsiteDataStore  // Share cookies/session

        // Create a new session for each navigator with its own configuration
        let session = Session(webViewConfiguration: configuration)
        session.webView.customUserAgent = AppConfig.userAgent
        let navigator = Navigator(session: session)

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

    // Logout can be triggered from the web interface or via other means
    // Keeping the logout functionality but removing the dedicated profile tab

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
                print("  → Tasks tab selected")
            case 2:
                print("  → Meals tab selected")
            case 3:
                print("  → Chat tab selected")
            default:
                break
            }
        }
    }
}
