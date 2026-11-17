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

extension Footprint {
    /// Inside any part of the outline and outside its holes. Even-odd ray casting in map points, exact enough at
    /// house scale.
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let point = MKMapPoint(coordinate)
        return polygons.contains { polygon in
            Self.ring(polygon, contains: point) && !(polygon.interiorPolygons ?? []).contains { Self.ring($0, contains: point) }
        }
    }

    private static func ring(_ polygon: MKPolygon, contains point: MKMapPoint) -> Bool {
        let corners = UnsafeBufferPointer(start: polygon.points(), count: polygon.pointCount)
        var inside = false
        var previous = corners.count - 1
        for index in corners.indices {
            let a = corners[index], b = corners[previous]
            if (a.y > point.y) != (b.y > point.y), point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            previous = index
        }
        return inside
    }
}
