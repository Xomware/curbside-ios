import Foundation
import MapKit
import Testing
@testable import Curbside

/// Four features in the B7 output shape: a house with a courtyard hole, an accessory shed, a two-part relation,
/// and a point that must be skipped.
enum FootprintFixtures {
    static let geojson = #"{"type":"FeatureCollection","features":[{"type":"Feature","id":"osm:way/11","geometry":{"type":"Polygon","coordinates":[[[-122.1,37.1],[-122.0998,37.1],[-122.0998,37.1002],[-122.1,37.1002],[-122.1,37.1]],[[-122.09995,37.10005],[-122.09985,37.10005],[-122.09985,37.10015],[-122.09995,37.10015],[-122.09995,37.10005]]]},"properties":{"building":"house","area_m2":380,"accessory":false}},{"type":"Feature","id":"osm:way/12","geometry":{"type":"Polygon","coordinates":[[[-122.0997,37.1],[-122.09965,37.1],[-122.09965,37.10005],[-122.0997,37.10005],[-122.0997,37.1]]]},"properties":{"building":"shed","area_m2":25,"accessory":true}},{"type":"Feature","id":"osm:relation/13","geometry":{"type":"MultiPolygon","coordinates":[[[[-122.0990,37.1],[-122.0989,37.1],[-122.0989,37.1001],[-122.0990,37.1001],[-122.0990,37.1]]],[[[-122.0988,37.1],[-122.0987,37.1],[-122.0987,37.1001],[-122.0988,37.1001],[-122.0988,37.1]]]]},"properties":{"building":"yes","area_m2":200,"accessory":false}},{"type":"Feature","id":"osm:node/14","geometry":{"type":"Point","coordinates":[-122.1,37.1]},"properties":{}}]}"#
    /// `gzip.compress` output, as `footprints_fetch` writes it.
    static let gzipped = Data(base64Encoded: "H4sIAHhr/GoC/52TTWuEMBCG/0vOdk1irR/XQm+F3iWUVGfdQDSSRIqI/73RbcW1utIe53Ey5Hkz9sh2DaAUvQC3rYZnJSXkVqgaeeh8ZQalWb/qc19F4UplqvSTdz4hjpSgKrC6Q+nc/qZkV07DcqV0IWpup3lZ9kAoPREviE6EedcKJ0m8DTCmP4xsA+bK+VASfjfhcDnqPiVLmtynbgJjg4carRrQVoxOPfpohXSKpfO+qNaMIXEN/L2iKA1i7Ko8B2PUmNCZSwPD4B0GS/8VrLtstI7yKdwhq0SifXhgbS5QLKVpeONsdXukrEHycft8Emx7v7bSin35+b545Ron28C98MIS7zI2Ldh8eL2ncbQNbkbF8S5jB8l2jiyDxX/fploV4JPHvXUStf2V5/L/Wt9uGNjwBUNHXh0+BAAA")!
    /// The gzip CLI's output, which carries the file name (FNAME flag).
    static let gzippedWithName = Data(base64Encoded: "H4sICHhr/GoAA3YxLmdlb2pzb24AnZPBboQgEIbfhbNdQWtFr016a9K7IQ3VWZeElQ1gGmN896LbGsvqmvY4n8OE72fske0ugHL0Aty2Gp6VlFBaoRoUoOOVGZQXvdfnvorKlcqc80/ehYQ4UoM6g9Udyuf2NyW7ehpWKqUr0XA7zSuKBxJFBxLE6YGw4FrhLKPrAOPoh5F1wFw5H8qS7yacLEfdp2RJs/vUTWBsCNBFqwtoK0anHn20QjrF2nmfVGvGkLgG/n6OUB5T7KqyBGPUmNCRSwPDEOwGG/0rWHfZ1I/yKdkgXiLpNtyxNieoltJR8svZ6nZPWYPk4/aFJF73fm2lFdvy832x50qzdeBeeGGJNxmbFmw+7O8p9dOm6e0oSjcZ20m2c2QZLP77NjWqgpA8bq2TaOxNnsv/y7/dMLDhC0NHXh0+BAAA")!

    /// `footprints_get` output: pending is a bare status with 202.
    static func info(_ status: String, version: Int, url: String?) -> StubURLProtocol.Reply {
        if status == "pending" { return .init(status: 202, body: #"{"data": {"status": "pending"}, "error": null, "meta": {}}"#) }
        let url = url.map { "\"\($0)\"" } ?? "null"
        return .init(status: 200, body: #"{"data": {"status": "\#(status)", "source": "osm", "version": \#(version), "count": 3, "url": \#(url)}, "error": null, "meta": {}}"#)
    }
}

private func place(_ status: String = "ready", version: Int = 1) throws -> Place {
    let json = MapFixtures.place.replacingOccurrences(of: #""status": "pending", "version": 0"#, with: #""status": "\#(status)", "version": \#(version)"#)
    return try JSONDecoder().decode(Place.self, from: Data(json.utf8))
}

@MainActor
private func loader(_ replies: [StubURLProtocol.Reply]) -> FootprintLoader {
    FootprintLoader(api: stubAPI(replies), cache: URL.temporaryDirectory.appending(path: "footprints-\(UUID())"))
}

private let presigned = "https://bucket.example.test/footprints/m/v1.geojson.gz?X-Amz-Signature=abc"

extension StubbedNetwork {
    @MainActor @Suite struct FootprintLoaderTests {
        @Test func downloadsInflatesAndCaches() async throws {
            let loader = loader([FootprintFixtures.info("ready", version: 1, url: presigned), .init(status: 200, data: FootprintFixtures.gzipped)])

            let footprints = try #require(try await loader.load(try place()))

            #expect(footprints.map(\.id) == ["osm:way/11", "osm:way/12", "osm:relation/13"])
            #expect(footprints.map(\.accessory) == [false, true, false])
            #expect(footprints[0].polygons.first?.interiorPolygons?.count == 1)
            #expect(footprints[2].polygons.count == 2)
            let download = try #require(StubURLProtocol.requests.withLock { $0.last })
            #expect(download.value(forHTTPHeaderField: "Authorization") == nil)
            let cached = try String(contentsOf: loader.file(MapFixtures.mapID, 1), encoding: .utf8)
            #expect(cached == FootprintFixtures.geojson)
        }

        @Test func cachedVersionSkipsTheNetwork() async throws {
            let warm = loader([FootprintFixtures.info("ready", version: 1, url: presigned), .init(status: 200, data: FootprintFixtures.gzipped)])
            _ = try await warm.load(try place())

            let cold = FootprintLoader(api: stubAPI([]), cache: warm.cache)
            #expect(try await cold.load(try place())?.count == 3)
            #expect(requestLog().isEmpty)
        }

        @Test func newVersionReplacesTheOldFile() async throws {
            let warm = loader([FootprintFixtures.info("ready", version: 1, url: presigned), .init(status: 200, data: FootprintFixtures.gzipped)])
            _ = try await warm.load(try place())

            let next = FootprintLoader(api: stubAPI([
                FootprintFixtures.info("ready", version: 2, url: presigned),
                .init(status: 200, data: Data(FootprintFixtures.geojson.utf8)),
            ]), cache: warm.cache)
            #expect(try await next.load(try place(version: 2))?.count == 3)
            #expect(FileManager.default.fileExists(atPath: next.file(MapFixtures.mapID, 2).path()))
            #expect(!FileManager.default.fileExists(atPath: next.file(MapFixtures.mapID, 1).path()))
        }

        @Test(arguments: ["empty", "failed"])
        func noFileMeansNoFootprints(_ status: String) async throws {
            let loader = loader([FootprintFixtures.info(status, version: 0, url: nil)])
            #expect(try await loader.load(try place(status, version: 0))?.isEmpty == true)
            #expect(requestLog() == ["GET /v1/maps/\(MapFixtures.mapID)/footprints"])
        }

        @Test func pendingIsNotYetRatherThanNone() async throws {
            let loader = loader([FootprintFixtures.info("pending", version: 0, url: nil)])
            #expect(try await loader.load(try place("pending", version: 0)) == nil)
        }

        @Test func expiredLinkThrowsSoTheMapKeepsPins() async throws {
            let loader = loader([FootprintFixtures.info("ready", version: 1, url: presigned), .init(status: 403, body: "<Error/>")])
            await #expect(throws: APIError.malformed) { _ = try await loader.load(try place()) }
        }
    }
}

@Suite struct GzipTests {
    @Test(arguments: [FootprintFixtures.gzipped, FootprintFixtures.gzippedWithName, Data(FootprintFixtures.geojson.utf8)])
    func inflatesGzipAndPassesPlainBodiesThrough(_ body: Data) throws {
        #expect(try Gzip.inflateIfNeeded(body) == Data(FootprintFixtures.geojson.utf8))
    }
}
