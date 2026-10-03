import UIKit

/// The website's colours, as the Android app uses them.
enum Palette {
    static let teal = UIColor(red: 0x00 / 255, green: 0x73 / 255, blue: 0x6B / 255, alpha: 1)
    static let cream = UIColor(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF5 / 255, alpha: 1)
    static let ink = UIColor(red: 0x29 / 255, green: 0x13 / 255, blue: 0x34 / 255, alpha: 1)

    /// A solid bar for web screens. The website has no dark mode, so neither does its bar.
    static let webBar: UINavigationBarAppearance = {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = cream
        appearance.titleTextAttributes = [.foregroundColor: ink]
        return appearance
    }()
}
