import CoreLocation
import Observation

/// Talk or type → parse → the user checks the proposed changes → apply. The transcript lives only here and is never
/// written anywhere on the device; it goes when this model does.
@MainActor @Observable
final class CaptureModel: Identifiable {
    enum Phase: Equatable {
        case input
        case parsing
        case review
        case saving
        case saved
    }

    var transcript = ""
    var source = Note.Source.text
    private(set) var phase = Phase.input
    private(set) var message: String?
    private(set) var ops: [CaptureOp] = []
    private(set) var unresolved: [String] = []
    /// Where each "new:N" goes on the map. The parse only knows a label and maybe an address.
    private(set) var placements: [String: Spot] = [:]
    private var baseVersions: [String: Int] = [:]

    let households: [Household]
    private let place: Place
    private let selection: Spot?
    private let focus: Household?
    private let api: APIClient
    private let geo: Geo

    init(place: Place, households: [Household], selection: Spot?, focus: Household?, api: APIClient, geo: Geo) {
        self.place = place
        self.households = households
        self.selection = selection
        self.focus = focus
        self.api = api
        self.geo = geo
    }

    static let limit = 2000

    var checkedCount: Int { ops.count(where: \.checked) }

    /// New houses the user kept but hasn't put on the map yet. Apply needs their lat/lng.
    var unplaced: [String] {
        ops.filter { $0.checked && $0.op == .createHousehold && placements[$0.householdRef] == nil }.map(\.householdRef)
    }

    var canSave: Bool { phase == .review && checkedCount > 0 && unplaced.isEmpty }

    /// The households the model may write to: the one picked on the map, then the nearest, 8 at most.
    nonisolated static func roster(_ households: [Household], focus: String?, near here: CLLocationCoordinate2D) -> [String] {
        Nearby.nearest(households.filter { $0.id != focus }, to: here, heading: nil, limit: 8).map(\.household.id)
    }

    func parse() async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...Self.limit).contains(text.count) else { return }
        phase = .parsing
        message = nil
        let center = CLLocationCoordinate2D(latitude: place.center.lat, longitude: place.center.lng)
        let here = if let selection { selection.coordinate } else { await locate() ?? center }
        let request = ParseRequest(
            transcript: text,
            source: source,
            focusHouseholdID: focus?.id,
            nearbyHouseholdIDs: Self.roster(households, focus: focus?.id, near: here)
        )
        do {
            let parsed: ParsedCapture = try await api.request("/v1/maps/\(place.id)/capture/parse", method: "POST", body: request)
            ops = parsed.operations
            unresolved = parsed.unresolved
            baseVersions = parsed.baseVersions
            placements = [:]
            // Opened on an empty building or a dropped pin: that's where the first new house is.
            if let selection, focus == nil, ops.contains(where: { $0.householdRef == "new:1" }) {
                placements["new:1"] = selection
            }
            phase = .review
        } catch {
            phase = .input
            message = Self.message(for: error)
        }
    }

    /// One fix, or nil after 3 s: a fix that never comes (indoors, location off) mustn't hold up the parse.
    private func locate() async -> CLLocationCoordinate2D? {
        let geo = geo
        return await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask { try? await geo.locate() }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// A new house's changes need its create, and the create's loss takes them with it: apply 400s otherwise.
    func toggle(_ index: Int) {
        let op = ops[index]
        ops[index].checked.toggle()
        guard op.isNew else { return }
        for i in ops.indices where ops[i].householdRef == op.householdRef {
            if op.op == .createHousehold, op.checked {
                ops[i].checked = false
            } else if !op.checked, ops[i].op == .createHousehold {
                ops[i].checked = true
            }
        }
    }

    func place(_ ref: String, at spot: Spot) {
        placements[ref] = spot
    }

    /// Back to the transcript, to say more or fix it.
    func revise() {
        phase = .input
        message = nil
    }

    /// Checked ops, creates first: the model sometimes names a new house's people before the house, and apply
    /// refuses a "new:N" it hasn't seen created.
    var applyBody: ApplyBody {
        let kept = ops.filter(\.checked).map { op -> CaptureOp in
            guard op.op == .createHousehold, let spot = placements[op.householdRef] else { return op }
            var op = op
            op.fields["lat"] = .double(spot.lat)
            op.fields["lng"] = .double(spot.lng)
            if let building = spot.buildingID { op.fields["building_id"] = .string(building) }
            if op.fields["address"] == nil, let address = spot.address { op.fields["address"] = .string(address) }
            return op
        }
        let creates = kept.filter { $0.op == .createHousehold }
        return ApplyBody(operations: creates + kept.filter { $0.op != .createHousehold }, baseVersions: baseVersions, source: source)
    }

    /// True once saved. A conflict means the houses moved under the parse, so it parses again for a fresh diff.
    func apply() async -> Bool {
        guard canSave else { return false }
        phase = .saving
        message = nil
        do {
            let _: [Applied] = try await api.request("/v1/maps/\(place.id)/capture/apply", method: "POST", body: applyBody)
            transcript = ""
            ops = []
            phase = .saved
            return true
        } catch APIError.conflict {
            await parse()
            if phase == .review { message = "Something changed on these houses since. Here's a fresh read; check it again." }
            return false
        } catch {
            phase = .review
            message = Self.message(for: error)
            return false
        }
    }

    private static func message(for error: any Error) -> String? {
        switch error as? APIError {
        case .unauthorized: nil
        case .rateLimited: "That's today's 50 captures. Add this on the card instead, or try again tomorrow."
        case .server(status: 502, _): "Couldn't make sense of that. Try saying it another way."
        case .server(status: 503, _): "Reading is down for a moment. Try again shortly."
        case .server(status: 413, _): "Too many changes at once. Uncheck some and save again."
        default: "Couldn't reach Curbside. Try again."
        }
    }
}

private struct ParseRequest: Encodable, Sendable {
    let transcript: String
    let source: Note.Source
    let focusHouseholdID: String?
    let nearbyHouseholdIDs: [String]

    enum CodingKeys: String, CodingKey {
        case transcript, source
        case focusHouseholdID = "focus_household_id"
        case nearbyHouseholdIDs = "nearby_household_ids"
    }
}

struct ApplyBody: Encodable, Sendable {
    let operations: [CaptureOp]
    let baseVersions: [String: Int]
    let source: Note.Source

    enum CodingKeys: String, CodingKey {
        case operations, source
        case baseVersions = "base_versions"
    }
}

private struct Applied: Decodable, Sendable {
    let op: String
    let id: String
}
