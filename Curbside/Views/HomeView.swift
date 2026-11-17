import SwiftUI

/// Placeholder until the map lands.
struct HomeView: View {
    let account: Account
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            StreetSign(name: account.displayName)
            Text("Your map is on its way.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.inkSecondary)
            Spacer()
            SignButton(title: "Sign out", action: signOut)
        }
        .padding(Spacing.md)
    }
}

#Preview {
    HomeView(account: Account(accountID: "a1", displayName: "Pumpernickel")) {}
        .background(Palette.background)
}
