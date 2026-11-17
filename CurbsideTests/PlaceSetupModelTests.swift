import CoreLocation
import Foundation
import Testing
@testable import Curbside

private let home = CLLocationCoordinate2D(latitude: 37.4475, longitude: -122.1395)

private func geo(locate: Result<CLLocationCoordinate2D, Geo.Failure> = .success(home), address: String? = "11 Quillfeather Ln") -> Geo {
    Geo(
        locate: { try locate.get() },
        search: { _ in (home, "9 Bramblewick Ct") },
        address: { _ in address }
    )
}

private let created = StubURLProtocol.Reply(status: 201, body: #"{"data": \#(MapFixtures.place), "error": null, "meta": {}}"#)

extension StubbedNetwork {
    @MainActor @Suite struct PlaceSetupModelTests {
        @Test func myLocationSetsCenterAndPrefillsTheStreet() async {
            let model = PlaceSetupModel(api: stubAPI([]), geo: geo())
            #expect(!model.canCreate)
            await model.useMyLocation()
            #expect(model.center?.latitude == home.latitude)
            #expect(model.name == "Quillfeather Ln")
            #expect(model.canCreate)
        }

        @Test func prefillKeepsATypedName() async {
            let model = PlaceSetupModel(api: stubAPI([]), geo: geo())
            model.name = "The cul-de-sac"
            await model.useMyLocation()
            #expect(model.name == "The cul-de-sac")
        }

        @Test func deniedLocationPointsAtSearch() async {
            let model = PlaceSetupModel(api: stubAPI([]), geo: geo(locate: .failure(.denied)))
            await model.useMyLocation()
            #expect(model.center == nil)
            #expect(model.message?.contains("Search for your address") == true)

            model.query = "9 Bramblewick Ct"
            await model.search()
            #expect(model.center != nil)
            #expect(model.name == "Bramblewick Ct")
            #expect(model.message == nil)
        }

        @Test func createPostsNameCenterAndRadius() async throws {
            let model = PlaceSetupModel(api: stubAPI([created]), geo: geo())
            await model.useMyLocation()
            model.radius = 150
            model.name = "  Quillfeather Ln "

            let place = await model.create()

            #expect(place?.id == MapFixtures.mapID)
            let post = try #require(StubURLProtocol.requests.withLock { $0.first })
            #expect(post.httpMethod == "POST")
            #expect(post.url?.path() == "/v1/maps")
            let body = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: post).utf8)) as? NSDictionary
            #expect(body == ["name": "Quillfeather Ln", "center": ["lat": 37.4475, "lng": -122.1395], "radius_m": 150] as NSDictionary)
        }

        @Test func rejectedCreateSaysSo() async {
            let invalid = StubURLProtocol.Reply(status: 400, body: #"{"data": null, "error": {"code": "invalid_request", "message": "Invalid request body"}, "meta": {}}"#)
            let model = PlaceSetupModel(api: stubAPI([invalid]), geo: geo())
            await model.useMyLocation()
            #expect(await model.create() == nil)
            #expect(model.message == "Couldn't make the map. Try again.")
        }

        @Test func createdPlaceOpensAnEmptyMap() async throws {
            let home = MapHomeModel(api: stubAPI([MapFixtures.none]))
            await home.load()
            home.show(try JSONDecoder().decode(Place.self, from: Data(MapFixtures.place.utf8)))
            #expect(home.state == .ready)
            #expect(home.households.isEmpty)
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
