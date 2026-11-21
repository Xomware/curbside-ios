import SwiftUI

/// The open street's sign with a household count, the activity bell, and a menu to switch streets, see who's on it, and reach settings.
struct MapHeader: View {
    let place: Place
    let places: [Place]
    let count: Int
    let unread: Int
    let open: (String) -> Void
    let activity: () -> Void
    let sharing: () -> Void
    let friends: () -> Void
    let settings: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StreetSign(name: place.name, detail: count == 1 ? "1 HOME" : "\(count) HOMES")
                // A wrapped name doubles the header's height over the map.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Button(action: activity) {
                Image(systemName: "bell")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        if unread > 0 {
                            Text(unread > 9 ? "9+" : "\(unread)")
                                .font(CurbsideFont.label)
                                .foregroundStyle(Palette.signWhite)
                                .padding(.horizontal, Spacing.xs)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Palette.stop, in: .capsule)
                                .offset(x: Spacing.xs, y: -Spacing.xs)
                        }
                    }
            }
            .buttonStyle(SignPressStyle())
            .accessibilityLabel(unread > 0 ? "Activity, \(unread) new" : "Activity")
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
                Button("Friends", systemImage: "person.crop.circle.badge.checkmark", action: friends)
                Button("Settings", systemImage: "gearshape", action: settings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
            }
            .accessibilityLabel("More")
            .accessibilityHint(places.count > 1 ? "Switch streets, sharing, friends and settings" : "Sharing, friends and settings")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}
