import SwiftUI

/// Address, the household's name blade, and when you last talked.
struct HouseholdHero: View {
    let household: Household
    let talkedToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let address = household.mine.address {
                Text(address.uppercased())
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.inkSecondary)
            }
            StreetSign(name: household.mine.label)
            HStack {
                Text(talked)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                if !talkedToToday {
                    Button("Talked today", action: talkedToday)
                        .font(CurbsideFont.button)
                        .foregroundStyle(Palette.signGreen)
                        .frame(minHeight: 44)
                        .buttonStyle(SignPressStyle())
                }
            }
        }
        .padding(Spacing.md)
    }

    private var talkedToToday: Bool {
        household.mine.lastTalkedAt?.isoDate.map(Calendar.current.isDateInToday) ?? false
    }

    private var talked: String {
        guard let date = household.mine.lastTalkedAt?.isoDate else { return "Haven't talked yet" }
        return "Talked " + date.formatted(.relative(presentation: .named))
    }
}
