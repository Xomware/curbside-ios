import CoreLocation
import Foundation
import Observation

/// Loads the open street and its households. An account can have several (its own and ones shared with it); the open
/// one is remembered by id, falling back to the first in `GET /maps`.
@MainActor @Observable
final class MapHomeModel {
    nonisolated static let openKey = "openMapID"

    enum State: Equatable {
        case loading
        case noPlace
        case ready
        case failed
    }

    private(set) var state = State.loading
    private(set) var places: [Place] = []
    private(set) var place: Place?
    private(set) var households: [Household] = []
    /// Empty until the file loads, and for good when the place has none; households then stand alone as pins.
    private(set) var footprints: [Footprint] = []
    private(set) var selection: Spot?

    let api: APIClient
    private let footprintLoader: FootprintLoader
    private let geo: Geo
    private let defaults: UserDefaults
    private let pollInterval: Duration

    init(
        api: APIClient,
        footprintLoader: FootprintLoader? = nil,
        geo: Geo = .live,
        defaults: UserDefaults = .standard,
        pollInterval: Duration = .seconds(3)
    ) {
        self.api = api
        self.footprintLoader = footprintLoader ?? FootprintLoader(api: api)
        self.geo = geo
        self.defaults = defaults
        self.pollInterval = pollInterval
    }

    /// Households in the selected building. Duplexes and apartments put several in one outline.
    var selectedHouseholds: [Household] {
        guard let id = selection?.buildingID else { return [] }
        return households.filter { $0.buildingID == id }
    }

    func load() async {
        state = .loading
        do {
            places = try await api.request("/v1/maps")
            // The remembered street may be gone: left, removed by its owner, or deleted.
            let remembered = defaults.string(forKey: Self.openKey)
            guard let open = places.first(where: { $0.id == remembered }) ?? places.first else {
                state = .noPlace
                return
            }
            let loaded: Loaded = try await api.request("/v1/maps/\(open.id)")
            place = loaded.map
            households = loaded.households
            footprints = []
            selection = nil
            state = .ready
        } catch APIError.unauthorized {
            // APIClient signed out; RootModel's route follows.
        } catch {
            state = .failed
        }
    }

    /// Switches streets; nil forgets the open one, so the first left in `GET /maps` opens, or place setup.
    func open(_ id: String?) async {
        defaults.set(id, forKey: Self.openKey)
        await load()
    }

    /// A place just created: no households yet, footprints still pending.
    func show(_ place: Place) {
        places.append(place)
        defaults.set(place.id, forKey: Self.openKey)
        self.place = place
        households = []
        footprints = []
        state = .ready
    }

    /// A tap selects the building under it. Anywhere else (open ground, a shed, a street with no outlines yet) it drops
    /// a pin, so a house can always be added where the user taps.
    func tap(_ coordinate: CLLocationCoordinate2D) async {
        let building = footprints.first { !$0.accessory && $0.contains(coordinate) }
        await select(Spot(coordinate, buildingID: building?.id))
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

    /// A new street's outlines take a few seconds to fetch, so a pending file is asked about again, for about a minute.
    /// Runs from the map's `.task`, which cancels it when the street changes.
    func loadFootprints() async {
        guard footprints.isEmpty, let place else { return }
        for attempt in 0..<20 {
            if attempt > 0 {
                try? await Task.sleep(for: pollInterval)
            }
            guard !Task.isCancelled, self.place?.id == place.id else { return }
            do {
                guard let loaded = try await footprintLoader.load(place) else { continue }
                footprints = loaded
            } catch {
                // Pins only, which is the designed fallback; the next appear tries again.
                footprints = []
            }
            return
        }
    }
}

private struct Loaded: Decodable, Sendable {
    let map: Place
    let households: [Household]
}
