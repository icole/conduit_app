import UIKit
import HotwireNative
internal import WebKit

class HotwireNativeViewController: VisitableViewController, BridgeDestination {

    private lazy var bridgeDelegate = BridgeDelegate(
        location: currentVisitableURL.absoluteString,
        destination: self,
        componentTypes: AppDelegate.bridgeComponentTypes
    )

    /// Freshens the top bar's bell: a sheet over this screen closed, which
    /// doesn't count as the screen appearing again
    func refreshBell() {
        (bridgeDelegate.component() as BellComponent?)?.refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.standardAppearance = Palette.webBar
        navigationItem.scrollEdgeAppearance = Palette.webBar
        navigationItem.compactAppearance = Palette.webBar

        visitableView.allowsPullToRefresh = true

        bridgeDelegate.onViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bridgeDelegate.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bridgeDelegate.onViewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bridgeDelegate.onViewWillDisappear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        bridgeDelegate.onViewDidDisappear()
    }

    // MARK: - Visitable

    override func visitableDidActivateWebView(_ webView: WKWebView) {
        super.visitableDidActivateWebView(webView)
        Bridge.initialize(webView)
        bridgeDelegate.webViewDidBecomeActive(webView)
    }

    override func visitableDidDeactivateWebView() {
        super.visitableDidDeactivateWebView()
        bridgeDelegate.webViewDidBecomeDeactivated()
    }

    // Note: Error handling is done at the SessionDelegate level in Navigator
    // If you need custom error handling per view controller, you can add methods
    // that Navigator can call

    // Helper method to reload the current page
    func reload() {
        let url = currentVisitableURL
        visit(url: url)
    }

    // Helper method to visit a new URL
    func visit(url: URL) {
        (navigationController as? Navigator)?.route(url)
    }
}
