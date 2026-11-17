import Foundation

/// The person editor's form state, kept as the user typed it. Converts to a create body or a PATCH diff.
struct PersonDraft: Equatable {
    var name = ""
    var role = Person.Role.adult
    var birthYear = ""
    var approx = false
    var notes = ""

    init() {}

    init(_ person: Person) {
        name = person.name
        role = person.role
        birthYear = person.birthYear.map(String.init) ?? ""
        approx = person.birthYearApprox
        notes = person.notes ?? ""
    }

    /// Why the form can't be saved, or nil when it can. Limits match the backend's `PersonCreate`.
    func problem(thisYear: Int = Calendar.current.component(.year, from: .now)) -> String? {
        if RootModel.validName(name) == nil { return "Add a name." }
        if !trimmed(birthYear).isEmpty, !(1900...thisYear).contains(Int(trimmed(birthYear)) ?? 0) {
            return "Birth year should be between 1900 and \(thisYear)."
        }
        if trimmed(notes).count > 1000 { return "Notes run past 1,000 characters." }
        return nil
    }

    var create: NewPerson {
        NewPerson(name: trimmed(name), role: role, birthYear: year, birthYearApprox: approx, notes: note)
    }

    func patch(from person: Person) -> Patch {
        var patch = Patch(version: person.version)
        patch.set("name", person.name, trimmed(name), as: Patch.Value.string)
        patch.set("role", person.role.rawValue, role.rawValue, as: Patch.Value.string)
        patch.set("birth_year", person.birthYear, year, as: Patch.Value.nullable)
        patch.set("birth_year_approx", person.birthYearApprox, approx, as: Patch.Value.bool)
        patch.set("notes", person.notes, note, as: Patch.Value.nullable)
        return patch
    }

    private var year: Int? { Int(trimmed(birthYear)) }
    private var note: String? { trimmed(notes).isEmpty ? nil : trimmed(notes) }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NewPerson: Encodable, Sendable {
    let name: String
    let role: Person.Role
    let birthYear: Int?
    let birthYearApprox: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case name, role, notes
        case birthYear = "birth_year"
        case birthYearApprox = "birth_year_approx"
    }
}
