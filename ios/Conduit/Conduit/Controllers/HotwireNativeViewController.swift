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
        // Check if this is the Home tab
        let isHomeTab = tabBarController?.selectedIndex == 0

        // Ensure the web view respects safe area layout guides
        if let webView = visitableView.webView {
            // Make the scroll view adjust for safe areas automatically
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic

            // Ensure the web view doesn't go under the bars
            webView.scrollView.scrollIndicatorInsets = webView.scrollView.safeAreaInsets
        }

        if isHomeTab {
            // Home tab: Allow content to extend to top but respect safe area
            edgesForExtendedLayout = .top
            extendedLayoutIncludesOpaqueBars = true
        } else {
            // Other tabs: Don't extend under navigation bar
            edgesForExtendedLayout = []
            extendedLayoutIncludesOpaqueBars = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Hide navigation bar for Home tab (index 0), show for others
        if let tabBarController = tabBarController,
           tabBarController.selectedIndex == 0 {
            // Home tab - hide navigation bar for more screen space
            navigationController?.setNavigationBarHidden(true, animated: animated)
        } else {
            // Other tabs - show navigation bar if needed
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }

        // Re-apply layout configuration when view appears
        configureWebViewLayout()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Reset navigation bar when leaving this view
        navigationController?.setNavigationBarHidden(false, animated: false)
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
