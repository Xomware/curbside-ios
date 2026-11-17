import Foundation

/// Fetches a place's footprint file and caches it on disk by (mapId, version).
/// The response contract is in xom-research `docs/features/curbside/ios-map-footprints/PLAN.md`.
@MainActor
struct FootprintLoader {
    let api: APIClient
    var cache = URL.cachesDirectory.appending(path: "footprints")

    /// Building outlines, or none while the file is pending, empty or failed.
    func load(_ place: Place) async throws -> [Footprint] {
        if place.footprint.status == .ready, let data = try? Data(contentsOf: file(place.id, place.footprint.version)) {
            return try Footprint.decode(data)
        }
        let info: Info = try await api.request("/v1/maps/\(place.id)/footprints")
        guard info.status == .ready, let url = info.url else { return [] }
        let file = file(place.id, info.version)
        if let data = try? Data(contentsOf: file) {
            return try Footprint.decode(data)
        }

        // Presigned S3 URL: no bearer token.
        let (body, response) = try await api.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.malformed }
        let data = try Gzip.inflateIfNeeded(body)
        let footprints = try Footprint.decode(data)

        let folder = file.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: file)
        return footprints
    }

    func file(_ mapID: String, _ version: Int) -> URL {
        cache.appending(path: mapID).appending(path: "v\(version).geojson")
    }

    private struct Info: Decodable, Sendable {
        let status: Place.Footprint.Status
        let version: Int
        let url: URL?
    }
}
