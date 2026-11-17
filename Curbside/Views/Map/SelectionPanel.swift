import SwiftUI

/// The picked building or dropped pin: its address and who lives there.
struct SelectionPanel: View {
    let spot: Spot
    let households: [Household]
    let open: (Household) -> Void
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
                Text("Nobody added here yet.")
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
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 0, y: 3)
        .padding(Spacing.md)
    }
}
