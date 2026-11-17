import Foundation

/// The pet editor's form state. Converts to a create body or a PATCH diff.
struct PetDraft: Equatable {
    var name = ""
    var species = ""
    var notes = ""

    init() {}

    init(_ pet: Pet) {
        name = pet.name
        species = pet.species ?? ""
        notes = pet.notes ?? ""
    }

    /// Why the form can't be saved, or nil when it can. Limits match the backend's `PetCreate`.
    var problem: String? {
        if RootModel.validName(name) == nil { return "Add a name." }
        if trimmed(species).count > 40 { return "Keep the kind of animal under 40 characters." }
        if trimmed(notes).count > 1000 { return "Notes run past 1,000 characters." }
        return nil
    }

    var create: NewPet {
        NewPet(name: trimmed(name), species: optional(species), notes: optional(notes))
    }

    func patch(from pet: Pet) -> Patch {
        var patch = Patch(version: pet.version)
        patch.set("name", pet.name, trimmed(name), as: Patch.Value.string)
        patch.set("species", pet.species, optional(species), as: Patch.Value.nullable)
        patch.set("notes", pet.notes, optional(notes), as: Patch.Value.nullable)
        return patch
    }

    private func optional(_ text: String) -> String? {
        trimmed(text).isEmpty ? nil : trimmed(text)
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NewPet: Encodable, Sendable {
    let name: String
    let species: String?
    let notes: String?
}
