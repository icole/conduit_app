import SwiftUI
import HotwireNative

// Minimal iOS app to wrap the HOA Chat with Hotwire Native
struct ContentView: View {
    @State private var navigator = Navigator()

    var body: some View {
        NavigatorView(navigator: navigator)
            .onAppear {
                // Load the chat page directly
                // For local testing, use: http://localhost:3000/chat
                // For production, use: https://your-domain.com/chat
                navigator.route(to: URL(string: "http://localhost:3000/chat")!)
            }
    }
}

// App configuration
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)

        // Configure Hotwire Native
        Hotwire.config.userAgent = "HOA Chat iOS (Turbo Native)"
        Hotwire.config.pathConfiguration = PathConfiguration(sources: [
            // You can add path configuration here if needed
        ])

        window.rootViewController = UIHostingController(rootView: ContentView())
        self.window = window
        window.makeKeyAndVisible()
    }
}