import CoreLocation
import Foundation
import Testing
@testable import Curbside

private let here = CLLocationCoordinate2D(latitude: 37.1, longitude: -122.1)

/// A household `label` at an offset from `here`, in degrees.
private func household(_ label: String, dLat: Double = 0, dLng: Double = 0) -> Household {
    var household = HouseholdFixtures.household()
    household = Household(id: label, version: 1, lat: here.latitude + dLat, lng: here.longitude + dLng, buildingID: nil, mine: household.mine, published: nil)
    household.mine.label = label
    return household
}

// Roughly 9 m east, 18 m west, 7 m north, 27 m south.
private let east = household("east", dLng: 0.0001)
private let west = household("west", dLng: -0.0002)
private let north = household("north", dLat: 0.00006)
private let south = household("south", dLat: -0.00024)
private let street = [south, west, east, north]

@Suite struct NearbyTests {
    @Test func nearestFirstAndCappedAtFive() {
        let far = (1...6).map { household("far\($0)", dLat: 0.01 * Double($0)) }
        let rows = Nearby.nearest(street + far, to: here, heading: nil)
        #expect(rows.map(\.household.mine.label) == ["north", "east", "west", "south", "far1"])
        #expect(rows.map(\.meters) == [7, 9, 18, 27, 1110])
    }

    @Test(arguments: [
        (0.0, ["east": Nearby.Side.right, "west": .left]),
        (180.0, ["east": .left, "west": .right]),
        (90.0, ["north": .left, "south": .right]),
        (270.0, ["north": .right, "south": .left]),
        (350.0, ["east": .right, "west": .left]),
    ])
    func sideFollowsWhichWayYouFace(_ heading: Double, _ expected: [String: Nearby.Side]) {
        let sides = Dictionary(uniqueKeysWithValues: Nearby.nearest(street, to: here, heading: heading).map { ($0.household.mine.label, $0.side) })
        for (label, side) in expected {
            #expect(sides[label] == side, "\(label) facing \(heading)")
        }
    }

    @Test func noHeadingMeansNoSide() {
        #expect(Nearby.nearest(street, to: here, heading: nil).allSatisfy { $0.side == nil })
    }

    @Test(arguments: [(0.0, "NORTH"), (89.0, "EAST"), (200.0, "SOUTH"), (-90.0, "WEST"), (337.6, "NORTH"), (300.0, "NORTHWEST")])
    func compassPoints(_ degrees: Double, _ point: String) {
        #expect(compassPoint(degrees) == point)
    }
}

@MainActor @Suite struct NearMeModelTests {
    private func stream(_ fixes: [Fix]) -> AsyncStream<Fix> {
        AsyncStream { continuation in
            fixes.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    @Test func eachFixResortsTheRows() async {
        let model = NearMeModel(households: street)
        await model.run(stream([.at(here, heading: 0), .at(south.coordinate, heading: nil)]))
        #expect(model.state == .ready)
        #expect(model.rows.first?.household.mine.label == "south")
        #expect(model.heading == nil)
    }

    @Test func deniedSaysSo() async {
        let model = NearMeModel(households: street)
        await model.run(stream([.denied]))
        #expect(model.state == .denied)
        #expect(model.rows.isEmpty)
    }

    @Test func emptyMapIsReadyWithNoRows() async {
        let model = NearMeModel(households: [])
        await model.run(stream([.at(here, heading: 90)]))
        #expect(model.state == .ready)
        #expect(model.rows.isEmpty)
    }
}
