import SwiftUI

/// Signed-in home: the place's map, or place setup when the account has none yet. Household cards push by id.
struct HomeView: View {
    let signOut: () -> Void

    @State private var model: MapHomeModel
    @State private var path: [String] = []

    init(api: APIClient, signOut: @escaping () -> Void) {
        self.signOut = signOut
        _model = State(initialValue: MapHomeModel(api: api))
    }

    var body: some View {
        content
            .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .accessibilityLabel("Loading your map")
        case .failed:
            VStack(spacing: Spacing.md) {
                Text("Couldn't load your map.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                SignButton(title: "Try again") { Task { await model.load() } }
            }
            .padding(Spacing.md)
        case .noPlace:
            PlaceSetupView(api: model.api, created: model.show)
        case .ready:
            if let place = model.place {
                NavigationStack(path: $path) {
                    PlaceMap(model: model, place: place, signOut: signOut) { path.append($0.id) }
                        .navigationTitle("Block")
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: String.self) { id in
                            if let card = model.card(for: id) {
                                HouseholdView(model: card)
                            }
                        }
                }
                .tint(Palette.ink)
            }
        }
    }
}
