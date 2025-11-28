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

    // MARK: - Base URL
    static var baseURL: URL {
        let url: URL

        // First, always try to load from Config.plist if it exists
        if let configURL = loadProductionURLFromPlist() {
            print("📋 Found Config.plist with URL: \(configURL.absoluteString)")
            url = configURL
        } else {
            // Fall back to environment-based URLs
            switch Environment.current {
            case .development:
                url = URL(string: "http://localhost:3000")!
            case .production:
                // Fallback to compile-time URL if set
                #if PRODUCTION_URL
                url = URL(string: PRODUCTION_URL)!
                #else
                // Default fallback - update this or use Config.plist
                url = URL(string: "https://your-production-url.com")!
                #endif
            }
        }

        print("🔗 AppConfig: Using base URL: \(url.absoluteString)")
        print("📱 Environment: \(Environment.current == .development ? "Development" : "Production")")
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