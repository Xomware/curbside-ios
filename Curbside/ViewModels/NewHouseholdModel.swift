import Observation

/// Adds a household at a picked spot: its building (if any), coordinate and geocoded address come along.
@MainActor @Observable
final class NewHouseholdModel {
    var label = ""
    var address: String
    private(set) var isBusy = false
    private(set) var message: String?

    let spot: Spot
    private let mapID: String
    private let api: APIClient

    init(spot: Spot, mapID: String, api: APIClient) {
        self.spot = spot
        self.mapID = mapID
        self.api = api
        address = spot.address ?? ""
    }

    var canSave: Bool {
        RootModel.validName(label) != nil && !isBusy
    }

    func save() async -> Household? {
        guard let label = RootModel.validName(label) else { return nil }
        isBusy = true
        defer { isBusy = false }
        message = nil
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = NewHousehold(
            label: label,
            address: address.isEmpty ? nil : String(address.prefix(200)),
            lat: spot.lat,
            lng: spot.lng,
            buildingID: spot.buildingID
        )
        do {
            return try await api.request("/v1/maps/\(mapID)/households", method: "POST", body: body)
        } catch {
            message = "Couldn't add them. Try again."
            return nil
        }
    }
}

/// nil fields are left out: the backend rejects unknown keys but takes absent optionals.
private struct NewHousehold: Encodable, Sendable {
    let label: String
    let address: String?
    let lat: Double
    let lng: Double
    let buildingID: String?

    enum CodingKeys: String, CodingKey {
        case label, address, lat, lng
        case buildingID = "building_id"
    }
}
