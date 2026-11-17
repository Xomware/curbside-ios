import SwiftUI

struct RootView: View {
    var body: some View {
        StreetSign(name: "Curbside")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
    }
}

#Preview {
    RootView()
}
