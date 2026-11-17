import SwiftUI
import Testing
import UIKit
@testable import Curbside

@Test(arguments: CurbsideFont.Face.allCases)
func bundledFontFaceResolves(_ face: CurbsideFont.Face) throws {
    let font = try #require(UIFont(name: face.rawValue, size: 17))
    #expect(font.fontName == face.rawValue)
}

struct ContrastPair: Sendable, CustomTestStringConvertible {
    let text: Color
    let fill: Color
    let testDescription: String
}

private let pairs = [
    ContrastPair(text: Palette.ink, fill: Palette.background, testDescription: "ink on background"),
    ContrastPair(text: Palette.inkSecondary, fill: Palette.background, testDescription: "secondary ink on background"),
    ContrastPair(text: Palette.inkSecondary, fill: Palette.surface, testDescription: "empty plaque"),
    ContrastPair(text: Palette.signWhite, fill: Palette.signGreen, testDescription: "street sign"),
    ContrastPair(text: Palette.signInk, fill: Palette.signWhite, testDescription: "plaque number, panel"),
    ContrastPair(text: Palette.signInk, fill: Palette.warning, testDescription: "warning diamond, pennant"),
    ContrastPair(text: Palette.signInk, fill: Palette.workZone, testDescription: "work-zone diamond"),
    ContrastPair(text: Palette.signWhite, fill: Palette.stop, testDescription: "stop sign"),
]

@Test(arguments: pairs, [UIUserInterfaceStyle.light, .dark])
func textMeetsWCAGAA(_ pair: ContrastPair, style: UIUserInterfaceStyle) {
    let traits = UITraitCollection(userInterfaceStyle: style)
    let text = luminance(UIColor(pair.text).resolvedColor(with: traits))
    let fill = luminance(UIColor(pair.fill).resolvedColor(with: traits))
    let ratio = (max(text, fill) + 0.05) / (min(text, fill) + 0.05)
    #expect(ratio >= 4.5)
}

private func luminance(_ color: UIColor) -> CGFloat {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: nil)
    func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}
