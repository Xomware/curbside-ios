/// One change `capture/parse` proposes. `fields` hold only what the transcript said.
struct CaptureOp: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case createHousehold = "create_household"
        case updateHousehold = "update_household"
        case addPerson = "add_person"
        case updatePerson = "update_person"
        case addPet = "add_pet"
        case updatePet = "update_pet"
        case addNote = "add_note"
        case touchLastTalked = "touch_last_talked"
    }

    let op: Kind
    /// An existing household id, or "new:1", "new:2"... for one this capture creates.
    let householdRef: String
    /// The person or pet an update changes.
    let targetID: String?
    var fields: [String: Patch.Value]
    /// The span of the transcript this came from.
    let evidence: String
    let confidence: Double
    /// Placed only by position ("next door"), so it starts unchecked.
    let needsReview: Bool
    var checked: Bool

    enum CodingKeys: String, CodingKey {
        case op, fields, evidence, confidence, checked
        case householdRef = "household_ref"
        case targetID = "target_id"
        case needsReview = "needs_review"
    }

    var isNew: Bool { householdRef.hasPrefix("new:") }
}

/// `capture/parse` output. `base_versions` go back unchanged with apply, which 409s if anything moved since.
struct ParsedCapture: Decodable, Sendable {
    let operations: [CaptureOp]
    let unresolved: [String]
    let baseVersions: [String: Int]

    enum CodingKeys: String, CodingKey {
        case operations, unresolved
        case baseVersions = "base_versions"
    }
}
