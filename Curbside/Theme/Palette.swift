import SwiftUI

/// Colour tokens from the Curbside mockup: sun-bleached concrete by day, asphalt under streetlights by night.
enum Palette {
    static let background = Color(light: 0xEBE8E1, dark: 0x161918)
    static let surface = Color(light: 0xF6F4EE, dark: 0x202423)
    static let ink = Color(light: 0x1C1F1E, dark: 0xECEEE8)
    static let inkSecondary = Color(light: 0x535955, dark: 0xA5ACA7)

    static let signGreen = Color(light: 0x0D6B3C, dark: 0x0F6E40)
    static let signWhite = Color(light: 0xF5F5EE, dark: 0xF2F3EA)
    static let signInk = Color(light: 0x151716, dark: 0x151716)
    static let warning = Color(light: 0xF2C12A, dark: 0xF2C12A)
    static let workZone = Color(light: 0xE9711A, dark: 0xF08232)
    // The mockup's brighter night red (#D63A32) drops white text to 4.2:1, under WCAG AA.
    static let stop = Color(light: 0xC4302A, dark: 0xC4302A)

    static let roof = Color(light: 0x6E5648, dark: 0x3B3230)
    static let roofAccessory = Color(light: 0x857A70, dark: 0x34302E)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
