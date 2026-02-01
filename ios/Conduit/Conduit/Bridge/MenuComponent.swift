import HotwireNative
import UIKit

final class MenuComponent: BridgeComponent {
    override nonisolated class var name: String { "menu" }

    override func onReceive(message: Message) {
        guard message.event == "display" else { return }
        handleDisplayEvent(message)
    }

    private var viewController: UIViewController? {
        delegate?.destination as? UIViewController
    }

    private func handleDisplayEvent(_ message: Message) {
        guard let data: MessageData = message.data() else { return }

        let alert = UIAlertController(
            title: data.title,
            message: nil,
            preferredStyle: .actionSheet
        )

        for item in data.items {
            let action = UIAlertAction(title: item.title, style: .default) { [weak self] _ in
                self?.reply(to: message.event, with: SelectionMessageData(selectedIndex: item.index))
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        viewController?.present(alert, animated: true)
    }
}

private extension MenuComponent {
    struct MessageData: Decodable {
        let title: String
        let items: [Item]
    }

    struct Item: Decodable {
        let title: String
        let index: Int
    }

    struct SelectionMessageData: Encodable {
        let selectedIndex: Int
    }
}
