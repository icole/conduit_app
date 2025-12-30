import UIKit
import HotwireNative
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var tabBarController: TabBarController?
    var loginNavigationController: UINavigationController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Create window
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Check if community is selected first
        if !CommunityManager.shared.hasCommunityURL() {
            showCommunitySelectScreen()
            window.makeKeyAndVisible()
            return
        }

        // Check authentication status and show appropriate screen
        if AuthenticationManager.shared.isAuthenticated() {
            // User might be authenticated, verify with server
            showLoadingScreen()

            // Sync cookies to WebView first, then verify
            AuthenticationManager.shared.syncCookiesToWebView {
                AuthenticationManager.shared.checkAuthenticationStatus { [weak self] authenticated in
                    if authenticated {
                        self?.showMainApp()
                    } else {
                        // Session expired or invalid
                        AuthenticationManager.shared.logout()
                        self?.showLoginScreen()
                    }
                }
            }
        } else {
            // Not authenticated, show login
            showLoginScreen()
        }

        window.makeKeyAndVisible()
    }

    private func showLoadingScreen() {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        loadingVC.view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: loadingVC.view.centerYAnchor)
        ])

        window?.rootViewController = loadingVC
    }

    private func showCommunitySelectScreen() {
        let communitySelectVC = CommunitySelectViewController()
        communitySelectVC.onCommunitySelected = { [weak self] in
            // After community selected, proceed to login
            self?.showLoginScreen()
        }

        let navController = UINavigationController(rootViewController: communitySelectVC)

        // Animate transition if window already has a root view controller
        if window?.rootViewController != nil {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = navController
            }
        } else {
            window?.rootViewController = navController
        }
    }

    private func showLoginScreen() {
        let loginVC = LoginViewController()
        loginVC.onLoginSuccess = { [weak self] in
            // Sync cookies and show main app
            AuthenticationManager.shared.syncCookiesToWebView {
                self?.showMainApp()
            }
        }
        loginVC.onSwitchCommunity = { [weak self] in
            // Go back to community selector
            self?.showCommunitySelectScreen()
        }

        let navController = UINavigationController(rootViewController: loginVC)
        self.loginNavigationController = navController

        // Animate transition if window already has a root view controller
        if window?.rootViewController != nil {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = navController
            }
        } else {
            window?.rootViewController = navController
        }
    }

    private func showMainApp() {
        // Create and configure tab bar controller
        let tabBarController = TabBarController()
        self.tabBarController = tabBarController

        // Add logout handler
        tabBarController.onLogout = { [weak self] in
            // Disconnect Stream Chat before logging out
            ChatManager.shared.disconnect()
            // Use async logout to ensure all data is cleared before showing login
            AuthenticationManager.shared.logout {
                self?.showLoginScreen()
            }
        }

        // Add switch community handler (clears community and shows selector)
        tabBarController.onSwitchCommunity = { [weak self] in
            ChatManager.shared.disconnect()
            // Use async logout to ensure all data is cleared before showing selector
            AuthenticationManager.shared.logout {
                CommunityManager.shared.clearCommunityURL()
                self?.showCommunitySelectScreen()
            }
        }

        // Setup notification observer for push notification taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openChatTab),
            name: Notification.Name("OpenChatTab"),
            object: nil
        )

        // Animate transition if window already has a root view controller
        if window?.rootViewController != nil {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = tabBarController
            }
        } else {
            window?.rootViewController = tabBarController
        }
    }

    @objc private func openChatTab() {
        // Switch to chat tab (index 1)
        tabBarController?.selectedIndex = 1
    }

    // MARK: - URL Handling for Google Sign-In

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("SceneDelegate: Handling URL: \(url)")

        // Handle Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) {
            print("SceneDelegate: URL handled by Google Sign-In")
            return
        }

        print("SceneDelegate: URL not handled")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Clear badge count when app becomes active
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("Error clearing badge count: \(error.localizedDescription)")
            }
        }

        // Also clear any delivered notifications from notification center
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
