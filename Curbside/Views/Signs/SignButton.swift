import SwiftUI

/// A full-width action painted as a green street-name blade.
struct SignButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(CurbsideFont.button)
                .foregroundStyle(Palette.signWhite)
                .frame(maxWidth: .infinity, minHeight: 48)
                .signFace(Palette.signGreen, rule: Palette.signWhite)
        }
        .buttonStyle(SignPressStyle())
        .accessibilityLabel(title)
    }
}

#Preview("Light") {
    SignButton(title: "Start mapping") {}
        .padding()
        .background(Palette.background)
}

#Preview("Dark") {
    SignButton(title: "Start mapping") {}
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
