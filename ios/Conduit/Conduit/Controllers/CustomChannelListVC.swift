import UIKit
import StreamChat
import StreamChatUI

class CustomChannelListVC: ChatChannelListVC {

    // Community slug for channel creation - set by parent view controller
    var communitySlug: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Note: When used as a child view controller (as in StreamChatViewController),
        // the parent controls the navigation bar. The plus button is added by the parent.

        // Configure swipe actions for channels
        configureSwipeActions()

        // Add muted channel indicators
        configureMutedChannelIndicators()
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Get the selected channel
        guard indexPath.row < controller?.channels.count ?? 0,
              let channel = controller?.channels[indexPath.row],
              let currentUserId = controller?.client.currentUserId else {
            super.collectionView(collectionView, didSelectItemAt: indexPath)
            return
        }

        // Check if user is a member
        let isMember = channel.lastActiveMembers.contains { $0.id == currentUserId }

        if !isMember {
            // Auto-join the channel before opening
            print("User not a member, auto-joining channel...")
            let channelController = controller!.client.channelController(for: channel.cid)

            channelController.addMembers(userIds: [currentUserId]) { [weak self] error in
                if let error = error {
                    print("Failed to join channel: \(error)")
                } else {
                    print("Successfully joined channel")
                }

                // Open the channel after attempting to join
                self?.openChannel(at: indexPath)
            }
        } else {
            // Already a member, just open
            super.collectionView(collectionView, didSelectItemAt: indexPath)
        }
    }

    private func openChannel(at indexPath: IndexPath) {
        // Manually trigger the default selection behavior
        super.collectionView(collectionView, didSelectItemAt: indexPath)
    }

    override func controller(_ controller: ChatChannelListController, didChangeChannels changes: [ListChange<ChatChannel>]) {
        super.controller(controller, didChangeChannels: changes)

        // Update muted indicators when channels change
        updateMutedChannelIndicators()
    }

    private func configureMutedChannelIndicators() {
        // Update channel appearances on initial load without delay
        updateMutedChannelIndicators()
    }

    private func updateMutedChannelIndicators() {
        // Add muted emoji to channel names
        guard let channels = controller?.channels else { return }

        // Find the collection view cells and update them
        if let collectionView = self.view.subviews.first(where: { $0 is UICollectionView }) as? UICollectionView {
            for (index, channel) in channels.enumerated() {
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = collectionView.cellForItem(at: indexPath) {
                    // Find the title label in the cell and update it
                    updateCellForMutedState(cell: cell, channel: channel)
                }
            }
        }
    }

    private func updateCellForMutedState(cell: UICollectionViewCell, channel: ChatChannel) {
        // Find labels in the cell hierarchy
        let labels = findLabels(in: cell)

        if channel.isMuted {
            // Add mute indicator and dim the cell
            cell.alpha = 0.7
            cell.contentView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.3)

            // Add mute emoji to the first label (channel name)
            if let titleLabel = labels.first,
               let text = titleLabel.text,
               !text.hasPrefix("🔇") {
                titleLabel.text = "🔇 \(text)"
            }
        } else {
            // Remove mute indicator and restore normal appearance
            cell.alpha = 1.0
            cell.contentView.backgroundColor = .clear

            // Remove mute emoji if present
            if let titleLabel = labels.first,
               let text = titleLabel.text,
               text.hasPrefix("🔇") {
                titleLabel.text = String(text.dropFirst(3))
            }
        }
    }

    private func findLabels(in view: UIView) -> [UILabel] {
        var labels: [UILabel] = []
        if let label = view as? UILabel {
            labels.append(label)
        }
        for subview in view.subviews {
            labels.append(contentsOf: findLabels(in: subview))
        }
        return labels
    }

    private func configureSwipeActions() {
        // Add long press gesture recognizer for channel options
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPressGesture)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: self.view)

        // Find which channel was long-pressed
        // Stream Chat UI uses a collection view internally
        if let collectionView = self.view.subviews.first(where: { $0 is UICollectionView }) as? UICollectionView,
           let indexPath = collectionView.indexPathForItem(at: collectionView.convert(point, from: self.view)),
           indexPath.row < controller?.channels.count ?? 0,
           let channel = controller?.channels[indexPath.row] {
            showChannelOptionsMenu(for: channel)
        }
    }

    @objc func createChannelTapped() {
        showChannelCreationDialog()
    }

    private func showChannelCreationDialog() {
        let alert = UIAlertController(
            title: "Create New Channel",
            message: "Enter a name for the new channel",
            preferredStyle: .alert
        )

        // Add text field for channel name
        alert.addTextField { textField in
            textField.placeholder = "Channel name"
            textField.autocapitalizationType = .words
        }

        // Add text field for channel description (optional)
        alert.addTextField { textField in
            textField.placeholder = "Description (optional)"
            textField.autocapitalizationType = .sentences
        }

        // Create action
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let channelName = alert.textFields?.first?.text,
                  !channelName.isEmpty else {
                self?.showError("Channel name is required")
                return
            }

            let description = alert.textFields?[1].text
            self?.createChannel(name: channelName, description: description)
        }

        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(createAction)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }

    private func createChannel(name: String, description: String?) {
        guard let client = controller?.client else {
            showError("Chat client not available")
            return
        }

        // Generate a channel ID from the name (lowercase, replace spaces with hyphens)
        let channelId = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        // Ensure channel ID is not empty and add timestamp to make it unique
        let timestamp = Int(Date().timeIntervalSince1970)
        let finalChannelId = channelId.isEmpty ? "channel-\(timestamp)" : "\(channelId)-\(timestamp)"

        // Create the channel with description in extraData if provided
        let channelController: ChatChannelController
        var extraData: [String: RawJSON] = [:]
        if let description = description, !description.isEmpty {
            extraData["description"] = .string(description)
        }

        // Make the channel public by setting it as open for all members
        extraData["public"] = .bool(true)
        extraData["open"] = .bool(true)  // Allow anyone to join

        // Add community_slug so the channel appears in community-filtered lists
        if let communitySlug = communitySlug {
            extraData["community_slug"] = .string(communitySlug)
        }

        do {
            // Create the channel with the current user as the initial member
            // The public flag will make it discoverable to others
            let channelId = ChannelId(type: .team, id: finalChannelId)

            // Get current user ID
            guard let currentUserId = client.currentUserId else {
                showError("Unable to get current user ID")
                return
            }

            channelController = try client.channelController(
                createChannelWithId: channelId,
                name: name,
                imageURL: nil,
                members: [currentUserId], // Include creator as initial member
                isCurrentUserMember: true, // Ensure creator is a member
                extraData: extraData
            )
        } catch {
            print("Failed to create channel controller: \(error)")
            showError("Failed to create channel: \(error.localizedDescription)")
            return
        }

        // Note: Channel description can be set in extraData during creation
        // Stream SDK v4 doesn't support updating extraData after creation directly
        // Description would need to be part of initial channel creation

        // Show loading indicator
        showLoadingIndicator()

        // Synchronize to create the channel
        channelController.synchronize { [weak self] error in
            self?.hideLoadingIndicator()

            if let error = error {
                print("Channel creation error: \(error)")

                // Parse Stream error for permission issues
                let errorMessage = error.localizedDescription
                if errorMessage.lowercased().contains("permission") ||
                   errorMessage.lowercased().contains("unauthorized") ||
                   errorMessage.lowercased().contains("not allowed") {
                    self?.showError("Permission Denied: Users are not allowed to create channels. Please contact your admin to enable this feature.")
                } else {
                    self?.showError("Failed to create channel: \(errorMessage)")
                }
            } else {
                print("Channel created successfully")

                // Sync community members to the channel via Rails endpoint
                self?.syncCommunityMembers(channelId: finalChannelId)

                // Add a welcome message to the new channel
                channelController.createNewMessage(
                    text: "Welcome to #\(name)! 🎉"
                ) { result in
                    if case .failure(let error) = result {
                        print("Failed to send welcome message: \(error)")
                    }
                }

                // The channel list should automatically update, but we can force a refresh
                self?.controller?.synchronize { _ in }

                // Optionally, navigate to the new channel
                self?.navigateToChannel(channelController: channelController)
            }
        }
    }

    private func syncCommunityMembers(channelId: String) {
        // Call Rails endpoint to add all community members to the channel
        let baseURL = AppConfig.baseURL
        let syncURL = baseURL.appendingPathComponent("chat/channels/\(channelId)/sync_members")

        var request = URLRequest(url: syncURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include cookies for authentication
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, value) in headers {
                request.setValue(value, forHTTPHeaderField: header)
            }
        }

        // Get CSRF token from cookies if available
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL),
           let csrfCookie = cookies.first(where: { $0.name == "CSRF-TOKEN" }) {
            request.setValue(csrfCookie.value, forHTTPHeaderField: "X-CSRF-Token")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to sync community members: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let membersAdded = json["members_added"] as? Int {
                        print("Successfully synced \(membersAdded) community members to channel")
                    }
                } else {
                    print("Failed to sync members, status: \(httpResponse.statusCode)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("Response: \(body)")
                    }
                }
            }
        }.resume()
    }

    private func navigateToChannel(channelController: ChatChannelController) {
        // Create and configure optimized channel view controller
        let channelVC = TrackingChannelVC()
        channelVC.channelController = channelController

        // Push to navigation controller with optimized transition
        navigationController?.pushViewController(channelVC, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showLoadingIndicator() {
        let loadingAlert = UIAlertController(
            title: nil,
            message: "Creating channel...",
            preferredStyle: .alert
        )

        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()

        loadingAlert.view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor, constant: -20)
        ])

        present(loadingAlert, animated: true)
    }

    private func hideLoadingIndicator() {
        if let presentedVC = presentedViewController,
           presentedVC is UIAlertController {
            presentedVC.dismiss(animated: true)
        }
    }
}

// MARK: - Advanced Channel Creation Options (Future Enhancement)
extension CustomChannelListVC {

    // These methods are placeholders for future enhancements
    // Currently, the basic channel creation is implemented via showChannelCreationDialog()

    // Helper method to show channel type selection (future enhancement)
    func showChannelTypeSelection() {
        let alert = UIAlertController(
            title: "Channel Type",
            message: "Choose the type of channel to create",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Public Channel", style: .default) { [weak self] _ in
            self?.showChannelCreationDialog()
        })

        alert.addAction(UIAlertAction(title: "Private Channel", style: .default) { [weak self] _ in
            // For private channels, you might want to add member selection
            self?.showPrivateChannelCreation()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }

        present(alert, animated: true)
    }

    private func showPrivateChannelCreation() {
        // Implement private channel creation with member selection
        // This is a placeholder for more advanced functionality
        showChannelCreationDialog()
    }
}

// MARK: - Channel Actions
extension CustomChannelListVC {

    private func createChannelContextMenu(for channel: ChatChannel) -> UIMenu {
        var actions: [UIMenuElement] = []

        // Mute/Unmute action
        let muteTitle = channel.isMuted ? "Unmute Channel" : "Mute Channel"
        let muteImage = UIImage(systemName: channel.isMuted ? "speaker.wave.2" : "speaker.slash")
        let muteAction = UIAction(title: muteTitle, image: muteImage) { [weak self] _ in
            self?.toggleMute(for: channel)
        }
        actions.append(muteAction)

        // Mark as Read
        if channel.unreadCount.messages > 0 {
            let markReadAction = UIAction(title: "Mark as Read", image: UIImage(systemName: "envelope.open")) { [weak self] _ in
                self?.markChannelAsRead(channel)
            }
            actions.append(markReadAction)
        }

        // Channel Info
        let infoAction = UIAction(title: "Channel Info", image: UIImage(systemName: "info.circle")) { [weak self] _ in
            self?.showChannelInfo(channel)
        }
        actions.append(infoAction)

        // Separator before destructive actions
        actions.append(UIMenu(title: "", options: .displayInline, children: []))

        // Leave Channel
        let leaveAction = UIAction(title: "Leave Channel", image: UIImage(systemName: "arrow.right.square"), attributes: .destructive) { [weak self] _ in
            self?.confirmLeaveChannel(channel)
        }
        actions.append(leaveAction)

        // Delete Channel (only for admins/owners)
        if channel.membership?.memberRole == .admin || channel.membership?.memberRole == .owner {
            let deleteAction = UIAction(title: "Delete Channel", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDeleteChannel(channel)
            }
            actions.append(deleteAction)
        }

        return UIMenu(children: actions)
    }

    private func showChannelOptionsMenu(for channel: ChatChannel) {
        let alert = UIAlertController(
            title: channel.name ?? "Channel Options",
            message: nil,
            preferredStyle: .actionSheet
        )

        // Mute/Unmute option
        let muteTitle = channel.isMuted ? "Unmute Channel" : "Mute Channel"
        alert.addAction(UIAlertAction(title: muteTitle, style: .default) { [weak self] _ in
            self?.toggleMute(for: channel)
        })

        // Mark as Read
        if channel.unreadCount.messages > 0 {
            alert.addAction(UIAlertAction(title: "Mark as Read", style: .default) { [weak self] _ in
                self?.markChannelAsRead(channel)
            })
        }

        // Channel Info
        alert.addAction(UIAlertAction(title: "Channel Info", style: .default) { [weak self] _ in
            self?.showChannelInfo(channel)
        })

        // Leave Channel
        alert.addAction(UIAlertAction(title: "Leave Channel", style: .destructive) { [weak self] _ in
            self?.confirmLeaveChannel(channel)
        })

        // Delete Channel (only for admins/owners)
        if channel.membership?.memberRole == .admin || channel.membership?.memberRole == .owner {
            alert.addAction(UIAlertAction(title: "Delete Channel", style: .destructive) { [weak self] _ in
                self?.confirmDeleteChannel(channel)
            })
        }

        // Cancel
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Configure for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func toggleMute(for channel: ChatChannel) {
        guard let channelController = controller?.client.channelController(for: channel.cid) else {
            return
        }

        let shouldMute = !channel.isMuted

        if shouldMute {
            // Mute the channel
            channelController.muteChannel { [weak self] error in
                if let error = error {
                    self?.showError("Failed to mute channel: \(error.localizedDescription)")
                } else {
                    self?.showSuccess("Channel muted 🔇")
                    // Reload the table view to update the UI with mute indicator
                    self?.controller?.synchronize { _ in
                        // Force reload to show mute indicator
                        DispatchQueue.main.async {
                            self?.collectionView.reloadData()
                        }
                    }
                }
            }
        } else {
            // Unmute the channel
            channelController.unmuteChannel { [weak self] error in
                if let error = error {
                    self?.showError("Failed to unmute channel: \(error.localizedDescription)")
                } else {
                    self?.showSuccess("Channel unmuted 🔔")
                    // Reload the table view to update the UI and remove mute indicator
                    self?.controller?.synchronize { _ in
                        // Force reload to remove mute indicator
                        DispatchQueue.main.async {
                            self?.collectionView.reloadData()
                        }
                    }
                }
            }
        }
    }

    private func markChannelAsRead(_ channel: ChatChannel) {
        guard let channelController = controller?.client.channelController(for: channel.cid) else {
            return
        }

        channelController.markRead { [weak self] error in
            if let error = error {
                self?.showError("Failed to mark as read: \(error.localizedDescription)")
            } else {
                self?.controller?.synchronize()
            }
        }
    }

    private func showChannelInfo(_ channel: ChatChannel) {
        let info = """
        Channel: \(channel.name ?? "Unnamed")
        Type: \(channel.type.rawValue)
        Members: \(channel.memberCount)
        Created: \(channel.createdAt.formatted())
        """

        let alert = UIAlertController(
            title: "Channel Information",
            message: info,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func confirmLeaveChannel(_ channel: ChatChannel) {
        let alert = UIAlertController(
            title: "Leave Channel?",
            message: "Are you sure you want to leave '\(channel.name ?? "this channel")'?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.leaveChannel(channel)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func leaveChannel(_ channel: ChatChannel) {
        guard let channelController = controller?.client.channelController(for: channel.cid),
              let currentUserId = controller?.client.currentUserId else {
            return
        }

        showLoadingIndicator()

        channelController.removeMembers(userIds: [currentUserId]) { [weak self] error in
            self?.hideLoadingIndicator()

            if let error = error {
                self?.showError("Failed to leave channel: \(error.localizedDescription)")
            } else {
                self?.showSuccess("Left channel")
                self?.controller?.synchronize()
            }
        }
    }

    private func confirmDeleteChannel(_ channel: ChatChannel) {
        let alert = UIAlertController(
            title: "Delete Channel?",
            message: "Are you sure you want to delete '\(channel.name ?? "this channel")'? This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteChannel(channel)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func deleteChannel(_ channel: ChatChannel) {
        guard let channelController = controller?.client.channelController(for: channel.cid) else {
            return
        }

        showLoadingIndicator()

        channelController.deleteChannel { [weak self] error in
            self?.hideLoadingIndicator()

            if let error = error {
                self?.showError("Failed to delete channel: \(error.localizedDescription)")
            } else {
                self?.showSuccess("Channel deleted")
                self?.controller?.synchronize()
            }
        }
    }

    private func showSuccess(_ message: String) {
        let alert = UIAlertController(
            title: "Success",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Auto-dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}

