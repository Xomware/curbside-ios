import SwiftUI

/// Add or edit one pet. Stays open on a conflict or failure so nothing typed is lost.
struct PetEditor: View {
    let model: HouseholdModel
    let pet: Pet?

    @State private var draft: PetDraft
    @State private var message: String?
    @State private var isBusy = false
    @Environment(\.dismiss) private var dismiss

    init(model: HouseholdModel, pet: Pet?) {
        self.model = model
        self.pet = pet
        _draft = State(initialValue: pet.map(PetDraft.init) ?? PetDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Name") {
                    TextField("Name", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Kind") {
                    TextField("Kind", text: $draft.species, prompt: Text("Basset hound, cat"))
                        .multilineTextAlignment(.trailing)
                }
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...8)
                if let message = message ?? draft.problem {
                    Text(message)
                        .foregroundStyle(Palette.ink)
                }
                if let pet {
                    Button("Remove \(pet.name)", role: .destructive) { Task { await remove(pet) } }
                }
            }
            .font(CurbsideFont.body)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(pet.map { "Edit \($0.name)" } ?? "Add a pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(draft.problem != nil || isBusy)
                }
            }
            .disabled(isBusy)
        }
        .tint(Palette.ink)
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        switch await model.savePet(draft, id: pet?.id) {
        case .saved: dismiss()
        case .conflict: message = "Someone else changed this pet. The card has their version; save again to apply yours."
        case .failed: message = "Couldn't save. Try again."
        }
    }

    private func remove(_ pet: Pet) async {
        isBusy = true
        defer { isBusy = false }
        if await model.deletePet(pet.id) { dismiss() } else { message = "Couldn't remove \(pet.name). Try again." }
    }
}
