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
            let action = UIAlertAction(title: item.title, style: item.destructive == true ? .destructive : .default) { [weak self] _ in
                self?.reply(to: message.event, with: SelectionMessageData(selectedIndex: item.index))
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        guard let viewController else { return }
        // On iPad an action sheet is a popover and must be anchored, or it crashes
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        viewController.present(alert, animated: true)
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
        let destructive: Bool?
    }

    struct SelectionMessageData: Encodable {
        let selectedIndex: Int
    }
}
