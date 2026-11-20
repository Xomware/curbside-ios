import SwiftUI

/// Account, sign-ins, privacy, your data and credits.
struct SettingsView: View {
    let root: RootModel

    @Environment(\.dismiss) private var dismiss
    @State private var signIns: SignInsModel
    @State private var data: AccountDataModel
    @State private var exported: ExportFile?

    init(root: RootModel) {
        self.root = root
        _signIns = State(initialValue: SignInsModel(api: root.api, auth: root.auth, updated: root.update))
        _data = State(initialValue: AccountDataModel(api: root.api, auth: root.auth))
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .home(let account) = root.route {
                    DisplayNameSection(root: root, saved: account.displayName)
                }
                SignInsSection(model: signIns)
                lock
                DataSection(model: data, identities: signIns.identities) { exported = ExportFile(url: $0) }
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
        .sheet(item: $exported, onDismiss: removeExport) { ShareSheet(url: $0.url) }
    }

    private func removeExport() {
        // A leftover file in tmp is cleared by the system; nothing else to do if this fails.
        if let url = exported?.url { try? FileManager.default.removeItem(at: url) }
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
