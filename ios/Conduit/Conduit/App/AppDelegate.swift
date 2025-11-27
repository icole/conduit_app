import UIKit
internal import WebKit
import HotwireNative

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Hotwire Native
        configureHotwireNative()

        return true
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
