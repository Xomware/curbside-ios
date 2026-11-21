import CoreLocation
import Foundation
import Testing
@testable import Curbside

private let spot = CLLocationCoordinate2D(latitude: 37.4475, longitude: -122.1395)

private func geo(locate: Result<CLLocationCoordinate2D, Geo.Failure> = .success(spot), address: String? = "11 Quillfeather Ln") -> Geo {
    Geo(
        locate: { try locate.get() },
        search: { _ in (spot, "9 Bramblewick Ct") },
        address: { _ in address }
    )
}

private let placeCreated = StubURLProtocol.Reply(status: 201, body: #"{"data": \#(MapFixtures.place), "error": null, "meta": {}}"#)
private let homeCreated = StubURLProtocol.Reply(status: 201, body: #"{"data": \#(MapFixtures.household), "error": null, "meta": {}}"#)
private let homeID = "01M7MYZ2HN482TDYCDP6CB5D9W"
private let personCreated = StubURLProtocol.Reply(status: 201, body: #"{"data": {"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "name": "Juniper", "role": "kid", "birth_year": null, "birth_year_approx": false, "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}, "error": null, "meta": {}}"#)
private let petCreated = StubURLProtocol.Reply(status: 201, body: #"{"data": {"id": "01M7MYZ2HYK2HABX0PK0M9JEJT", "name": "Waffles", "species": null, "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}, "error": null, "meta": {}}"#)
private let failed = StubURLProtocol.Reply(status: 500, body: "{}")

private func json(_ request: URLRequest) throws -> NSDictionary? {
    try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary
}

private func requests() -> [URLRequest] {
    StubURLProtocol.requests.withLock { $0 }
}

extension StubbedNetwork {
    @MainActor @Suite struct FirstRunModelTests {
        @Test func myLocationPrefillsTheStreetAndTheSignFromTheName() async {
            let model = FirstRunModel(api: stubAPI([]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            #expect(model.label == "Dom's")
            #expect(!model.canSaveHome)
            await model.useMyLocation()
            #expect(model.found?.address == "11 Quillfeather Ln")
            #expect(model.street == "Quillfeather Ln")
            #expect(model.canSaveHome)
        }

        @Test func deniedLocationPointsAtSearch() async {
            let model = FirstRunModel(api: stubAPI([]), displayName: "Dom", geo: geo(locate: .failure(.denied)), defaults: freshDefaults())
            await model.useMyLocation()
            #expect(model.found == nil)
            #expect(model.message?.contains("Search for your address") == true)

            model.query = "9 Bramblewick Ct"
            await model.search()
            #expect(model.found != nil)
            #expect(model.street == "Bramblewick Ct")
            #expect(model.message == nil)
        }

        @Test func homeMakesTheStreetAroundItThenTheHouseholdAndRemembersIt() async throws {
            let defaults = freshDefaults()
            let model = FirstRunModel(api: stubAPI([placeCreated, homeCreated]), displayName: "Dom", geo: geo(), defaults: defaults)
            await model.useMyLocation()
            model.label = " Rivera "

            await model.saveHome()

            #expect(requestLog() == ["POST /v1/maps", "POST /v1/maps/\(MapFixtures.mapID)/households"])
            let sent = requests()
            #expect(try json(sent[0]) == ["name": "Quillfeather Ln", "center": ["lat": 37.4475, "lng": -122.1395], "radius_m": 300] as NSDictionary)
            #expect(try json(sent[1]) == ["label": "Rivera", "address": "11 Quillfeather Ln", "lat": 37.4475, "lng": -122.1395] as NSDictionary)
            #expect(model.place?.id == MapFixtures.mapID)
            #expect(model.home?.id == homeID)
            #expect(defaults.string(forKey: MapHomeModel.homeKey) == homeID)
            #expect(model.step == .people)
        }

        @Test func retryAfterAFailedHouseholdDoesNotMakeASecondStreet() async {
            let model = FirstRunModel(api: stubAPI([placeCreated, failed, homeCreated]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            await model.useMyLocation()

            await model.saveHome()
            #expect(model.message == "Couldn't save your home. Try again.")
            #expect(model.step == .home)

            await model.saveHome()
            let households = "POST /v1/maps/\(MapFixtures.mapID)/households"
            #expect(requestLog() == ["POST /v1/maps", households, households])
            #expect(model.step == .people)
        }

        @Test func joiningPutsTheHomeOnThatStreet() async throws {
            let model = FirstRunModel(api: stubAPI([homeCreated]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            model.join(try JSONDecoder().decode(Place.self, from: Data(MapFixtures.shared.utf8)))
            await model.useMyLocation()
            model.street = ""
            #expect(model.canSaveHome)

            await model.saveHome()

            #expect(requestLog() == ["POST /v1/maps/\(MapFixtures.sharedID)/households"])
            #expect(model.isJoining)
        }

        @Test func joiningCanSkipTheHomeStraightToTheTour() throws {
            let model = FirstRunModel(api: stubAPI([]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            model.join(try JSONDecoder().decode(Place.self, from: Data(MapFixtures.shared.utf8)))
            model.skipHome()
            #expect(model.step == .tour)
            #expect(requestLog().isEmpty)
        }

        @Test func anInvitePastTheHomeStepLeavesTheNewStreetAlone() async throws {
            let model = FirstRunModel(api: stubAPI([placeCreated, homeCreated]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            await model.useMyLocation()
            await model.saveHome()
            model.join(try JSONDecoder().decode(Place.self, from: Data(MapFixtures.shared.utf8)))
            #expect(!model.isJoining)
            #expect(model.place?.id == MapFixtures.mapID)
        }

        @Test func addsPeopleAndPetsToTheHome() async throws {
            let model = FirstRunModel(api: stubAPI([placeCreated, homeCreated, personCreated, petCreated]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            await model.useMyLocation()
            await model.saveHome()

            model.name = " Juniper "
            model.kind = .kid
            await model.addMember()
            model.name = "Waffles"
            model.kind = .pet
            await model.addMember()

            let path = "/v1/maps/\(MapFixtures.mapID)/households/\(homeID)"
            #expect(requestLog().suffix(2) == ["POST \(path)/people", "POST \(path)/pets"])
            let sent = requests()
            #expect(try json(sent[2])?["name"] as? String == "Juniper")
            #expect(try json(sent[2])?["role"] as? String == "kid")
            #expect(try json(sent[3])?["name"] as? String == "Waffles")
            #expect(model.added.map(\.name) == ["Juniper", "Waffles"])
            #expect(model.name.isEmpty)
        }

        @Test func aFailedAddKeepsTheName() async {
            let model = FirstRunModel(api: stubAPI([placeCreated, homeCreated, failed]), displayName: "Dom", geo: geo(), defaults: freshDefaults())
            await model.useMyLocation()
            await model.saveHome()
            model.name = "Juniper"
            await model.addMember()
            #expect(model.message == "Couldn't add Juniper. Try again.")
            #expect(model.name == "Juniper")
            #expect(model.added.isEmpty)
        }

        @Test func theTourShowsOnce() {
            let defaults = freshDefaults()
            let first = FirstRunModel(api: stubAPI([]), displayName: "Dom", geo: geo(), defaults: defaults)
            first.finishPeople()
            #expect(first.step == .tour)
            first.finishTour()
            #expect(first.step == .done)

            let again = FirstRunModel(api: stubAPI([]), displayName: "Dom", geo: geo(), defaults: defaults)
            again.finishPeople()
            #expect(again.step == .done)
        }

        @Test func theMapOpensOnTheRememberedHome() throws {
            let defaults = freshDefaults()
            defaults.set(homeID, forKey: MapHomeModel.homeKey)
            let home = MapHomeModel(api: stubAPI([]), defaults: defaults)
            let household = try JSONDecoder().decode(Household.self, from: Data(MapFixtures.household.utf8))
            home.show(try JSONDecoder().decode(Place.self, from: Data(MapFixtures.place.utf8)), households: [household])
            #expect(home.state == .ready)
            #expect(home.home?.id == homeID)
        }
    }
}

@Suite struct GeoTests {
    @Test(arguments: [
        ("11 Quillfeather Ln", "Quillfeather Ln"),
        ("10A Bramblewick Ct", "Bramblewick Ct"),
        ("Quillfeather Ln", "Quillfeather Ln"),
        ("Quillfeather Ln, Springfield", "Quillfeather Ln"),
    ])
    func streetDropsTheHouseNumber(_ address: String, _ street: String) {
        #expect(Geo.street(from: address) == street)
    }
}
