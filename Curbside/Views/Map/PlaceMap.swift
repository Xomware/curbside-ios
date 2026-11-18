import MapKit
import SwiftUI

/// The block: a muted map with building outlines, one house plaque per household, and the place's street sign on top.
/// Tap a building to pick it; long-press anywhere to drop a pin where there is no outline.
struct PlaceMap: View {
    let model: MapHomeModel
    let place: Place
    let settings: () -> Void
    let open: (Household) -> Void

    @State private var position: MapCameraPosition
    @State private var showsNames = true
    @State private var adding: Spot?
    @State private var nearMe = false
    @State private var capturing: CaptureModel?

    init(model: MapHomeModel, place: Place, settings: @escaping () -> Void, open: @escaping (Household) -> Void) {
        self.model = model
        self.place = place
        self.settings = settings
        self.open = open
        _position = State(initialValue: .region(place.region))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(model.footprints) { footprint in
                    let selected = footprint.id == model.selection?.buildingID
                    ForEach(footprint.polygons, id: \.self) { polygon in
                        MapPolygon(polygon)
                            .foregroundStyle(selected ? Palette.warning.opacity(0.6) : footprint.accessory ? Palette.roofAccessory : Palette.roof)
                            .stroke(selected ? Palette.warning : .black.opacity(0.3), lineWidth: selected ? 2 : 0.5)
                    }
                }
                ForEach(model.households) { household in
                    Annotation(household.mine.label, coordinate: household.coordinate) {
                        Button { open(household) } label: {
                            HousePlaque(number: household.houseNumber, name: household.mine.label, size: showsNames ? .pin : .tab)
                                // Past .large a plaque covers its neighbours' houses (S3's AX2 gallery).
                                .dynamicTypeSize(...DynamicTypeSize.large)
                        }
                        .buttonStyle(SignPressStyle())
                    }
                    .annotationTitles(.hidden)
                }
                if let spot = model.selection, spot.buildingID == nil {
                    Annotation("Dropped pin", coordinate: spot.coordinate) {
                        HousePlaque(number: nil, name: nil, size: .pin)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            // Past ~400 m of altitude, houses sit closer than a name blade is wide.
            .onMapCameraChange { showsNames = $0.camera.distance < 400 }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                Task { await model.tap(coordinate) }
            }
            // Ends on finger lift: the only way to get a location out of a SwiftUI long-press.
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).sequenced(before: DragGesture(minimumDistance: 0)).onEnded { value in
                guard case .second(true, let drag?) = value, let coordinate = proxy.convert(drag.location, from: .local) else { return }
                Task { await model.drop(coordinate) }
            })
        }
        .sensoryFeedback(.selection, trigger: model.selection)
        .safeAreaInset(edge: .top) { MapHeader(name: place.name, count: model.households.count, settings: settings) }
        .safeAreaInset(edge: .bottom) { bottom }
        .sheet(item: $adding) { spot in
            NewHouseholdView(model: NewHouseholdModel(spot: spot, mapID: place.id, api: model.api)) { household in
                model.added(household)
                open(household)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $nearMe) {
            NearMeSheet(households: model.households) { household in
                nearMe = false
                open(household)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $capturing) { capture in
            CaptureView(model: capture, place: place, footprints: model.footprints) { await model.refresh() }
        }
    }

    private func talk() {
        capturing = model.capture()
    }

    @ViewBuilder private var bottom: some View {
        if let spot = model.selection {
            SelectionPanel(spot: spot, households: model.selectedHouseholds, open: open, add: { adding = spot }, talk: talk, close: model.clearSelection)
        } else {
            MapDock(isEmpty: model.households.isEmpty, showsCredit: !model.footprints.isEmpty, nearMe: { nearMe = true }, talk: talk)
        }
    }
}
