import HotwireNative
import UIKit

/// A page's main action (e.g. Tasks' "Add") as a button in the top bar.
/// Tapping it replies to the page, which runs the web button's own action.
final class ButtonComponent: BridgeComponent {
    override nonisolated class var name: String { "button" }

    static func symbolName(for image: String?) -> String? {
        switch image {
        case "plus": "plus"
        case "more": "ellipsis.circle"
        default: nil
        }
    }

    override func onReceive(message: Message) {
        guard message.event == "connect", let data: MessageData = message.data() else { return }

        let action = UIAction { [weak self] _ in
            self?.reply(to: "connect")
        }
        let item: UIBarButtonItem
        if let symbol = Self.symbolName(for: data.image) {
            item = UIBarButtonItem(image: UIImage(systemName: symbol), primaryAction: action)
            item.accessibilityLabel = data.title
        } else {
            item = UIBarButtonItem(title: data.title, primaryAction: action)
        }
        viewController?.navigationItem.setRightBarItem(item, slot: .button)
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }
}

private extension ButtonComponent {
    struct MessageData: Decodable {
        let title: String
        let image: String?
    }
}
