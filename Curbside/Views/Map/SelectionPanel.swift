import SwiftUI

/// The picked building or dropped pin: its address, who lives there, and adding someone.
struct SelectionPanel: View {
    let spot: Spot
    let households: [Household]
    let open: (Household) -> Void
    let add: () -> Void
    let talk: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(spot.address?.uppercased() ?? "THIS HOUSE")
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityLabel("Close")
            }
            if households.isEmpty {
                Text(spot.buildingID == nil ? "Nobody added here yet. Tap the map to move the pin." : "Nobody added here yet.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
            }
            ForEach(households) { household in
                Button { open(household) } label: {
                    HousePlaque(number: household.houseNumber, name: household.mine.label)
                        .frame(minHeight: 44)
                }
                .buttonStyle(SignPressStyle())
            }
            HStack(spacing: Spacing.md) {
                // Always offered: a building with one household can still be a duplex.
                PanelButton(title: households.isEmpty ? "Add who lives here" : "Add another", systemImage: "plus", action: add)
                    .accessibilityLabel("Add a household here")
                Button(action: talk) {
                    Text("TALK")
                        .font(CurbsideFont.button)
                        .foregroundStyle(Palette.signWhite)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 48)
                        .background(Palette.stop, in: Octagon())
                }
                .buttonStyle(SignPressStyle())
                .accessibilityLabel(households.isEmpty ? "Talk: capture a new house here" : "Talk: capture about this house")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 0, y: 3)
        .padding(Spacing.md)
    }
}
