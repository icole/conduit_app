import UIKit
import StreamChat
import StreamChatUI

/// Minimal ChatChannelVC wrapper that tracks when user is viewing a channel
/// This is used to suppress push notifications for the currently viewed channel
class TrackingChannelVC: ChatChannelVC {

    /// Adds a search button beside the channel avatar in the navigation bar.
    override func setUpLayout() {
        super.setUpLayout()

        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(searchThisChat)
        )
        searchButton.accessibilityLabel = "Search this chat"
        // The first item is rightmost, so the avatar stays at the edge
        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem, searchButton].compactMap { $0 }
    }

    @objc private func searchThisChat() {
        guard let controller = channelController, let cid = controller.cid else { return }

        let searchVC = ChannelMessageSearchVC(cid: cid, client: controller.client)
        searchVC.onSelect = { [weak self] messageId in
            // Loads the messages around it first if it's further back
            self?.jumpToMessage(id: messageId)
        }
        present(UINavigationController(rootViewController: searchVC), animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Notify ChatManager that user is viewing this channel
        if let cid = channelController?.cid {
            ChatManager.shared.setCurrentlyViewingChannel(cid: cid.description)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Notify ChatManager that user left this channel
        ChatManager.shared.setCurrentlyViewingChannel(cid: nil)
    }
}
