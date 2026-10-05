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
        guard message.event == "connect", let data: MessageData = message.data() else { return }

        let count = data.count ?? 0
        let number = Self.badgeNumber(count)
        let action = UIAction { [weak self] _ in
            self?.reply(to: "connect")
        }
        let item: UIBarButtonItem
        if #available(iOS 26.0, *) {
            item = UIBarButtonItem(image: UIImage(systemName: "bell"), primaryAction: action)
            item.badge = number.map { .count($0) }
        } else {
            item = UIBarButtonItem(image: UIImage(systemName: number == nil ? "bell" : "bell.badge"), primaryAction: action)
        }
        item.accessibilityLabel = Self.label(title: data.title, count: count)
        viewController?.navigationItem.setRightBarItem(item, slot: .bell)
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
