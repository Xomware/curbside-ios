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

    let api: APIClient
    private let footprintLoader: FootprintLoader

    init(api: APIClient, footprintLoader: FootprintLoader? = nil) {
        self.api = api
        self.footprintLoader = footprintLoader ?? FootprintLoader(api: api)
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
