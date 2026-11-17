import CoreLocation
import Observation

/// Picks a center (current location or a searched address), a radius and a name, then creates the map.
@MainActor @Observable
final class PlaceSetupModel {
    static let radii = [150, 300, 500]

    var name = ""
    var radius = 300
    var query = ""
    private(set) var center: CLLocationCoordinate2D?
    private(set) var isBusy = false
    private(set) var message: String?

    private let api: APIClient
    private let geo: Geo

    init(api: APIClient, geo: Geo = .live) {
        self.api = api
        self.geo = geo
    }

    var canCreate: Bool {
        center != nil && RootModel.validName(name) != nil && !isBusy
    }

    func useMyLocation() async {
        await pick {
            let coordinate = try await geo.locate()
            return (coordinate, await geo.address(coordinate))
        }
    }

    func search() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        await pick { try await geo.search(query) }
    }

    /// The created place, or nil with `message` set.
    func create() async -> Place? {
        guard let center, let name = RootModel.validName(name) else { return nil }
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            let body = NewPlace(name: name, center: .init(lat: center.latitude, lng: center.longitude), radiusM: radius)
            return try await api.request("/v1/maps", method: "POST", body: body)
        } catch {
            message = "Couldn't make the map. Try again."
            return nil
        }
    }

    private func pick(_ find: () async throws -> (CLLocationCoordinate2D, String?)) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            let (coordinate, address) = try await find()
            center = coordinate
            if name.isEmpty, let address { name = Geo.street(from: address) }
        } catch Geo.Failure.denied {
            message = "Location is off for Curbside. Search for your address instead, or turn it on in Settings."
        } catch Geo.Failure.notFound {
            message = "No match for that address."
        } catch {
            message = "Couldn't find that. Try again."
        }
    }
}

private struct NewPlace: Encodable, Sendable {
    let name: String
    let center: Place.Center
    let radiusM: Int

    enum CodingKeys: String, CodingKey {
        case name, center
        case radiusM = "radius_m"
    }
}
