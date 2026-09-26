import UIKit
import HotwireNative
internal import WebKit
import SafariServices

/// One tab's navigation stack. Mirrors the parts of Hotwire Native's own
/// `Navigator` this app relies on:
/// - paths with `"context": "modal"` in path-configuration.json (new/edit
///   forms) open as a sheet with their own web view (`modalSession`), so the
///   page underneath keeps its state;
/// - when a modal leads to a page that isn't a modal (a form saved, or a
///   Cancel link), the sheet closes and that page shows in the main stack,
///   refreshed in place if it's the page that was underneath;
/// - the web page's alert()/confirm() dialogs are shown natively
///   (Hotwire's `WKUIController`). Without it every data-turbo-confirm
///   silently answered "Cancel".
class Navigator: UINavigationController {
    let session: Session
    let modalSession: Session
    private let modalNavigationController = UINavigationController()
    private let dialogPresenter = WebDialogPresenter()
    private lazy var webDialogs = WKUIController(delegate: dialogPresenter)
    private var cachedStreamChatViewController: UIViewController?

    init(session: Session? = nil) {
        let session = session ?? Session()
        self.session = session
        self.modalSession = Navigator.makeModalSession(matching: session)
        super.init(nibName: nil, bundle: nil)
        configureSessions()
    }

    required init?(coder aDecoder: NSCoder) {
        let session = Session()
        self.session = session
        self.modalSession = Navigator.makeModalSession(matching: session)
        super.init(coder: aDecoder)
        configureSessions()
    }

    /// A second web view sharing the tab's cookies and user agent.
    private static func makeModalSession(matching session: Session) -> Session {
        let modalSession = Session(webViewConfiguration: session.webView.configuration)
        modalSession.webView.customUserAgent = session.webView.customUserAgent
        return modalSession
    }

    private func configureSessions() {
        dialogPresenter.navigator = self
        for tabSession in [session, modalSession] {
            tabSession.delegate = self
            // Without this, proposals carry no path properties and nothing
            // ever opens as a modal.
            tabSession.pathConfiguration = Hotwire.config.pathConfiguration
            tabSession.webView.uiDelegate = webDialogs
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure navigation bar appearance
        navigationBar.prefersLargeTitles = false
        navigationBar.tintColor = .systemBlue

        // Web screens hide the navigation bar, which also turns off the
        // edge-swipe back gesture; turn it back on.
        interactivePopGestureRecognizer?.delegate = self

        // Configure web view
        session.webView.allowsLinkPreview = true
        session.webView.allowsBackForwardNavigationGestures = true

        configureWebView()
    }

    func route(_ url: URL) {
        let properties = session.pathConfiguration?.properties(for: url) ?? PathProperties()
        route(url: url, options: VisitOptions(), properties: properties)
    }

    private func route(url: URL, options: VisitOptions, properties: PathProperties) {
        let viewController = makeViewController(for: url, properties: properties)

        if properties.context == .modal && viewController is Visitable {
            presentModally(viewController, options: options)
        } else {
            showInMainStack(viewController, url: url, options: options)
        }
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

    // MARK: - Modal context

    private var isShowingModal: Bool {
        presentedViewController === modalNavigationController && !modalNavigationController.isBeingDismissed
    }

    private func presentModally(_ viewController: UIViewController, options: VisitOptions) {
        visit(viewController, on: modalSession, options: options)

        if isShowingModal {
            modalNavigationController.pushViewController(viewController, animated: true)
        } else {
            modalNavigationController.setViewControllers([viewController], animated: false)
            modalNavigationController.modalPresentationStyle = .pageSheet
            present(modalNavigationController, animated: true)
        }
    }

    // MARK: - Main stack

    private func showInMainStack(_ viewController: UIViewController, url: URL, options: VisitOptions) {
        // Leaving a modal: a form was saved or its Cancel link was tapped.
        let leavingModal = isShowingModal
        if leavingModal {
            dismiss(animated: true)
        }

        // Check if we're navigating to the cached Stream Chat view that's already visible
        if let cachedChat = cachedStreamChatViewController,
           viewController === cachedChat,
           viewControllers.contains(cachedChat) {
            print("📍 Navigator: Stream Chat already visible, skipping navigation")
            return
        }

        visit(viewController, on: session, options: options)

        if isSamePageAsTop(url) {
            // e.g. a form under this page redirected back to it: show it fresh
            replaceTop(with: viewController, animated: false)
        } else if options.action == .restore {
            replaceTop(with: viewController, animated: false)
        } else if options.action == .replace && !leavingModal {
            replaceTop(with: viewController, animated: true)
        } else {
            pushViewController(viewController, animated: true)
        }
    }

    private func isSamePageAsTop(_ url: URL) -> Bool {
        guard let top = topViewController as? Visitable else { return false }
        let current = top.currentVisitableURL
        return current.path == url.path && current.query == url.query
    }

    private func replaceTop(with viewController: UIViewController, animated: Bool) {
        setViewControllers(Array(viewControllers.dropLast()) + [viewController], animated: animated)
    }

    private func visit(_ viewController: UIViewController, on session: Session, options: VisitOptions) {
        // Only visit if the view controller is Visitable (skip for StreamChatLauncherViewController)
        guard let visitable = viewController as? Visitable else {
            print("Skipping session visit for non-Visitable controller: \(type(of: viewController))")
            return
        }
        session.visit(visitable, options: options)
    }

    /// Whatever is on top: the modal sheet if one is showing, else this stack.
    fileprivate var topPresenter: UIViewController {
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        return presenter
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

// MARK: - UIGestureRecognizerDelegate

extension Navigator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only swipe back when there's somewhere to go back to
        gestureRecognizer !== interactivePopGestureRecognizer || viewControllers.count > 1
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

    func sessionDidFinishFormSubmission(_ session: Session) {
        // A form in the sheet may have changed what the page underneath shows
        if session === modalSession {
            self.session.markSnapshotCacheAsStale()
        }
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
        topPresenter.present(safariVC, animated: true)
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
        topPresenter.present(alert, animated: true)
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

// MARK: - Web page dialogs

/// Shows the web page's alert()/confirm() (via Hotwire's `WKUIController`) on
/// top of whatever is showing. A separate object because
/// `WKUIControllerDelegate.present(_:animated:)` would clash with
/// `UIViewController.present(_:animated:completion:)` on the Navigator.
final class WebDialogPresenter: WKUIControllerDelegate {
    weak var navigator: Navigator?

    func present(_ alert: UIAlertController, animated: Bool) {
        navigator?.topPresenter.present(alert, animated: animated)
    }
}
