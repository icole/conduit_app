import UIKit
import StreamChat
import StreamChatUI

// Custom channel list item view that shows muted state
class CustomChannelListItemView: ChatChannelListItemView {

    // Mute indicator icon
    private lazy var muteIndicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "speaker.slash.fill")
        imageView.tintColor = .systemGray
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    override func setUpLayout() {
        super.setUpLayout()

        // Add mute indicator to the view
        mainContainer.addSubview(muteIndicatorView)

        // Position the mute indicator - top right corner of avatar
        NSLayoutConstraint.activate([
            muteIndicatorView.widthAnchor.constraint(equalToConstant: 20),
            muteIndicatorView.heightAnchor.constraint(equalToConstant: 20),
            muteIndicatorView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 5),
            muteIndicatorView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 5)
        ])
    }

    override func updateContent() {
        super.updateContent()

        // Show/hide mute indicator based on channel mute state
        if let content = content {
            let isMuted = content.channel.isMuted
            muteIndicatorView.isHidden = !isMuted

            // Optionally dim the channel name when muted
            if isMuted {
                titleLabel.alpha = 0.6
                subtitleLabel.alpha = 0.6
                // Add a background circle for better visibility
                muteIndicatorView.backgroundColor = .systemBackground
                muteIndicatorView.layer.cornerRadius = 10
                muteIndicatorView.layer.borderWidth = 1
                muteIndicatorView.layer.borderColor = UIColor.systemGray3.cgColor
            } else {
                titleLabel.alpha = 1.0
                subtitleLabel.alpha = 1.0
            }
        }
    }
}

// Alternative: Simpler approach with title prefix
class SimpleMutedChannelListItemView: ChatChannelListItemView {

    override func updateContent() {
        super.updateContent()

        // Add mute icon to channel name if muted
        if let content = content {
            let channel = content.channel

            if channel.isMuted {
                // Prepend mute emoji to the title
                let mutedPrefix = "🔇 "
                if let currentTitle = titleLabel.text,
                   !currentTitle.hasPrefix(mutedPrefix) {
                    titleLabel.text = mutedPrefix + currentTitle
                }

                // Dim the text
                titleLabel.alpha = 0.7
                subtitleLabel.alpha = 0.7

                // Change background color slightly
                mainContainer.backgroundColor = UIColor.systemGray6
            } else {
                // Reset to normal appearance
                titleLabel.alpha = 1.0
                subtitleLabel.alpha = 1.0
                mainContainer.backgroundColor = .clear

                // Remove mute prefix if it exists
                if let currentTitle = titleLabel.text,
                   currentTitle.hasPrefix("🔇 ") {
                    titleLabel.text = String(currentTitle.dropFirst(3)) // Drop emoji and space
                }
            }
        }
    }
}

// More sophisticated version with custom mute badge
class BadgedChannelListItemView: ChatChannelListItemView {

    private lazy var muteBadge: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray
        view.layer.cornerRadius = 12
        view.isHidden = true

        let iconView = UIImageView(image: UIImage(systemName: "speaker.slash.fill"))
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit

        view.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14)
        ])

        return view
    }()

    override func setUpLayout() {
        super.setUpLayout()

        // Add mute badge
        mainContainer.addSubview(muteBadge)

        // Position next to channel name
        NSLayoutConstraint.activate([
            muteBadge.widthAnchor.constraint(equalToConstant: 24),
            muteBadge.heightAnchor.constraint(equalToConstant: 24),
            muteBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            muteBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }

    override func updateContent() {
        super.updateContent()

        // Show/hide mute badge
        if let content = content {
            let isMuted = content.channel.isMuted
            muteBadge.isHidden = !isMuted

            // Apply muted styling
            if isMuted {
                // Slightly transparent
                mainContainer.alpha = 0.85

                // Different background tint
                let mutedOverlay = UIView()
                mutedOverlay.backgroundColor = UIColor.systemGray.withAlphaComponent(0.05)
                mutedOverlay.translatesAutoresizingMaskIntoConstraints = false
                mainContainer.insertSubview(mutedOverlay, at: 0)
                NSLayoutConstraint.activate([
                    mutedOverlay.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
                    mutedOverlay.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
                    mutedOverlay.topAnchor.constraint(equalTo: mainContainer.topAnchor),
                    mutedOverlay.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor)
                ])
            } else {
                mainContainer.alpha = 1.0
            }
        }
    }
}