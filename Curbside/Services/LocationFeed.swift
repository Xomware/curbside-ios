import CoreLocation

/// Location plus which way the user faces, for the near-me sheet. When-in-use only.
enum Fix: Equatable {
    case denied
    /// `heading` is the compass when the device has one, else course while walking, else nil.
    case at(CLLocationCoordinate2D, heading: Double?)

    static func == (a: Fix, b: Fix) -> Bool {
        switch (a, b) {
        case (.denied, .denied): true
        case let (.at(x, h1), .at(y, h2)): x.latitude == y.latitude && x.longitude == y.longitude && h1 == h2
        default: false
        }
    }
}

/// `CLLocationUpdate` has no heading, so this is a delegate-backed `CLLocationManager` instead.
@MainActor
final class LocationFeed: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<Fix>.Continuation?
    private var compass: Double?

    func fixes() -> AsyncStream<Fix> {
        AsyncStream { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.manager.stopUpdatingLocation()
                    self.manager.stopUpdatingHeading()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            let heading = compass ?? (location.course >= 0 ? location.course : nil)
            continuation?.yield(.at(location.coordinate, heading: heading))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        let degrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        MainActor.assumeIsolated { compass = degrees }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            if status == .denied || status == .restricted { continuation?.yield(.denied) }
        }
    }
}
