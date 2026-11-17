import CoreLocation

/// A household on a map. `mine` is the API's `private` block; `published` is the post-MVP card, always null for now.
struct Household: Decodable, Equatable, Identifiable, Sendable {
    /// `people`/`pets` are absent from PATCH responses and `notes` from map loads; nil means "not sent", not "none".
    struct Mine: Decodable, Equatable, Sendable {
        var label: String
        var address: String?
        var lastTalkedAt: String?
        var people: [Person]?
        var pets: [Pet]?
        var notes: [Note]?

        enum CodingKeys: String, CodingKey {
            case label, address, people, pets, notes
            case lastTalkedAt = "last_talked_at"
        }
    }

    /// Fields arrive with profile cards; until then only null vs. present matters.
    struct Published: Decodable, Equatable, Sendable {}

    let id: String
    var version: Int
    var lat: Double
    var lng: Double
    var buildingID: String?
    var mine: Mine
    var published: Published?

    enum CodingKeys: String, CodingKey {
        case id, version, lat, lng, published
        case buildingID = "building_id"
        case mine = "private"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// "11" from "11 Quillfeather Ln", "10A" from "10A Quillfeather Ln".
    var houseNumber: String? {
        guard let address = mine.address, let match = address.firstMatch(of: /^\d+[A-Za-z]?\b/) else { return nil }
        return String(match.output)
    }
}
