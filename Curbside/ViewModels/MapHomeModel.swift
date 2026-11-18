import CoreLocation
import Foundation
import Observation

/// Loads the account's place and its households. MVP has one place per account: the first map in `GET /maps`.
@MainActor @Observable
final class MapHomeModel {
    enum State: Equatable {
        case loading
        case noPlace
        case ready
        case failed
    }

    private(set) var state = State.loading
    private(set) var place: Place?
    private(set) var households: [Household] = []
    /// Empty until the file loads, and for good when the place has none; households then stand alone as pins.
    private(set) var footprints: [Footprint] = []
    private(set) var selection: Spot?

    let api: APIClient
    private let footprintLoader: FootprintLoader
    private let geo: Geo

    init(api: APIClient, footprintLoader: FootprintLoader? = nil, geo: Geo = .live) {
        self.api = api
        self.footprintLoader = footprintLoader ?? FootprintLoader(api: api)
        self.geo = geo
    }

    /// Households in the selected building. Duplexes and apartments put several in one outline.
    var selectedHouseholds: [Household] {
        guard let id = selection?.buildingID else { return [] }
        return households.filter { $0.buildingID == id }
    }

    func load() async {
        state = .loading
        do {
            let places: [Place] = try await api.request("/v1/maps")
            guard let first = places.first else {
                state = .noPlace
                return
            }
            let loaded: Loaded = try await api.request("/v1/maps/\(first.id)")
            place = loaded.map
            households = loaded.households
            state = .ready
            await loadFootprints()
        } catch APIError.unauthorized {
            // APIClient signed out; RootModel's route follows.
        } catch {
            state = .failed
        }
    }

    /// A place just created: no households yet, footprints still pending.
    func show(_ place: Place) {
        self.place = place
        households = []
        footprints = []
        state = .ready
    }

    /// A tap selects the building under it; accessory buildings and open ground clear the selection.
    func tap(_ coordinate: CLLocationCoordinate2D) async {
        guard let building = footprints.first(where: { !$0.accessory && $0.contains(coordinate) }) else {
            selection = nil
            return
        }
        await select(Spot(coordinate, buildingID: building.id))
    }

    /// A long-press drops a pin anywhere: the fallback for houses with no outline.
    func drop(_ coordinate: CLLocationCoordinate2D) async {
        await select(Spot(coordinate, buildingID: nil))
    }

    /// The card for a household on this map, wired to keep the map's copy current.
    func card(for id: String) -> HouseholdModel? {
        guard let place, let household = households.first(where: { $0.id == id }) else { return nil }
        return HouseholdModel(household: household, mapID: place.id, api: api) { [weak self] in self?.upsert($0) }
    }

    /// Capture centred on the picked building or pin, if any. Its first household is the one being talked about.
    func capture() -> CaptureModel? {
        guard let place else { return nil }
        return CaptureModel(place: place, households: households, selection: selection, focus: selectedHouseholds.first, api: api, geo: geo)
    }

    /// Picks up what a capture wrote. Apply answers with ids only, so the map is the cheapest complete copy.
    func refresh() async {
        guard let place else { return }
        // A failed refresh leaves the old pins; the next load catches up, and the capture itself already saved.
        guard let loaded: Loaded = try? await api.request("/v1/maps/\(place.id)") else { return }
        households = loaded.households
        selection = nil
    }

    func upsert(_ household: Household) {
        if let index = households.firstIndex(where: { $0.id == household.id }) {
            households[index] = household
        } else {
            households.append(household)
        }
    }

    func added(_ household: Household) {
        upsert(household)
        selection = nil
    }

    func clearSelection() {
        selection = nil
    }

    private func select(_ spot: Spot) async {
        selection = spot
        let address = await geo.address(spot.coordinate)
        // A newer tap may have landed while Apple answered.
        guard selection == spot else { return }
        selection?.address = address
    }

    func loadFootprints() async {
        guard let place else { return }
        // Any failure leaves pins only, which is the designed fallback; the next appear tries again.
        footprints = (try? await footprintLoader.load(place)) ?? []
    }
}

private struct Loaded: Decodable, Sendable {
    let map: Place
    let households: [Household]
}
