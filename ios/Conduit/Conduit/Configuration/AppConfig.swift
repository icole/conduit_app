import Foundation

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
        // Check for user-selected community URL first (for production)
        if Environment.current == .production,
           let communityURL = CommunityManager.shared.getCommunityURL() {
            print("🏘️ Using selected community URL: \(communityURL.absoluteString)")
            return communityURL
        }

        let url: URL

        // Check environment first - Debug always uses localhost
        switch Environment.current {
        case .development:
            // In Debug mode, always use localhost
            print("🔧 Debug mode: using localhost for development")
            url = URL(string: "http://localhost:3000")!

        case .production:
            // In Release mode, check for Config.plist
            if let configURL = loadProductionURLFromPlist() {
                print("📋 Found Config.plist with URL: \(configURL.absoluteString)")
                url = configURL
            } else {
                // Fallback to compile-time URL if set
                #if PRODUCTION_URL
                url = URL(string: PRODUCTION_URL)!
                #else
                // Default fallback - update this or use Config.plist
                print("⚠️ No Config.plist found and no PRODUCTION_URL set")
                url = URL(string: "https://your-production-url.com")!
                #endif
            }
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

    static var userAgent: String {
        return "Conduit iOS (Turbo Native)"
    }
}