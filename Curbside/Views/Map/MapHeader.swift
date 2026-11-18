import SwiftUI

/// The place's street sign with a household count, and the way into settings.
struct MapHeader: View {
    let name: String
    let count: Int
    let settings: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StreetSign(name: name, detail: count == 1 ? "1 HOME" : "\(count) HOMES")
            Button(action: settings) {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(SignPressStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}
