import UIKit
import StreamChat
import StreamChatUI

/// Minimal ChatChannelVC wrapper that tracks when user is viewing a channel
/// This is used to suppress push notifications for the currently viewed channel
class TrackingChannelVC: ChatChannelVC {

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
