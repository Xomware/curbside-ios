import SwiftUI

/// A white regulatory panel as a button: black type and rule, for adding things.
struct PanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(CurbsideFont.button)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Palette.signInk)
                .padding(.horizontal, Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 48)
                .signFace(Palette.signWhite, rule: Palette.signInk, cornerRadius: 6)
        }
        .buttonStyle(SignPressStyle())
    }
}

#Preview("Light") {
    PanelButton(title: "Add a house", systemImage: "plus") {}
        .padding()
        .background(Palette.background)
}

#Preview("Dark") {
    PanelButton(title: "Add a house", systemImage: "plus") {}
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
