import Foundation

/// Fetches a place's footprint file and caches it on disk by (mapId, version).
/// Response shape: curbside-backend `lambdas/footprints_get/handler.py`.
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
        guard info.status == .ready, let url = info.url, let version = info.version else { return [] }
        let file = file(place.id, version)
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

    /// `footprints_get`: 202 `{status: "pending"}` alone; otherwise status, source, version, count and url.
    private struct Info: Decodable, Sendable {
        let status: Place.Footprint.Status
        let version: Int?
        let url: URL?
    }
}
