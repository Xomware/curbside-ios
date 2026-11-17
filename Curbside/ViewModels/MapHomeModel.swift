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

    let api: APIClient

    init(api: APIClient) {
        self.api = api
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
        } catch APIError.unauthorized {
            // APIClient signed out; RootModel's route follows.
        } catch {
            state = .failed
        }
    }

    /// A place just created: no households yet.
    func show(_ place: Place) {
        self.place = place
        households = []
        state = .ready
    }
}

private struct Loaded: Decodable, Sendable {
    let map: Place
    let households: [Household]
}
