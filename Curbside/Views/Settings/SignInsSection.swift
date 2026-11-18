import SwiftUI

/// Settings' list of sign-ins, with add and remove.
struct SignInsSection: View {
    let model: SignInsModel

    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var removing: Identity?

    var body: some View {
        Section {
            ForEach(model.identities) { identity in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(identity.name)
                        if identity.sub == model.currentSub {
                            Text("Signed in on this iPhone")
                                .font(CurbsideFont.detail)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Spacer()
                    if model.identities.count > 1 {
                        Button(identity.sub == model.currentSub ? "Remove and sign out" : "Remove", role: .destructive) {
                            removing = identity
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            ForEach(model.addable, id: \.self) { provider in
                Button(provider == .apple ? "Add Sign in with Apple" : "Add Google sign-in") {
                    Task { await link(provider) }
                }
            }
        } header: {
            Text("Sign-ins")
        } footer: {
            if let message = model.message {
                Text(message).foregroundStyle(Palette.ink)
            } else {
                Text("Any of these opens the same account.")
            }
        }
        .disabled(model.isBusy)
        .task { await model.load() }
        .confirmationDialog("Remove \(removing?.name ?? "") sign-in?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible, presenting: removing) { identity in
            Button(identity.sub == model.currentSub ? "Remove and sign out" : "Remove", role: .destructive) {
                Task { await model.unlink(identity) }
            }
        } message: { identity in
            Text("You won't be able to open Curbside with \(identity.name) any more.")
        }
    }

    private func link(_ provider: IdentityProvider) async {
        await model.link(provider) { url in
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
