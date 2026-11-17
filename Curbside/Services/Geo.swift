import CoreLocation
import MapKit

/// Location and geocoding, as closures so view models can be tested without CoreLocation or Apple's servers.
struct Geo: Sendable {
    enum Failure: Error {
        case denied
        case notFound
    }

    /// One when-in-use fix. The permission prompt appears here, on first use.
    var locate: @Sendable () async throws -> CLLocationCoordinate2D
    /// First result for a typed address, with its short address ("11 Quillfeather Ln").
    var search: @Sendable (String) async throws -> (CLLocationCoordinate2D, String?)
    /// Short address at a coordinate, if Apple has one.
    var address: @Sendable (CLLocationCoordinate2D) async -> String?

    static let live = Geo(
        locate: {
            let session = CLServiceSession(authorization: .whenInUse)
            defer { session.invalidate() }
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally { throw Failure.denied }
                if let location = update.location { return location.coordinate }
            }
            throw Failure.denied
        },
        search: { query in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { throw Failure.notFound }
            return (item.location.coordinate, item.address?.shortAddress)
        },
        address: { coordinate in
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            // A failed lookup only means no prefill; the user types the address instead.
            let items = try? await MKReverseGeocodingRequest(location: location)?.mapItems
            return items?.first?.address?.shortAddress
        }
    )

    /// "Quillfeather Ln" from "11 Quillfeather Ln" or "Quillfeather Ln, Springfield".
    static func street(from address: String) -> String {
        let line = address.split(separator: ",").first.map(String.init) ?? address
        return line.replacing(/^\d+[A-Za-z]?\s+/, with: "")
    }
}
