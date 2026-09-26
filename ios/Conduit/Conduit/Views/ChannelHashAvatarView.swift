import UIKit
import StreamChat
import StreamChatUI

/// Channel avatar that shows a "#" instead of Stream's collage of member
/// photos. Every channel holds the whole community, so the collage looked the
/// same everywhere and only added clutter; the web chat lists channels as
/// "# name" too. A channel that has its own image still shows it.
final class ChannelHashAvatarView: ChatChannelAvatarView {
    override func loadAvatar(for channel: ChatChannel) {
        if channel.imageURL != nil {
            super.loadAvatar(for: channel)
            return
        }

        presenceAvatarView.isOnlineIndicatorVisible = false
        loadIntoAvatarImageView(from: nil, placeholder: Self.hashImage(for: traitCollection))
    }

    // Drawn with resolved colors; Stream's base view calls updateContent()
    // again when the app switches between light and dark mode.
    private static func hashImage(for traits: UITraitCollection) -> UIImage {
        let size = CGSize(width: 40, height: 40)
        let background = UIColor.systemGray5.resolvedColor(with: traits)
        let glyphColor = UIColor.secondaryLabel.resolvedColor(with: traits)
        let glyph = UIImage(
            systemName: "number",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        )?.withTintColor(glyphColor, renderingMode: .alwaysOriginal)

        return UIGraphicsImageRenderer(size: size).image { _ in
            background.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            if let glyph = glyph {
                let origin = CGPoint(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2)
                glyph.draw(at: origin)
            }
        }
    }
}
