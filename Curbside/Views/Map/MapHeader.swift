import SwiftUI

/// The open street's sign with a household count, and a menu to switch streets, see who's on it, and reach settings.
struct MapHeader: View {
    let place: Place
    let places: [Place]
    let count: Int
    let open: (String) -> Void
    let sharing: () -> Void
    let settings: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StreetSign(name: place.name, detail: count == 1 ? "1 HOME" : "\(count) HOMES")
                // A wrapped name doubles the header's height over the map.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Menu {
                if places.count > 1 {
                    Picker("Street", selection: Binding(get: { place.id }, set: { open($0) })) {
                        ForEach(places) { street in
                            Text(street.name).tag(street.id)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Button("Sharing", systemImage: "person.2", action: sharing)
                Button("Settings", systemImage: "gearshape", action: settings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
            }
            .accessibilityLabel("More")
            .accessibilityHint(places.count > 1 ? "Switch streets, sharing and settings" : "Sharing and settings")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}
