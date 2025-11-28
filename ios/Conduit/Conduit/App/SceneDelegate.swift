import UIKit
import HotwireNative

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var tabBarController: TabBarController?
    var loginNavigationController: UINavigationController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Create window
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // Check authentication status and show appropriate screen
        if AuthenticationManager.shared.isAuthenticated() {
            // User might be authenticated, verify with server
            showLoadingScreen()
            AuthenticationManager.shared.checkAuthenticationStatus { [weak self] authenticated in
                if authenticated {
                    self?.showMainApp()
                } else {
                    // Session expired or invalid
                    AuthenticationManager.shared.logout()
                    self?.showLoginScreen()
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

    private func showLoginScreen() {
        let loginVC = LoginViewController()
        loginVC.onLoginSuccess = { [weak self] in
            // Sync cookies and show main app
            AuthenticationManager.shared.syncCookiesToWebView {
                self?.showMainApp()
            }
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
            AuthenticationManager.shared.logout()
            self?.showLoginScreen()
        }

        // Animate transition if window already has a root view controller
        if window?.rootViewController != nil {
            UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve) {
                self.window?.rootViewController = tabBarController
            }
        } else {
            window?.rootViewController = tabBarController
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
