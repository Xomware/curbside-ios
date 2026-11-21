import AuthenticationServices
import SwiftUI

/// First sign-in with no account: start a new one, or add this sign-in to the account you already have.
struct OnboardingView: View {
    let model: RootModel

    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepLabel(number: 1)
                StreetSign(name: "New here")
                Text("What should neighbors call you? Only people on streets you share can see it.")
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
                existing
                    .padding(.top, Spacing.md)
                Button("Use a different sign-in", action: model.signOut)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .buttonStyle(SignPressStyle())
            }
            .padding(Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .disabled(model.isBusy)
    }

    private var existing: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("ALREADY USE CURBSIDE?")
                .font(CurbsideFont.label)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in the way you did before and this sign-in joins that account.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
            ForEach(IdentityProvider.allCases, id: \.self) { provider in
                ProviderButton(provider: provider) { link(provider) }
            }
        }
    }

    private func submit() {
        Task { await model.createAccount(named: name) }
    }

    private func link(_ provider: IdentityProvider) {
        Task {
            await model.linkExisting(provider) { url in
                // Ephemeral, like sign-in: the other provider's cookie mustn't sign the next person in.
                try await webAuth.authenticate(
                    using: url,
                    callback: .customScheme(Cognito.callbackScheme),
                    preferredBrowserSession: .ephemeral,
                    additionalHeaderFields: [:]
                )
            }
        }
    }
}
