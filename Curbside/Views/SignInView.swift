import AuthenticationServices
import SwiftUI

struct SignInView: View {
    let model: RootModel

    @Environment(\.webAuthenticationSession) private var webAuth

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            StreetSign(name: "Curbside")
            Text("Remember who lives where on your street.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            if let message = model.errorMessage {
                Text(message)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.ink)
            }
            ForEach(IdentityProvider.allCases, id: \.self) { provider in
                ProviderButton(provider: provider) { signIn(provider) }
            }
        }
        .padding(Spacing.md)
        .disabled(model.isBusy)
    }

    private func signIn(_ provider: IdentityProvider) {
        Task {
            await model.signIn(with: provider) { url in
                // Ephemeral: no Cognito or Google cookie outlives sign-out to sign the next person straight back in.
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

#Preview {
    SignInView(model: .live())
        .background(Palette.background)
}
