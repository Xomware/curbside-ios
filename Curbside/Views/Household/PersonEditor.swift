import SwiftUI

/// Add or edit one person. Stays open on a conflict or failure so nothing typed is lost.
struct PersonEditor: View {
    let model: HouseholdModel
    let person: Person?

    @State private var draft: PersonDraft
    @State private var message: String?
    @State private var isBusy = false
    @Environment(\.dismiss) private var dismiss

    init(model: HouseholdModel, person: Person?) {
        self.model = model
        self.person = person
        _draft = State(initialValue: person.map(PersonDraft.init) ?? PersonDraft())
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Name") {
                    TextField("Name", text: $draft.name)
                        .textContentType(.givenName)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Adult or kid", selection: $draft.role) {
                    Text("Adult").tag(Person.Role.adult)
                    Text("Kid").tag(Person.Role.kid)
                }
                .pickerStyle(.segmented)
                LabeledContent("Birth year") {
                    TextField("Birth year", text: $draft.birthYear, prompt: Text("Optional"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("The year is a guess", isOn: $draft.approx)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...8)
                if let message = message ?? draft.problem() {
                    Text(message)
                        .foregroundStyle(Palette.ink)
                }
                if let person {
                    Button("Remove \(person.name)", role: .destructive) { Task { await remove(person) } }
                }
            }
            .font(CurbsideFont.body)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(person == nil ? "Add a person" : "Edit \(person?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(draft.problem() != nil || isBusy)
                }
            }
            .disabled(isBusy)
        }
        .tint(Palette.ink)
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        switch await model.savePerson(draft, id: person?.id) {
        case .saved: dismiss()
        case .conflict: message = "Someone else changed this person. The card has their version; save again to apply yours."
        case .failed: message = "Couldn't save. Try again."
        }
    }

    private func remove(_ person: Person) async {
        isBusy = true
        defer { isBusy = false }
        if await model.deletePerson(person.id) { dismiss() } else { message = "Couldn't remove them. Try again." }
    }
}
