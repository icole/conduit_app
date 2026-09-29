import Foundation

/// Links to Conduit pages in chat (like the Chores & Coverage "pick it up"
/// link to the Available queue) open in the app's own tabs, not Safari.
/// A link is Conduit's when it's on the app's server or the community's own
/// domain; either way the app opens its path on the app's server, where the
/// user is signed in. TabBarController does the opening.
enum ConduitLink {
    static let openNotification = Notification.Name("OpenConduitLink")

    enum Tab { case home, tasks, meals }

    /// A link waiting for the tabs to exist: a notification tapped while the
    /// app wasn't running arrives before TabBarController is set up.
    private static var pendingURL: URL?

    /// Opens a Conduit link in the app. False for any other link, which the
    /// caller should open as it normally would.
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard let appURL = appURL(for: url) else { return false }
        pendingURL = appURL
        NotificationCenter.default.post(name: openNotification, object: nil)
        return true
    }

    /// The link to open, handed out once (TabBarController).
    static func takePending() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
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
