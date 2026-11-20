import SwiftUI

/// Export and delete. Delete asks twice: here, then with a fresh sign-in.
struct DataSection: View {
    let model: AccountDataModel
    let identities: [Identity]
    /// Presented by the caller: a sheet attached inside a Form section dismissed the settings sheet with it.
    let share: (URL) -> Void

    @Environment(\.webAuthenticationSession) private var webAuth
    @Environment(\.openURL) private var openURL
    @State private var confirming = false

    var body: some View {
        Section {
            Button("Export my data") {
                Task {
                    if let url = await model.export() { share(url) }
                }
            }
            Button("Delete account", role: .destructive) { confirming = true }
        } header: {
            Text("Your data")
        } footer: {
            Text(model.message ?? "Export is a JSON file of everything Curbside holds for you.")
                .foregroundStyle(model.message == nil ? Palette.inkSecondary : Palette.ink)
        }
        .disabled(model.phase == .working)
        .confirmationDialog("Delete your account?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { Task { await delete() } }
        } message: {
            Text("This deletes your account, your sign-ins, and every street only you are on. A street you share passes to whoever has been on it longest. It can't be undone. You'll sign in with \(model.reauthProvider(identities) == .apple ? "Apple" : "Google") first to confirm.")
        }
        .alert("Account deleted", isPresented: .constant(manualRevoke != nil)) {
            Button("Open Apple's instructions") {
                if let manualRevoke { openURL(manualRevoke) }
                model.finish()
            }
            Button("Done", role: .cancel, action: model.finish)
        } message: {
            Text("Apple didn't confirm that Sign in with Apple stopped for Curbside. You can stop it yourself in your Apple Account settings.")
        }
    }

    private var manualRevoke: URL? {
        if case .deleted(let url) = model.phase { url } else { nil }
    }

    private func delete() async {
        await model.delete(identities: identities) { url in
            try await webAuth.authenticate(
                using: url,
                callback: .customScheme(Cognito.callbackScheme),
                preferredBrowserSession: .ephemeral,
                additionalHeaderFields: [:]
            )
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
