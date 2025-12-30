import Foundation

/// Manages the selected community URL for multi-tenant support
class CommunityManager {
    static let shared = CommunityManager()

    private let communityURLKey = "conduit_community_url"
    private let communityNameKey = "conduit_community_name"

    private init() {}

    // MARK: - Community URL

    func getCommunityURL() -> URL? {
        guard let urlString = UserDefaults.standard.string(forKey: communityURLKey),
              let url = URL(string: urlString) else {
            return nil
        }
        return url
    }

    func setCommunityURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: communityURLKey)
    }

    func hasCommunityURL() -> Bool {
        return getCommunityURL() != nil
    }

    func clearCommunityURL() {
        UserDefaults.standard.removeObject(forKey: communityURLKey)
        UserDefaults.standard.removeObject(forKey: communityNameKey)
    }

    // MARK: - Community Name (for display)

    func getCommunityName() -> String? {
        return UserDefaults.standard.string(forKey: communityNameKey)
    }

    func setCommunityName(_ name: String) {
        UserDefaults.standard.set(name, forKey: communityNameKey)
    }
}
