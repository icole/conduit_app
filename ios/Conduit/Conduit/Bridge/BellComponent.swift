import HotwireNative
import UIKit

/// The notification bell in the top bar (CON-72). Every page sends the count
/// of what needs the member; tapping replies, and the page opens Notifications.
/// It sits left of the page's own button (ButtonComponent).
final class BellComponent: BridgeComponent {
    override nonisolated class var name: String { "bell" }

    static func label(title: String, count: Int) -> String {
        switch count {
        case ...0: title
        case 1: "\(title), 1 needs you"
        default: "\(title), \(count) need you"
        }
    }

    static func badgeNumber(_ count: Int) -> Int? {
        count > 0 ? min(count, 99) : nil
    }

    override func onReceive(message: Message) {
        guard message.event == "connect", let data: MessageData = message.data(),
              let navigationItem = viewController?.navigationItem else { return }

        // Update the bell already in the bar: iOS 26 may not draw the badge of
        // a new button that replaces one that looks the same
        let existing = navigationItem.rightBarButtonItems?.first { $0.tag == RightBarSlot.bell.rawValue }
        let item = existing ?? UIBarButtonItem(image: UIImage(systemName: "bell"))
        item.primaryAction = UIAction(image: item.image) { [weak self] _ in
            self?.reply(to: "connect")
        }

        let count = data.count ?? 0
        let number = Self.badgeNumber(count)
        if #available(iOS 26.0, *) {
            item.badge = number.map { .count($0) }
        } else {
            item.image = UIImage(systemName: number == nil ? "bell" : "bell.badge")
        }
        item.accessibilityLabel = Self.label(title: data.title, count: count)

        if existing == nil {
            navigationItem.setRightBarItem(item, slot: .bell)
        }
    }

    /// Asks the page for the current count: something may have changed
    /// while this screen was covered by a sheet or out of sight
    func refresh() {
        reply(to: "connect", with: #"{"refresh":true}"#)
    }

    override func onViewWillAppear() {
        refresh()
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }
}

private extension BellComponent {
    struct MessageData: Decodable {
        let title: String
        let count: Int?
    }
}
