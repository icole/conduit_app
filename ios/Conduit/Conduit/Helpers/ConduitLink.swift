import Foundation

/// Links to Conduit pages in chat (like the Chores & Coverage "pick it up"
/// link to the Available queue) open in the app's own tabs, not Safari.
/// A link is Conduit's when it's on the app's server or the community's own
/// domain; either way the app opens its path on the app's server, where the
/// user is signed in. TabBarController does the opening.
enum ConduitLink {
    static let openNotification = Notification.Name("OpenConduitLink")

    enum Tab { case home, tasks, meals }

    /// Opens a Conduit link in the app. False for any other link, which the
    /// caller should open as it normally would.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard let appURL = appURL(for: url) else { return false }
        NotificationCenter.default.post(name: openNotification, object: nil, userInfo: ["url": appURL])
        return true
    }

    /// The same page on the app's server, or nil if it isn't a Conduit link.
    static func appURL(for url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host?.lowercased() else { return nil }

        let community = CommunityManager.shared
        let ours = [AppConfig.baseURL.host, community.getCommunityURL()?.host, community.getCommunityDomain()]
            .compactMap { $0?.lowercased() }
        guard ours.contains(host) else { return nil }

        var components = URLComponents(url: AppConfig.baseURL, resolvingAgainstBaseURL: false)
        components?.path = url.path.isEmpty ? "/" : url.path
        components?.percentEncodedQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        return components?.url
    }

    static func tab(for path: String) -> Tab {
        func isUnder(_ section: String) -> Bool { path == section || path.hasPrefix(section + "/") }

        if isUnder("/tasks") || isUnder("/workstreams") { return .tasks }
        if isUnder("/meals") { return .meals }
        return .home
    }
}
