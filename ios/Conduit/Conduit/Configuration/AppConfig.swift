import Foundation
import HotwireNative

enum AppConfig {
    // MARK: - Environment
    enum Environment {
        case development
        case production

        static var current: Environment {
            #if DEBUG
            return .development
            #else
            return .production
            #endif
        }
    }

    // MARK: - Communities API URL
    static let communitiesAPIURL = URL(string: "https://api.conduitcoho.app")!

    // MARK: - Base URL
    static var baseURL: URL {
        let url: URL

        switch Environment.current {
        case .development:
            // In Debug mode, always use localhost
            print("🔧 Debug mode: using localhost for development")
            url = URL(string: "http://localhost:3000")!

        case .production:
            // In production, always use the central API domain
            // The backend determines the tenant from the JWT token
            print("🏘️ Using central API URL: \(communitiesAPIURL.absoluteString)")
            url = communitiesAPIURL
        }

        print("🔗 AppConfig: Using base URL: \(url.absoluteString)")
        print("📱 Build Configuration: \(Environment.current == .development ? "Debug" : "Release")")
        return url
    }

    // MARK: - Load from Config.plist
    private static func loadProductionURLFromPlist() -> URL? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path),
              let urlString = config["ProductionURL"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    // MARK: - Other Configuration
    static var appName: String {
        return "Conduit"
    }

    /// The server knows the app by "Conduit iOS/2" and "Turbo Native"; the web
    /// bridge loads a component's controller only if it's listed here.
    static var userAgent: String {
        let components = AppDelegate.bridgeComponentTypes.map { $0.name }.joined(separator: " ")
        return "Conduit iOS/2 (Turbo Native) bridge-components: [\(components)]"
    }
}