import SwiftUI

/// Write a note about a household. Saving one also counts as talking to them today.
struct NoteEditor: View {
    let model: HouseholdModel

    @State private var text = ""
    @State private var failed = false
    @State private var isBusy = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("What did you learn?", text: $text, axis: .vertical)
                    .font(CurbsideFont.body)
                    .lineLimit(4...12)
                    .padding(Spacing.md)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
                if failed {
                    Text("Couldn't save the note. Try again.")
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
            }
            .padding(Spacing.md)
            .background(Palette.background)
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2000 || isBusy)
                }
            }
        }
        .tint(Palette.ink)
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        if await model.addNote(text) { dismiss() } else { failed = true }
    }
}
