import SwiftUI

/// Account, privacy and credits. Sign-in methods and your data join this list in the next sections.
struct SettingsView: View {
    let root: RootModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if case .home(let account) = root.route {
                    Section("Account") {
                        LabeledContent("Display name", value: account.displayName)
                    }
                }
                lock
                about
                Section {
                    Button("Sign out", role: .destructive) {
                        dismiss()
                        root.signOut()
                    }
                }
            }
            .font(CurbsideFont.body)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Palette.ink)
    }

    private var lock: some View {
        @Bindable var lock = root.lock
        return Section {
            Toggle("Lock with Face ID or passcode", isOn: $lock.isEnabled)
                .tint(Palette.signGreen)
                .disabled(!lock.canLock)
        } header: {
            Text("Privacy")
        } footer: {
            Text(lock.canLock ? "Asks when Curbside opens and when you come back to it." : "Set a passcode on this iPhone to lock Curbside.")
        }
    }

    private var about: some View {
        Section("About") {
            outbound("Privacy policy", Self.privacyPolicy)
            outbound("Map outlines © OpenStreetMap contributors", Self.osmCopyright)
            Text("Maps and addresses by Apple Maps")
            Text("Overpass and Overpass Mono typefaces, SIL Open Font License 1.1")
            LabeledContent("Version", value: Self.version)
        }
    }

    private func outbound(_ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    // Literal URLs: a typo fails the first time this view renders in any build, so the force unwrap can't ship.
    private static let privacyPolicy = URL(string: "https://curbside.xomware.com/privacy")!
    private static let osmCopyright = URL(string: "https://www.openstreetmap.org/copyright")!

    private static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }
}
