import SwiftUI

/// Overpass, the open cousin of the highway sign face. Sizes are the mockup's; `relativeTo:` scales them with Dynamic Type.
enum CurbsideFont {
    /// PostScript names of the named instances inside the bundled variable fonts.
    enum Face: String, CaseIterable {
        case regular = "Overpass-Regular"
        case extraBold = "OverpassRoman-ExtraBold"
        case black = "OverpassRoman-Black"
        case monoSemiBold = "OverpassMono-SemiBold"
        case monoBold = "OverpassMono-Bold"
    }

    static let signTitle = font(.extraBold, 27, .title)
    static let signHeadline = font(.extraBold, 21, .title2)
    static let button = font(.extraBold, 15, .headline)
    static let label = font(.black, 12, .caption)
    static let stop = font(.black, 18, .title3)
    static let body = font(.regular, 15, .body)
    static let detail = font(.regular, 13, .subheadline)
    static let number = font(.monoBold, 15, .headline)
    static let mono = font(.monoSemiBold, 11, .caption)

    private static func font(_ face: Face, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        .custom(face.rawValue, size: size, relativeTo: style)
    }
}
