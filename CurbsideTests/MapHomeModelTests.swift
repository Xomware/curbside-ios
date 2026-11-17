import Foundation
import Testing
@testable import Curbside

/// Bodies are `maps_list` / `maps_get` output captured from the curbside-backend handlers under moto.
enum MapFixtures {
    static let mapID = "01M7MYZ2HFPVH17HK973WZBB9S"
    static let place = #"{"id": "01M7MYZ2HFPVH17HK973WZBB9S", "name": "Quillfeather Ln", "center": {"lat": 37.1, "lng": -122.1}, "radius_m": 300, "footprint": {"status": "pending", "version": 0, "count": 0}, "version": 1, "created_at": "2026-11-17T14:35:52+00:00", "role": "owner"}"#
    static let household = #"{"id": "01M7MYZ2HN482TDYCDP6CB5D9W", "version": 2, "lat": 37.1, "lng": -122.1, "building_id": "osm:way/1", "private": {"label": "Pumpernickel", "address": "11 Quillfeather Ln", "last_talked_at": "2026-11-17T14:35:52+00:00", "people": [{"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "name": "Juniper", "role": "kid", "birth_year": 2018, "birth_year_approx": false, "version": 2, "created_at": "2026-11-17T14:35:52+00:00", "notes": "Collects rocks"}], "pets": [{"id": "01M7MYZ2HYK2HABX0PK0M9JEJT", "name": "Waffles", "species": "dog", "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}]}, "published": null}"#
    static let list = StubURLProtocol.Reply(status: 200, body: #"{"data": [\#(place)], "error": null, "meta": {}}"#)
    static let none = StubURLProtocol.Reply(status: 200, body: #"{"data": [], "error": null, "meta": {}}"#)
    static let footprintsPending = StubURLProtocol.Reply(status: 202, body: #"{"data": {"status": "pending", "version": 0, "count": 0, "url": null}, "error": null, "meta": {}}"#)
    static let loaded = StubURLProtocol.Reply(status: 200, body: #"{"data": {"map": \#(place), "households": [\#(household)]}, "error": null, "meta": {}}"#)
}

private actor FixedTokens: TokenProvider {
    func accessToken() -> String? { "a1" }
    func refreshAccessToken() throws -> String { "a1" }
    func signOut() {}
}

@MainActor
func stubAPI(_ replies: [StubURLProtocol.Reply]) -> APIClient {
    APIClient(baseURL: URL(string: "https://api.example.test")!, tokens: FixedTokens(), session: StubURLProtocol.session(replies))
}

func requestLog() -> [String] {
    StubURLProtocol.requests.withLock { $0.map { "\($0.httpMethod ?? "") \($0.url?.path() ?? "")" } }
}

extension StubbedNetwork {
    @MainActor @Suite struct MapHomeModelTests {
        @Test func loadsTheFirstPlaceAndItsHouseholds() async throws {
            let model = MapHomeModel(api: stubAPI([MapFixtures.list, MapFixtures.loaded, MapFixtures.footprintsPending]))
            await model.load()

            #expect(model.state == .ready)
            #expect(requestLog() == ["GET /v1/maps", "GET /v1/maps/\(MapFixtures.mapID)", "GET /v1/maps/\(MapFixtures.mapID)/footprints"])
            #expect(model.footprints.isEmpty)
            let place = try #require(model.place)
            #expect(place.radiusM == 300)
            #expect(place.footprint == Place.Footprint(status: .pending, version: 0))
            let household = try #require(model.households.first)
            #expect(household.mine.label == "Pumpernickel")
            #expect(household.buildingID == "osm:way/1")
            #expect(household.version == 2)
            #expect(household.published == nil)
        }

        @Test func noPlaceRoutesToSetupWithoutLoadingAMap() async {
            let model = MapHomeModel(api: stubAPI([MapFixtures.none]))
            await model.load()
            #expect(model.state == .noPlace)
            #expect(requestLog() == ["GET /v1/maps"])
        }

        @Test func footprintFailureStillShowsTheHouseholds() async {
            let model = MapHomeModel(api: stubAPI([MapFixtures.list, MapFixtures.loaded, .init(status: 500, body: "{}")]))
            await model.load()
            #expect(model.state == .ready)
            #expect(model.households.count == 1)
            #expect(model.footprints.isEmpty)
        }

        @Test func serverErrorOffersRetry() async {
            let model = MapHomeModel(api: stubAPI([.init(status: 500, body: "{}"), MapFixtures.list, MapFixtures.loaded]))
            await model.load()
            #expect(model.state == .failed)
            await model.load()
            #expect(model.state == .ready)
        }
    }
}

@Suite struct HouseholdTests {
    @Test(arguments: [
        ("11 Quillfeather Ln", "11"),
        ("10A Quillfeather Ln", "10A"),
        ("Corner of Elm and 5th", nil),
        (nil, nil),
    ] as [(String?, String?)])
    func houseNumberComesFromTheAddress(_ address: String?, _ number: String?) throws {
        var household = try JSONDecoder().decode(Household.self, from: Data(MapFixtures.household.utf8))
        household.mine.address = address
        #expect(household.houseNumber == number)
    }

    @Test func publishedDecodesWhenPresent() throws {
        let json = MapFixtures.household.replacingOccurrences(of: #""published": null"#, with: #""published": {"display_name": "B"}"#)
        let household = try JSONDecoder().decode(Household.self, from: Data(json.utf8))
        #expect(household.published != nil)
    }

    @Test(arguments: ["demo-map"])
    func demoFixturesMatchTheModels(_ name: String) throws {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let data = try JSONSerialization.data(withJSONObject: try #require(json?["data"]))
        struct Loaded: Decodable { let map: Place; let households: [Household] }
        let loaded = try JSONDecoder().decode(Loaded.self, from: data)
        #expect(loaded.households.count == 9)
    }
}
