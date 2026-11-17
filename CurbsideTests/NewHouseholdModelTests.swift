import CoreLocation
import Foundation
import Testing
@testable import Curbside

private let created = StubURLProtocol.Reply(status: 201, body: #"{"data": \#(MapFixtures.household), "error": null, "meta": {}}"#)

private func spot(building: String?, address: String?) -> Spot {
    var spot = Spot(CLLocationCoordinate2D(latitude: 37.1, longitude: -122.1), buildingID: building)
    spot.address = address
    return spot
}

private func sentBody() throws -> NSDictionary? {
    let post = try #require(StubURLProtocol.requests.withLock { $0.first })
    #expect(post.httpMethod == "POST")
    #expect(post.url?.path() == "/v1/maps/\(MapFixtures.mapID)/households")
    return try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: post).utf8)) as? NSDictionary
}

extension StubbedNetwork {
    @MainActor @Suite struct NewHouseholdModelTests {
        @Test func prefillsTheGeocodedAddress() {
            let model = NewHouseholdModel(spot: spot(building: "osm:way/11", address: "11 Quillfeather Ln"), mapID: MapFixtures.mapID, api: stubAPI([]))
            #expect(model.address == "11 Quillfeather Ln")
            #expect(!model.canSave)
            model.label = "Pumpernickel"
            #expect(model.canSave)
        }

        @Test func postsBuildingAndCoordinate() async throws {
            let model = NewHouseholdModel(spot: spot(building: "osm:way/11", address: "11 Quillfeather Ln"), mapID: MapFixtures.mapID, api: stubAPI([created]))
            model.label = " Pumpernickel "
            let household = await model.save()
            #expect(household?.mine.label == "Pumpernickel")
            #expect(try sentBody() == ["label": "Pumpernickel", "address": "11 Quillfeather Ln", "lat": 37.1, "lng": -122.1, "building_id": "osm:way/11"] as NSDictionary)
        }

        @Test func droppedPinWithNoAddressLeavesBothOut() async throws {
            let model = NewHouseholdModel(spot: spot(building: nil, address: nil), mapID: MapFixtures.mapID, api: stubAPI([created]))
            model.label = "Pumpernickel"
            _ = await model.save()
            #expect(try sentBody() == ["label": "Pumpernickel", "lat": 37.1, "lng": -122.1] as NSDictionary)
        }

        @Test func rejectedSaveSaysSo() async {
            let model = NewHouseholdModel(spot: spot(building: nil, address: nil), mapID: MapFixtures.mapID, api: stubAPI([.init(status: 500, body: "{}")]))
            model.label = "Pumpernickel"
            #expect(await model.save() == nil)
            #expect(model.message == "Couldn't add them. Try again.")
        }

        @Test func addedHouseholdJoinsTheMapAndClearsTheSelection() async throws {
            let map = MapHomeModel(api: stubAPI([MapFixtures.none]))
            await map.load()
            map.added(HouseholdFixtures.household())
            #expect(map.households.map(\.id) == [HouseholdFixtures.id])
            #expect(map.selection == nil)
        }
    }
}
