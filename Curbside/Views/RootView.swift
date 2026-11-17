import SwiftUI

struct RootView: View {
    let model: RootModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .task { await model.load() }
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
        case .home(let account):
            HomeView(account: account, signOut: model.signOut)
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
