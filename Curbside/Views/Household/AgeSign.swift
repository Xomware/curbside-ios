import SwiftUI

/// A kid's age read like a speed-limit sign.
struct AgeSign: View {
    let age: String

    var body: some View {
        VStack(spacing: 0) {
            Text("AGE")
                .font(CurbsideFont.label)
            Text(age)
                .font(CurbsideFont.signHeadline)
        }
        .foregroundStyle(Palette.signInk)
        .frame(minWidth: 48)
        .padding(.vertical, Spacing.xs)
        .signFace(Palette.signWhite, rule: Palette.signInk, cornerRadius: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(age.hasPrefix("~") ? "About \(age.dropFirst())" : "Age \(age)")
    }
}
