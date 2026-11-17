import MapKit
import SwiftUI

/// The block: a muted map with one house plaque per household and the place's street sign on top.
struct PlaceMap: View {
    let place: Place
    let households: [Household]
    let footprints: [Footprint]
    let signOut: () -> Void

    @State private var position: MapCameraPosition
    @State private var showsNames = true

    init(place: Place, households: [Household], footprints: [Footprint], signOut: @escaping () -> Void) {
        self.place = place
        self.households = households
        self.footprints = footprints
        self.signOut = signOut
        _position = State(initialValue: .region(place.region))
    }

    var body: some View {
        Map(position: $position) {
            ForEach(footprints) { footprint in
                ForEach(footprint.polygons, id: \.self) { polygon in
                    MapPolygon(polygon)
                        .foregroundStyle(footprint.accessory ? Palette.roofAccessory : Palette.roof)
                        .stroke(.black.opacity(0.3), lineWidth: 0.5)
                }
            }
            ForEach(households) { household in
                Annotation(household.mine.label, coordinate: household.coordinate) {
                    HousePlaque(number: household.houseNumber, name: household.mine.label, size: showsNames ? .pin : .tab)
                        // Past .large a plaque covers its neighbours' houses (S3's AX2 gallery).
                        .dynamicTypeSize(...DynamicTypeSize.large)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        // Past ~400 m of altitude, houses sit closer than a name blade is wide.
        .onMapCameraChange { showsNames = $0.camera.distance < 400 }
        .safeAreaInset(edge: .top) { header }
        .overlay(alignment: .bottom) {
            if households.isEmpty {
                YardSign(text: "NOBODY ADDED YET", kind: .panel)
                    .padding(Spacing.md)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !footprints.isEmpty {
                // ODbL: the outlines are OSM data, so the credit sits on the map wherever they are drawn.
                Text("© OpenStreetMap contributors")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 3))
                    .padding(Spacing.sm)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            StreetSign(name: place.name, detail: households.count == 1 ? "1 HOME" : "\(households.count) HOMES")
            Menu {
                Button("Sign out", role: .destructive, action: signOut)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 48, height: 48)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(SignPressStyle())
            .accessibilityLabel("Map options")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }
}
