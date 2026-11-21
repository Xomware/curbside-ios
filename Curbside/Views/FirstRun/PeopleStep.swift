import SwiftUI

/// "Who lives with you?" Names only, one at a time; birthdays and the rest wait for the household card.
struct PeopleStep: View {
    @Bindable var model: FirstRunModel

    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepLabel(number: 3)
                StreetSign(name: "Who lives with you?")
                if let home = model.home {
                    HousePlaque(number: home.houseNumber, name: home.mine.label)
                }
                Text("Names are enough for now. Birthdays, notes and the rest go on your household's card.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                TextField("Name", text: $model.name)
                    .font(CurbsideFont.body)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($typing)
                    .onSubmit(add)
                    .padding(Spacing.md)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
                Picker("Adult, kid or pet", selection: $model.kind) {
                    ForEach(FirstRunModel.Kind.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                PanelButton(title: "Add", systemImage: "plus", action: add)
                    .disabled(RootModel.validName(model.name) == nil)
                    .opacity(RootModel.validName(model.name) == nil ? 0.5 : 1)
                if let message = model.message {
                    Text(message)
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                }
                if !model.added.isEmpty {
                    added
                }
                SignButton(title: model.added.isEmpty ? "Skip for now" : "Next", action: model.finishPeople)
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isBusy)
        .sensoryFeedback(.success, trigger: model.added.count)
    }

    private var added: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("IN YOUR HOUSE")
                .font(CurbsideFont.label)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(model.added) { member in
                Text("\(member.name), \(member.kind.rawValue)")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    private func add() {
        Task {
            await model.addMember()
            typing = true
        }
    }
}
