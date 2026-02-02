import UIKit
import HotwireNative
internal import WebKit
import SafariServices

class Navigator: UINavigationController {
    let session: Session
    private var cachedStreamChatViewController: UIViewController?

    init(session: Session? = nil) {
        self.session = session ?? Session()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        self.session = Session()
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure navigation bar appearance
        navigationBar.prefersLargeTitles = false
        navigationBar.tintColor = .systemBlue

        // Configure session
        session.delegate = self

        // Configure web view
        session.webView.allowsLinkPreview = true
        session.webView.allowsBackForwardNavigationGestures = true

        // Handle authentication cookies
        configureWebView()
    }

    func route(_ url: URL) {
        let properties = session.pathConfiguration?.properties(for: url) ?? PathProperties()
        route(url: url, options: VisitOptions(), properties: properties)
    }

    private func route(url: URL, options: VisitOptions, properties: PathProperties) {
        let viewController = makeViewController(for: url, properties: properties)
        navigate(to: viewController, action: options.action, properties: properties)
        visit(viewController, with: options)
    }

    private func makeViewController(for url: URL, properties: PathProperties = PathProperties()) -> UIViewController {
        // Check if this is the chat page - use cached launcher or create new one
        if url.path.contains("/chat") {
            if let cachedVC = cachedStreamChatViewController {
                print("🔄 Navigator: Reusing cached StreamChatLauncherViewController")
                return cachedVC
            } else {
                print("🆕 Navigator: Creating new StreamChatLauncherViewController")
                let newVC = StreamChatLauncherViewController(url: url)
                cachedStreamChatViewController = newVC
                return newVC
            }
        }

        return HotwireNativeViewController(url: url)
    }

    private func navigate(to viewController: UIViewController, action: VisitAction, properties: PathProperties) {
        // Check if we're navigating to the cached Stream Chat view that's already visible
        if let cachedChat = cachedStreamChatViewController,
           viewController === cachedChat,
           viewControllers.contains(cachedChat) {
            print("📍 Navigator: Stream Chat already visible, skipping navigation")
            return
        }

        switch action {
        case .advance:
            pushViewController(viewController, animated: true)
        case .replace:
            let viewControllers = self.viewControllers.dropLast()
            setViewControllers(viewControllers + [viewController], animated: true)
        case .restore:
            let viewControllers = self.viewControllers.dropLast()
            setViewControllers(viewControllers + [viewController], animated: false)
        default:
            pushViewController(viewController, animated: true)
        }
    }

    private func visit(_ viewController: UIViewController, with options: VisitOptions = VisitOptions()) {
        // Only visit if the view controller is Visitable (skip for StreamChatLauncherViewController)
        guard let visitable = viewController as? Visitable else {
            print("Skipping session visit for non-Visitable controller: \(type(of: viewController))")
            return
        }
        session.visit(visitable, options: options)
    }

    private func configureWebView() {
        // Configure web view for authentication and Element compatibility
        let configuration = session.webView.configuration

        // Allow inline media playback (for potential future video chat)
        configuration.allowsInlineMediaPlayback = true

        // Allow picture in picture
        if #available(iOS 14.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = true
        }

        // User content controller is available via configuration.userContentController
        // if custom JavaScript messaging is needed for general app functionality
    }
}

// MARK: - SessionDelegate

extension Navigator: SessionDelegate {
    func session(_ session: Session, didProposeVisit proposal: VisitProposal) {
        route(url: proposal.url, options: proposal.options, properties: proposal.properties)
    }

    func session(_ session: Session, didProposeVisitToCrossOriginRedirect location: URL) {
        // Handle cross-origin redirects - by default, navigate to the new location
        route(location)
    }

    func session(_ session: Session, decidePolicyFor navigationAction: WKNavigationAction) -> WebViewPolicyManager.Decision {
        guard let url = navigationAction.request.url else {
            return .allow
        }

        // Check if this is an external URL that should open in Safari
        if isExternalURL(url) {
            openInSafariViewController(url)
            return .cancel
        }

        return .allow
    }

    private func isExternalURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // List of external domains that should open in Safari
        let externalDomains = [
            "docs.google.com",
            "drive.google.com",
            "sheets.google.com",
            "slides.google.com",
            "forms.google.com",
            "accounts.google.com"
        ]

        return externalDomains.contains { host.contains($0) }
    }

    private func openInSafariViewController(_ url: URL) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue

        // Present from the top-most view controller
        if let topVC = topViewController {
            topVC.present(safariVC, animated: true)
        } else {
            present(safariVC, animated: true)
        }
    }

    func session(_ session: Session, didFailRequestForVisitable visitable: Visitable, error: Error) {
        print("Session failed request: \(error)")

        // Handle authentication errors
        if (error as NSError).userInfo["NSURLErrorFailingURLPeerTrustErrorKey"] != nil {
            print("SSL/TLS error - this is expected in development with self-signed certificates")
        }

        // Show error to user
        let alert = UIAlertController(
            title: "Error Loading Page",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func sessionWebViewProcessDidTerminate(_ session: Session) {
        session.reload()
    }

    func session(_ session: Session, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle authentication challenges
        // For development with self-signed certificates
        #if DEBUG
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        #endif

        completionHandler(.performDefaultHandling, nil)
    }
}
