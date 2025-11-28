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
        switch Environment.current {
        case .development:
            return URL(string: "http://localhost:3000")!
        case .production:
            // Try to load from Config.plist first (for local configuration)
            if let url = loadProductionURLFromPlist() {
                return url
            }
            // Fallback to compile-time URL if set
            #if PRODUCTION_URL
            return URL(string: PRODUCTION_URL)!
            #else
            // Default fallback - update this or use Config.plist
            return URL(string: "https://your-production-url.com")!
            #endif
        }
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