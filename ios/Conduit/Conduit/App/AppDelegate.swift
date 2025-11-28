import UIKit
internal import WebKit
import HotwireNative
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire Native
        configureHotwireNative()

        // Restore Google Sign-In previous session if available
        // Note: This will fail with error -4 if no previous session or URL scheme not configured
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error = error {
                let nsError = error as NSError
                if nsError.code == -4 {
                    // Expected error when no previous session exists or URL scheme missing
                    print("No previous Google Sign-In session to restore (this is normal on first launch)")
                } else {
                    print("Error restoring Google Sign-In: \(error.localizedDescription)")
                }
            } else if let user = user {
                print("Google Sign-In restored for user: \(user.profile?.email ?? "")")
            }
        }

        return true
    }

    // MARK: - Google Sign-In

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    private func configureHotwireNative() {
        // Configure custom web view with user agent
        Hotwire.config.makeCustomWebView = { (configuration: WKWebViewConfiguration) -> WKWebView in
            // Use different user agents for different purposes
            // Rails pages need "Turbo Native", Element needs desktop Safari
            configuration.applicationNameForUserAgent = "Conduit iOS (Turbo Native)"

            let webView = WKWebView(frame: .zero, configuration: configuration)

            // We'll override this per-page for Element
            return webView
        }

        // Configure path configuration if needed
        // This can be extended to load remote configuration
    }
}
