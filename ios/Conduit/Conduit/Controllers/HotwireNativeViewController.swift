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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure proper navigation bar appearance
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
