import SwiftUI

/// The household card: who lives here, their kids and pets, and what you've noted.
struct HouseholdView: View {
    @State private var model: HouseholdModel
    @State private var editingPerson: EditTarget<Person>?
    @State private var editingPet: EditTarget<Pet>?

    init(model: HouseholdModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HouseholdHero(household: model.household)
                ForEach(Array(model.sections.enumerated()), id: \.offset) { _, section in
                    HouseholdSection(section: section) { editingPerson = EditTarget(item: $0) } editPet: { editingPet = EditTarget(item: $0) }
                    Divider().overlay(Palette.inkSecondary.opacity(0.3))
                }
                if model.isLoading && model.household.mine.notes == nil {
                    ProgressView()
                        .tint(Palette.signGreen)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .accessibilityLabel("Loading notes")
                }
                HStack(spacing: Spacing.sm) {
                    SignButton(title: "Add a person") { editingPerson = EditTarget(item: nil) }
                    SignButton(title: "Add a pet") { editingPet = EditTarget(item: nil) }
                }
                .padding(Spacing.md)
                if model.failed {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Couldn't load their notes.")
                            .font(CurbsideFont.body)
                            .foregroundStyle(Palette.ink)
                        SignButton(title: "Try again") { Task { await model.load() } }
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .background(Palette.background)
        .task { await model.load() }
        .sheet(item: $editingPerson) { PersonEditor(model: model, person: $0.item) }
        .sheet(item: $editingPet) { PetEditor(model: model, pet: $0.item) }
    }
}

/// Sheet item for an editor: an existing item, or nil for a new one.
struct EditTarget<Item: Identifiable<String>>: Identifiable {
    let item: Item?
    var id: String { item?.id ?? "new" }
}

private struct HouseholdHero: View {
    let household: Household

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let address = household.mine.address {
                Text(address.uppercased())
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.inkSecondary)
            }
            StreetSign(name: household.mine.label)
            Text(talked)
                .font(CurbsideFont.detail)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(Spacing.md)
    }

    private var talked: String {
        guard let date = household.mine.lastTalkedAt?.isoDate else { return "Haven't talked yet" }
        return "Talked " + date.formatted(.relative(presentation: .named))
    }
}
