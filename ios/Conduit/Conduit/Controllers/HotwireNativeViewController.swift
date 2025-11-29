import UIKit
import HotwireNative
internal import WebKit

class HotwireNativeViewController: VisitableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure navigation item
        navigationItem.backButtonDisplayMode = .minimal

        // Configure pull to refresh
        visitableView.allowsPullToRefresh = true

        // Fix content bleeding behind bars by respecting safe areas
        configureWebViewLayout()
    }

    private func configureWebViewLayout() {
        // Ensure the web view respects safe area layout guides
        if let webView = visitableView.webView {
            // Make the scroll view adjust for safe areas automatically
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic

            // Ensure the web view doesn't go under the bars
            webView.scrollView.scrollIndicatorInsets = webView.scrollView.safeAreaInsets
        }

        // Set edges for extended layout to avoid content under bars
        edgesForExtendedLayout = []

        // Ensure the view controller's view respects safe areas
        extendedLayoutIncludesOpaqueBars = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure proper navigation bar appearance
        navigationController?.setNavigationBarHidden(false, animated: false)

        // Re-apply layout configuration when view appears
        configureWebViewLayout()
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
