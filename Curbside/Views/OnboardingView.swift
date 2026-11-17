import SwiftUI

struct OnboardingView: View {
    let model: RootModel

    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            StreetSign(name: "New here")
            Text("Pick a display name. Only people on maps you share can see it.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
            TextField("Display name", text: $name)
                .font(CurbsideFont.body)
                .textContentType(.nickname)
                .submitLabel(.done)
                .onSubmit(submit)
                .padding(Spacing.md)
                .background(Palette.surface, in: .rect(cornerRadius: 8))
            if let message = model.errorMessage {
                Text(message)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.ink)
            }
            SignButton(title: "Start mapping", action: submit)
                .disabled(RootModel.validName(name) == nil)
            Spacer()
            Button("Use a different sign-in", action: model.signOut)
                .font(CurbsideFont.detail)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .buttonStyle(SignPressStyle())
        }
        .padding(Spacing.md)
        .disabled(model.isBusy)
    }

    private func submit() {
        Task { await model.createAccount(named: name) }
    }
}
