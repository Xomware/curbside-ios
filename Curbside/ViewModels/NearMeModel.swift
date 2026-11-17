import Observation
import os

/// The near-me sheet: the five closest households, re-sorted on every fix.
@MainActor @Observable
final class NearMeModel {
    enum State: Equatable {
        case locating
        case denied
        case ready
    }

    private(set) var state = State.locating
    private(set) var rows: [Nearby] = []
    private(set) var heading: Double?

    private let households: [Household]
    // Open → first rows, for the plan's 1 s check. Instruments: Points of Interest.
    private let signposter = OSSignposter(subsystem: "com.Xomware.Curbside", category: .pointsOfInterest)

    init(households: [Household]) {
        self.households = households
    }

    func run(_ fixes: AsyncStream<Fix>) async {
        let interval = signposter.beginInterval("NearMe")
        var first = true
        for await fix in fixes {
            guard case let .at(coordinate, heading) = fix else {
                state = .denied
                continue
            }
            self.heading = heading
            rows = Nearby.nearest(households, to: coordinate, heading: heading)
            state = .ready
            if first {
                signposter.endInterval("NearMe", interval)
                first = false
            }
        }
    }
}
