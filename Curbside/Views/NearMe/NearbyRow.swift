import SwiftUI

/// An overhead exit sign: side and distance on the tab, an arrow at the curb you mean, who lives there, and the
/// newest note on the yellow EXIT ONLY strip when the card has loaded one.
struct NearbyRow: View {
    let row: Nearby

    private let year = Calendar.current.component(.year, from: .now)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.md) {
                if let side = row.side {
                    Image(systemName: side == .left ? "arrow.up.left" : "arrow.up.right")
                        .font(.title2.weight(.black))
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(row.household.mine.label)
                        .font(CurbsideFont.signHeadline)
                    Text(who)
                        .font(CurbsideFont.detail)
                }
                Spacer(minLength: 0)
                Text(tab)
                    .font(CurbsideFont.label)
            }
            .padding(Spacing.md)
            if let note = row.household.mine.notes?.first {
                Text(note.text.uppercased())
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.signInk)
                    .lineLimit(2)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.warning)
            }
        }
        .foregroundStyle(Palette.signWhite)
        .multilineTextAlignment(.leading)
        .signFace(Palette.signGreen, rule: Palette.signWhite)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var tab: String {
        guard let side = row.side else { return "\(row.meters) M" }
        return "\(side == .left ? "LEFT" : "RIGHT") · \(row.meters) M"
    }

    /// "Desmond, Opaline · kids Fig, 9 · Waffles (basset hound)"
    private var who: String {
        let people = row.household.mine.people ?? []
        let adults = people.filter { $0.role == .adult }.map(\.name).joined(separator: ", ")
        let kids = people.filter { $0.role == .kid }.map { kid in kid.age(in: year).map { "\(kid.name), \($0)" } ?? kid.name }
        let pets = (row.household.mine.pets ?? []).map { pet in pet.species.map { "\(pet.name) (\($0))" } ?? pet.name }
        let parts = [adults, kids.isEmpty ? "" : "kids " + kids.joined(separator: ", "), pets.joined(separator: ", ")]
        let line = parts.filter { !$0.isEmpty }.joined(separator: " · ")
        return line.isEmpty ? "No names yet" : line
    }
}
