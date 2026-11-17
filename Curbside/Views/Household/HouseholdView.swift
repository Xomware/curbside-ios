import SwiftUI

/// The household card: who lives here, their kids and pets, and what you've noted.
struct HouseholdView: View {
    @State private var model: HouseholdModel
    @State private var editingPerson: EditTarget<Person>?
    @State private var editingPet: EditTarget<Pet>?
    @State private var writingNote = false
    @State private var message: String?

    init(model: HouseholdModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HouseholdHero(household: model.household) { Task { await talkedToday() } }
                ForEach(Array(model.sections.enumerated()), id: \.offset) { _, section in
                    HouseholdSection(section: section) { editingPerson = EditTarget(item: $0) } editPet: {
                        editingPet = EditTarget(item: $0)
                    } deleteNote: { note in
                        Task { message = await model.deleteNote(note.id) ? nil : "Couldn't delete the note. Try again." }
                    }
                    Divider().overlay(Palette.inkSecondary.opacity(0.3))
                }
                if model.isLoading && model.household.mine.notes == nil {
                    ProgressView()
                        .tint(Palette.signGreen)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .accessibilityLabel("Loading notes")
                }
                if let message {
                    Text(message)
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, Spacing.md)
                }
                VStack(spacing: Spacing.sm) {
                    SignButton(title: "Add a note") { writingNote = true }
                    HStack(spacing: Spacing.sm) {
                        SignButton(title: "Add a person") { editingPerson = EditTarget(item: nil) }
                        SignButton(title: "Add a pet") { editingPet = EditTarget(item: nil) }
                    }
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
        .sheet(isPresented: $writingNote) { NoteEditor(model: model) }
    }

    private func talkedToday() async {
        switch await model.talkedToday() {
        case .saved: message = nil
        case .conflict: message = "Someone else changed this household. Here's their version; tap Talked today again."
        case .failed: message = "Couldn't save that. Try again."
        }
    }
}

/// Sheet item for an editor: an existing item, or nil for a new one.
struct EditTarget<Item: Identifiable<String>>: Identifiable {
    let item: Item?
    var id: String { item?.id ?? "new" }
}
