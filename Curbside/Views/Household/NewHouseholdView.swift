import SwiftUI

/// Sheet for "+ ADD": a name and the address Apple found, which the user can fix.
struct NewHouseholdView: View {
    let added: (Household) -> Void

    @State private var model: NewHouseholdModel
    @Environment(\.dismiss) private var dismiss

    init(model: NewHouseholdModel, added: @escaping (Household) -> Void) {
        _model = State(initialValue: model)
        self.added = added
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StreetSign(name: "New neighbors")
                field("Family or household name", text: $model.label, content: .familyName)
                field("Address", text: $model.address, content: .fullStreetAddress)
                if let message = model.message {
                    Text(message)
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                }
                SignButton(title: "Add them") { Task { await save() } }
                    .disabled(!model.canSave)
                    .opacity(model.canSave ? 1 : 0.5)
                Spacer()
            }
            .padding(Spacing.md)
            .background(Palette.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Palette.ink)
    }

    private func save() async {
        guard let household = await model.save() else { return }
        dismiss()
        added(household)
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType) -> some View {
        TextField(title, text: text)
            .font(CurbsideFont.body)
            .textContentType(content)
            .padding(Spacing.md)
            .background(Palette.surface, in: .rect(cornerRadius: 8))
    }
}
