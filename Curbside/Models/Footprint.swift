import MapKit

/// One OSM building outline. A relation with several parts carries several polygons.
struct Footprint: Identifiable {
    let id: String
    let polygons: [MKPolygon]
    /// Garages, sheds and anything under 30 m². Drawn lighter and never selected.
    let accessory: Bool

    /// Features from a GeoJSON FeatureCollection; non-polygon geometry is skipped.
    static func decode(_ data: Data) throws -> [Footprint] {
        try MKGeoJSONDecoder().decode(data).compactMap { object -> Footprint? in
            guard let feature = object as? MKGeoJSONFeature, let id = feature.identifier else { return nil }
            let polygons = feature.geometry.flatMap { shape -> [MKPolygon] in
                if let multi = shape as? MKMultiPolygon { return multi.polygons }
                return (shape as? MKPolygon).map { [$0] } ?? []
            }
            guard !polygons.isEmpty else { return nil }
            let properties = feature.properties.flatMap { try? JSONDecoder().decode(Properties.self, from: $0) }
            return Footprint(id: id, polygons: polygons, accessory: properties?.accessory ?? false)
        }
    }

    private struct Properties: Decodable {
        let accessory: Bool
    }
}
