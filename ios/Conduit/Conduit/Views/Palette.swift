import UIKit

/// The website's colours (app/assets/tailwind/theme.css), for the bars and
/// controls that sit against its pages. Paper, ink and green must equal the
/// theme's exactly; NativePaletteTest checks them. Palette.kt is the Android twin.
enum Palette {
    /// Actions, the current tab, links: the website's forest green
    static let green = UIColor(hex: 0x265C40)
    /// The page, and the bars that meet it
    static let paper = UIColor(hex: 0xF8F4EC)
    static let ink = UIColor(hex: 0x160D08)

    // Chat's colours, the same as Android's (Palette.kt)
    /// Cards and other people's messages on the paper
    static let surface = UIColor(hex: 0xFEFDFA)
    /// Secondary text, at the website's 70% ink
    static let muted = UIColor(hex: 0x6A635D)
    static let line = UIColor(hex: 0xE9E2D7)
    /// Your own messages
    static let greenTint = UIColor(hex: 0xDCE3DB)
    static let greenWash = UIColor(hex: 0xECEFE9)
    /// Search fields and quoted messages
    static let shade = UIColor(hex: 0xF4F0E8)

    /// A solid bar for web screens. The website has no dark mode, so neither does its bar.
    static let webBar: UINavigationBarAppearance = {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = paper
        appearance.titleTextAttributes = [.foregroundColor: ink]
        return appearance
    }()
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
