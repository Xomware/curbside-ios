import CoreLocation
import Foundation
import Testing
@testable import Curbside

private func at(_ lat: Double, _ lng: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lng)
}

// Points against FootprintFixtures: way/11 has a courtyard hole, way/12 is an accessory shed, relation/13 has two parts.
private let house = at(37.10001, -122.09999)
private let courtyard = at(37.1001, -122.0999)
private let shed = at(37.10002, -122.09968)
private let secondPart = at(37.10005, -122.09875)
private let street = at(37.2, -122.2)

@Suite struct HitTestTests {
    let footprints = try! Footprint.decode(Data(FootprintFixtures.geojson.utf8))

    @Test func insideTheOutlineHits() {
        #expect(footprints[0].contains(house))
    }

    @Test func holesAndOpenGroundMiss() {
        #expect(!footprints[0].contains(courtyard))
        #expect(!footprints.contains { $0.contains(street) })
    }

    @Test func anyPartOfARelationHits() {
        #expect(footprints[2].contains(secondPart))
    }
}

/// Two households in way/11 (a duplex), loaded through the real map and footprint requests.
@MainActor
private func loadedModel(address: @escaping @Sendable (CLLocationCoordinate2D) async -> String? = { _ in "11 Quillfeather Ln" }) async -> MapHomeModel {
    let second = MapFixtures.household
        .replacingOccurrences(of: "01M7MYZ2HN482TDYCDP6CB5D9W", with: "01M7MYZ2HN482TDYCDP6CB5D9X")
        .replacingOccurrences(of: #""label": "Pumpernickel""#, with: #""label": "Wigglesworth""#)
    let body = #"{"data": {"map": \#(MapFixtures.place), "households": [\#(MapFixtures.household), \#(second)]}, "error": null, "meta": {}}"#
        .replacingOccurrences(of: #""building_id": "osm:way/1""#, with: #""building_id": "osm:way/11""#)
    let api = stubAPI([
        MapFixtures.list,
        .init(status: 200, body: body),
        FootprintFixtures.info("ready", version: 1, url: "https://bucket.example.test/v1.geojson.gz"),
        .init(status: 200, data: FootprintFixtures.gzipped),
    ])
    let geo = Geo(locate: { street }, search: { _ in (street, nil) }, address: address)
    let loader = FootprintLoader(api: api, cache: URL.temporaryDirectory.appending(path: "footprints-\(UUID())"))
    let model = MapHomeModel(api: api, footprintLoader: loader, geo: geo)
    await model.load()
    return model
}

extension StubbedNetwork {
    @MainActor @Suite struct SelectionTests {
        @Test func tappingABuildingListsEveryHouseholdInIt() async {
            let model = await loadedModel()
            await model.tap(house)
            #expect(model.selection?.buildingID == "osm:way/11")
            #expect(model.selection?.address == "11 Quillfeather Ln")
            #expect(model.selectedHouseholds.map(\.mine.label) == ["Pumpernickel", "Wigglesworth"])
        }

        @Test func emptyBuildingSelectsWithNobodyInIt() async {
            let model = await loadedModel()
            await model.tap(secondPart)
            #expect(model.selection?.buildingID == "osm:relation/13")
            #expect(model.selectedHouseholds.isEmpty)
        }

        @Test(arguments: [shed, courtyard, street])
        func accessoryHoleOrOpenGroundClearsTheSelection(_ point: CLLocationCoordinate2D) async {
            let model = await loadedModel()
            await model.tap(house)
            await model.tap(point)
            #expect(model.selection == nil)
        }

        @Test func longPressDropsAPinWithItsAddress() async {
            let model = await loadedModel(address: { _ in "40 Bramblewick Ct" })
            await model.drop(street)
            #expect(model.selection?.buildingID == nil)
            #expect(model.selection?.coordinate.latitude == street.latitude)
            #expect(model.selection?.address == "40 Bramblewick Ct")
        }

        @Test func noAddressStillDropsThePin() async {
            let model = await loadedModel(address: { _ in nil })
            await model.drop(street)
            #expect(model.selection != nil)
            #expect(model.selection?.address == nil)
        }
    }
}
