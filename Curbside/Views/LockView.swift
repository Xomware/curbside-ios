import SwiftUI

/// Covers the app while locked, and in the app switcher so a glance doesn't show the street.
struct LockView: View {
    let unlock: (() -> Void)?

    var body: some View {
        // Top, not centered: the system Face ID panel sits in the middle of the screen.
        VStack(spacing: Spacing.md) {
            StreetSign(name: "Curbside")
            if let unlock {
                Text("Locked")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                SignButton(title: "Unlock", action: unlock)
            } else {
                Spacer()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}
