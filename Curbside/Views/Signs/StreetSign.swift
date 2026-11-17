import SwiftUI

/// Green street-name blade. With a `detail` ("100 BLK") it stretches to full width with the detail on the right.
struct StreetSign: View {
    let name: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(name)
                .font(CurbsideFont.signTitle)
            if let detail {
                Spacer(minLength: 0)
                Text(detail)
                    .font(CurbsideFont.button)
            }
        }
        .foregroundStyle(Palette.signWhite)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .signFace(Palette.signGreen, rule: Palette.signWhite)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        StreetSign(name: "Quillfeather Ln", detail: "100 BLK")
        StreetSign(name: "Pumpernickel")
    }
    .padding()
    .background(Palette.background)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        StreetSign(name: "Quillfeather Ln", detail: "100 BLK")
        StreetSign(name: "Pumpernickel")
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
