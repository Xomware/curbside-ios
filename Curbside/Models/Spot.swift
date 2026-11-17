import CoreLocation

/// What the user picked on the map: a building's outline, or a long-press where there is none.
struct Spot: Equatable, Identifiable {
    let lat: Double
    let lng: Double
    let buildingID: String?
    /// Short address from reverse geocoding; nil until it arrives, or when Apple has none.
    var address: String?

    init(_ coordinate: CLLocationCoordinate2D, buildingID: String?) {
        lat = coordinate.latitude
        lng = coordinate.longitude
        self.buildingID = buildingID
    }

    var id: String { "\(lat),\(lng)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
