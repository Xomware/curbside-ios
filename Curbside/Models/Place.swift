import MapKit

/// A map in the API: one place, its center and radius, and the state of its footprint file.
struct Place: Decodable, Equatable, Identifiable, Sendable {
    struct Center: Codable, Equatable, Sendable {
        let lat: Double
        let lng: Double
    }

    struct Footprint: Decodable, Equatable, Sendable {
        enum Status: String, Decodable, Sendable {
            case pending, ready, empty, failed
        }

        let status: Status
        let version: Int
    }

    /// The caller's role. A member edits everything on the street; only the owner renames, deletes, invites and removes.
    enum Role: String, Decodable, Sendable {
        case owner, member
    }

    let id: String
    let name: String
    let center: Center
    let radiusM: Int
    let footprint: Footprint
    let version: Int
    let role: Role

    enum CodingKeys: String, CodingKey {
        case id, name, center, footprint, version, role
        case radiusM = "radius_m"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: center.lat, longitude: center.lng)
    }

    /// Opens on the middle of the place, not all of it: at the full radius every plaque is a dot.
    var region: MKCoordinateRegion {
        let span = CLLocationDistance(radiusM)
        return MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: span,
            longitudinalMeters: span
        )
    }
}
