import CoreLocation

/// A household near the user, which side of the street it is on, and how far.
struct Nearby: Identifiable, Equatable {
    enum Side: Equatable {
        case left, right
    }

    let household: Household
    let meters: Int
    /// Nil without a heading: there is no "left" when we don't know which way you face.
    let side: Side?

    var id: String { household.id }

    /// The nearest `limit` households, nearest first. `heading` is degrees clockwise from true north.
    static func nearest(_ households: [Household], to here: CLLocationCoordinate2D, heading: Double?, limit: Int = 5) -> [Nearby] {
        let origin = CLLocation(latitude: here.latitude, longitude: here.longitude)
        let all = households
            .map { household in
                let there = CLLocation(latitude: household.lat, longitude: household.lng)
                let side = heading.map { relative(bearing(from: here, to: household.coordinate) - $0) < 0 ? Side.left : .right }
                return Nearby(household: household, meters: Int(origin.distance(from: there).rounded()), side: side)
            }
            .sorted { $0.meters < $1.meters }
        return Array(all.prefix(limit))
    }

    /// Initial great-circle bearing, degrees clockwise from north.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let (lat1, lat2) = (a.latitude * .pi / 180, b.latitude * .pi / 180)
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return atan2(y, x) * 180 / .pi
    }

    /// Folds an angle into -180..<180.
    private static func relative(_ degrees: Double) -> Double {
        let folded = (degrees + 180).truncatingRemainder(dividingBy: 360)
        return (folded < 0 ? folded + 360 : folded) - 180
    }
}

/// "EAST" for 90. Eight points are plenty for which way you're facing on a sidewalk.
func compassPoint(_ degrees: Double) -> String {
    let points = ["NORTH", "NORTHEAST", "EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST"]
    let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5) / 45).rounded(.down)) % 8
    return points[index]
}
