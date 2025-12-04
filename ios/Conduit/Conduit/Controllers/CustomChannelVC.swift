import UIKit
import StreamChat
import StreamChatUI

/// Custom ChatChannelVC that optimizes text input performance to avoid TextKit 1 fallback
class CustomChannelVC: ChatChannelVC {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Disable animations temporarily during setup to prevent lag
        UIView.setAnimationsEnabled(false)

        // Re-enable animations after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIView.setAnimationsEnabled(true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure smooth transition by preloading the view hierarchy
        view.layoutIfNeeded()
    }

    override func setUp() {
        super.setUp()

        // Perform any heavy setup operations asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Preload any data if needed
            DispatchQueue.main.async {
                self?.view.setNeedsLayout()
            }
        }
    }

    override func setUpLayout() {
        super.setUpLayout()

        // Apply optimizations to the view hierarchy after layout is set
        DispatchQueue.main.async { [weak self] in
            self?.optimizeTextViews()
        }
    }

    override func updateContent() {
        // Debounce content updates to prevent excessive redraws
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performContentUpdate), object: nil)
        perform(#selector(performContentUpdate), with: nil, afterDelay: 0.05)
    }

    @objc private func performContentUpdate() {
        super.updateContent()
    }

    /// Find and optimize all text views in the hierarchy to prevent TextKit 1 fallback
    private func optimizeTextViews() {
        let textViews = findTextViews(in: view)

        for textView in textViews {
            // Apply optimizations that don't trigger TextKit 1 fallback

            // Basic optimizations that work on all iOS versions
            textView.isScrollEnabled = true

            // Text container optimizations
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainer.widthTracksTextView = true
            textView.textContainer.maximumNumberOfLines = 0

            if #available(iOS 15.0, *) {
                // iOS 15+ specific optimizations

                // Use modern text layout if available (iOS 16+)
                if #available(iOS 16.0, *) {
                    // Access textLayoutManager to force TextKit 2
                    // This is the key to preventing the TextKit 1 fallback
                    _ = textView.textLayoutManager
                }

                // Apply performance optimizations for the text view
                // These are safe and won't trigger TextKit 1
                textView.isEditable = textView.isEditable  // Refresh the editable state

                // Disable and re-enable to force a clean state
                let wasEditable = textView.isEditable
                textView.isEditable = false
                textView.isEditable = wasEditable
            }
        }
    }

    /// Recursively find all UITextViews in a view hierarchy
    private func findTextViews(in view: UIView) -> [UITextView] {
        var textViews: [UITextView] = []

        if let textView = view as? UITextView {
            textViews.append(textView)
        }

        for subview in view.subviews {
            textViews.append(contentsOf: findTextViews(in: subview))
        }

        return textViews
    }
}

// MARK: - Additional Optimizations
extension CustomChannelVC {

    /// Override the keyboard appearance to optimize for performance
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Disable animations during rotation to prevent lag
        coordinator.animate(alongsideTransition: { _ in
            // Layout updates during transition
        }) { _ in
            // Re-optimize text views after rotation
            self.optimizeTextViews()
        }
    }
}