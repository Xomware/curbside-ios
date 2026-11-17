import SwiftUI

/// "Who lives here": the nearest houses as overhead exit signs, nearest first.
struct NearMeSheet: View {
    let open: (Household) -> Void

    @State private var model: NearMeModel
    @State private var feed = LocationFeed()

    init(households: [Household], open: @escaping (Household) -> Void) {
        _model = State(initialValue: NearMeModel(households: households))
        self.open = open
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Next houses")
                        .font(CurbsideFont.signHeadline)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let heading = model.heading {
                        Text("FACING \(compassPoint(heading))")
                            .font(CurbsideFont.label)
                            .foregroundStyle(Palette.signInk)
                            .padding(Spacing.sm)
                            .signFace(Palette.signWhite, rule: Palette.signInk, cornerRadius: 5)
                    }
                }
                content
            }
            .padding(Spacing.md)
        }
        .background(Palette.background)
        .task { await model.run(feed.fixes()) }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .locating:
            ProgressView("Finding you")
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity)
        case .denied:
            Text("Location is off for Curbside. Turn it on in Settings, under Privacy & Security, Location Services.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
        case .ready where model.rows.isEmpty:
            Text("No households on this map yet.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
        case .ready:
            ForEach(model.rows) { row in
                Button { open(row.household) } label: { NearbyRow(row: row) }
                    .buttonStyle(SignPressStyle())
            }
        }
    }
}
