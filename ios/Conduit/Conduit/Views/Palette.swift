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
