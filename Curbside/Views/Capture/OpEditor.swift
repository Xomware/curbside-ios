import SwiftUI

/// Retype what the parse heard: a misspelt name, a better label, a note in your own words.
struct OpEditor: View {
    let op: CaptureOp
    let save: ([String: String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]

    init(op: CaptureOp, save: @escaping ([String: String]) -> Void) {
        self.op = op
        self.save = save
        _values = State(initialValue: op.fields.compactMapValues(\.text))
    }

    private var keys: [String] { CaptureModel.editable.filter { values[$0] != nil } }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(keys, id: \.self) { key in
                    Section(key.capitalized) {
                        TextField(key.capitalized, text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }), axis: .vertical)
                            .font(CurbsideFont.body)
                            // A vertical-axis field drops its title from accessibility.
                            .accessibilityLabel(key.capitalized)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Edit change")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save(values)
                        dismiss()
                    }
                    .disabled(missing)
                }
            }
        }
    }

    private var missing: Bool {
        keys.contains { CaptureModel.required.contains($0) && (values[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
