import SwiftUI

/// The record button: a stop sign, because you stop and talk.
struct StopSignButton: View {
    let title: String
    let accessibilityLabel: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 84

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CurbsideFont.stop)
                .foregroundStyle(Palette.signWhite)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(Spacing.sm)
                .frame(width: size, height: size)
                .background {
                    Octagon()
                        .fill(Palette.stop)
                        .overlay { Octagon().stroke(Palette.signWhite, lineWidth: 2).padding(Spacing.xs) }
                        .shadow(color: .black.opacity(0.25), radius: 0, y: 3)
                }
                .contentShape(Octagon())
        }
        .buttonStyle(SignPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Light") {
    StopSignButton(title: "TALK", accessibilityLabel: "Talk: capture by voice or text") {}
        .padding()
        .background(Palette.background)
}

#Preview("Dark") {
    StopSignButton(title: "TALK", accessibilityLabel: "Talk: capture by voice or text") {}
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
