import MapKit
import SwiftUI

/// Where a house the capture created goes: tap its outline, or open ground where there is none.
struct PlacePicker: View {
    let place: Place
    let footprints: [Footprint]
    let households: [Household]
    let label: String
    let done: (Spot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var spot: Spot?

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(initialPosition: .region(place.region)) {
                    ForEach(footprints) { footprint in
                        let picked = footprint.id == spot?.buildingID
                        ForEach(footprint.polygons, id: \.self) { polygon in
                            MapPolygon(polygon)
                                .foregroundStyle(picked ? Palette.warning.opacity(0.6) : footprint.accessory ? Palette.roofAccessory : Palette.roof)
                                .stroke(picked ? Palette.warning : .black.opacity(0.3), lineWidth: picked ? 2 : 0.5)
                        }
                    }
                    ForEach(households) { household in
                        Annotation(household.mine.label, coordinate: household.coordinate) {
                            HousePlaque(number: household.houseNumber, name: household.mine.label, size: .tab)
                                .dynamicTypeSize(...DynamicTypeSize.large)
                        }
                        .annotationTitles(.hidden)
                    }
                    if let spot, spot.buildingID == nil {
                        Annotation(label, coordinate: spot.coordinate) { HousePlaque(number: nil, name: nil, size: .pin) }
                            .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    let building = footprints.first { !$0.accessory && $0.contains(coordinate) }
                    spot = Spot(coordinate, buildingID: building?.id)
                }
                .sensoryFeedback(.selection, trigger: spot)
            }
            .safeAreaInset(edge: .top) {
                Text("Tap where \(label) is.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.sm)
                    .background(Palette.surface)
            }
            .overlay(alignment: .bottomTrailing) {
                if !footprints.isEmpty {
                    Text("© OpenStreetMap contributors")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(Spacing.sm)
                }
            }
            .navigationTitle("Place it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Put it here") {
                        if let spot { done(spot) }
                        dismiss()
                    }
                    .disabled(spot == nil)
                }
            }
        }
    }
}
