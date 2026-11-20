import SwiftUI

/// The account's display name, editable in place. Save shows once it differs and the backend would take it.
struct DisplayNameSection: View {
    let root: RootModel
    let saved: String

    @State private var name: String
    @State private var isSaving = false
    @State private var failed = false

    init(root: RootModel, saved: String) {
        self.root = root
        self.saved = saved
        _name = State(initialValue: saved)
    }

    private var canSave: Bool {
        RootModel.validName(name).map { $0 != saved } ?? false
    }

    var body: some View {
        Section {
            TextField("Display name", text: $name)
                .textContentType(.nickname)
                .submitLabel(.done)
                .onSubmit(save)
            if canSave {
                Button(isSaving ? "Saving…" : "Save name", action: save)
                    .disabled(isSaving)
            }
        } header: {
            Text("Display name")
        } footer: {
            if failed {
                Text("Couldn't save your name. Try again.").foregroundStyle(Palette.ink)
            } else {
                Text("People on streets you share see this name.")
            }
        }
        .sensoryFeedback(.success, trigger: saved)
    }

    private func save() {
        guard canSave else { return }
        Task {
            isSaving = true
            failed = !(await root.rename(to: name))
            isSaving = false
        }
    }
}
