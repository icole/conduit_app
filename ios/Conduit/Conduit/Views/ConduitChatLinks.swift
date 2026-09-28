import UIKit
import StreamChat
import StreamChatUI

/// A message bubble whose Conduit links (ConduitLink) open in the app's tabs
/// instead of Safari. Other links, and mentions, behave as Stream's do.
final class ConduitMessageContentView: ChatMessageContentView {
    override func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        if interaction == .invokeDefaultAction, ConduitLink.open(URL) {
            return false
        }
        return super.textView(textView, shouldInteractWith: URL, in: characterRange, interaction: interaction)
    }
}

/// Stream's message list navigation, except a tapped link preview card for a
/// Conduit page opens in the app too.
final class ConduitMessageListRouter: ChatMessageListRouter {
    @available(iOSApplicationExtension, unavailable)
    override func showLinkPreview(link: URL) {
        if ConduitLink.open(link) { return }
        super.showLinkPreview(link: link)
    }
}
