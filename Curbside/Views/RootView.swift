import SwiftUI

struct RootView: View {
    let model: RootModel

    @Environment(\.scenePhase) private var phase

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .overlay { cover }
            .task {
                await model.lock.unlock()
                await model.load()
            }
            .onChange(of: phase) { _, phase in
                if phase == .background { model.lock.lock() }
                if phase == .active { Task { await model.lock.unlock() } }
            }
    }

    /// Nothing to hide before sign-in. Inactive covers the app-switcher snapshot, and the Face ID sheet's moment.
    @ViewBuilder private var cover: some View {
        if model.route != .signedOut {
            if model.lock.isLocked {
                LockView { Task { await model.lock.unlock() } }
            } else if phase != .active, model.lock.isEnabled {
                LockView(unlock: nil)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.route {
        case .signedOut:
            SignInView(model: model)
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .accessibilityLabel("Loading your account")
        case .onboarding:
            OnboardingView(model: model)
        case .home:
            HomeView(root: model)
        case .failed:
            VStack(spacing: Spacing.md) {
                Text("Couldn't reach Curbside.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                SignButton(title: "Try again") { Task { await model.load() } }
            }
            .padding(Spacing.md)
        }
    }
}

#Preview {
    RootView(model: .live())
}
