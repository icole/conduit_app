import UIKit

/// The top bar's right side holds the page's button and the bell, each set
/// by its own bridge component, so each replaces only its own item.
enum RightBarSlot: Int {
    // In order from the right edge
    case button = 1
    case bell = 2
}

extension UINavigationItem {
    func setRightBarItem(_ item: UIBarButtonItem, slot: RightBarSlot) {
        item.tag = slot.rawValue
        let others = (rightBarButtonItems ?? []).filter { $0.tag != slot.rawValue }
        rightBarButtonItems = (others + [item]).sorted { $0.tag < $1.tag }
    }
}
