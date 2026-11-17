import SwiftUI

/// "Continue with Apple" / "Continue with Google" in each brand's own button style.
///
/// Apple's HIG for a custom Sign in with Apple button: black in light mode and white in dark, the Apple logo and
/// title in one color, the system font, and no smaller or less prominent than other sign-in buttons. The native
/// `SignInWithAppleButton` can't be used: it starts `ASAuthorization`, but sign-in here goes through Cognito's web flow.
/// Google's button follows its branding guidelines: the four-color "G" on a neutral fill with a gray outline.
struct ProviderButton: View {
    let provider: IdentityProvider
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .headline) private var logo: CGFloat = 18

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                icon
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(colors.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(colors.fill, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(colors.stroke, lineWidth: 1) }
        }
        .buttonStyle(SignPressStyle())
    }

    private var title: String {
        provider == .apple ? "Continue with Apple" : "Continue with Google"
    }

    @ViewBuilder private var icon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .accessibilityHidden(true)
        case .google:
            Image("GoogleG")
                .resizable()
                .scaledToFit()
                .frame(width: logo, height: logo)
                .accessibilityHidden(true)
        }
    }

    private var colors: (fill: Color, text: Color, stroke: Color) {
        let dark = scheme == .dark
        switch provider {
        case .apple: return dark ? (.white, .black, .white) : (.black, .white, .black)
        case .google: return dark ? (Color(white: 0.075), Color(white: 0.89), Color(white: 0.56)) : (.white, Color(white: 0.12), Color(white: 0.46))
        }
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        ProviderButton(provider: .apple) {}
        ProviderButton(provider: .google) {}
    }
    .padding()
    .background(Palette.background)
}

#Preview("Dark") {
    VStack(spacing: Spacing.md) {
        ProviderButton(provider: .apple) {}
        ProviderButton(provider: .google) {}
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
