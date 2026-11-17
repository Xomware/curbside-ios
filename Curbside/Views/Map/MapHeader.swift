import SwiftUI

/// The place's street sign with a household count, and the options menu.
struct MapHeader: View {
    let name: String
    let count: Int
    let signOut: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StreetSign(name: name, detail: count == 1 ? "1 HOME" : "\(count) HOMES")
            Menu {
                Button("Sign out", role: .destructive, action: signOut)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(SignPressStyle())
            .accessibilityLabel("Map options")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}
