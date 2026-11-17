/// How one proposed change reads on the review list: whose house, who in it, and what changes.
struct CaptureSummary: Equatable {
    /// House number for the plaque tab; nil for a new house or one without an address.
    let number: String?
    /// "PUMPERNICKEL · ODO", "GRAY HOUSE · NEW PERSON".
    let who: String
    let change: String

    init(_ op: CaptureOp, households: [Household], newLabels: [String: String]) {
        let household = households.first { $0.id == op.householdRef }
        number = household?.houseNumber
        let house = (household?.mine.label ?? newLabels[op.householdRef] ?? "New house").uppercased()
        let people = household?.mine.people ?? []
        let pets = household?.mine.pets ?? []
        let fields = op.fields

        let detail: String?
        switch op.op {
        case .createHousehold:
            detail = "NEW HOUSE"
            change = Self.join([fields["label"]?.text, fields["address"]?.text])
        case .updateHousehold:
            detail = nil
            change = Self.join([Self.labelled("Label", fields["label"]), Self.labelled("Address", fields["address"])])
        case .addPerson:
            detail = "NEW PERSON"
            change = Self.join([fields["name"]?.text] + Self.person(fields))
        case .updatePerson:
            detail = people.first { $0.id == op.targetID }?.name.uppercased()
            change = Self.join([Self.labelled("Name", fields["name"])] + Self.person(fields))
        case .addPet:
            detail = "NEW PET"
            change = Self.join([fields["name"]?.text, fields["species"]?.text, fields["notes"]?.text])
        case .updatePet:
            detail = pets.first { $0.id == op.targetID }?.name.uppercased()
            change = Self.join(["name", "species", "notes"].map { Self.labelled($0.capitalized, fields[$0]) })
        case .addNote:
            detail = "NOTE"
            change = fields["text"]?.text ?? ""
        case .touchLastTalked:
            detail = nil
            change = "Talked today"
        }
        who = [house, detail].compactMap(\.self).joined(separator: " · ")
    }

    private static func person(_ fields: [String: Patch.Value]) -> [String?] {
        var born: String?
        if case .int(let year) = fields["birth_year"] {
            born = fields["birth_year_approx"] == .bool(true) ? "born ~\(year)" : "born \(year)"
        }
        return [
            fields["role"]?.text,
            born,
            fields["birthday"]?.text.map { "birthday \($0)" },
            fields["notes"]?.text,
        ]
    }

    private static func labelled(_ label: String, _ value: Patch.Value?) -> String? {
        switch value {
        case .string(let text): "\(label): \(text)"
        case .null: "\(label): cleared"
        default: nil
        }
    }

    private static func join(_ parts: [String?]) -> String {
        let text = parts.compactMap(\.self).filter { !$0.isEmpty }.joined(separator: ", ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
