import Foundation
import Observation

/// One household's card. Shows the map's copy straight away, then fetches the full record for notes.
@MainActor @Observable
final class HouseholdModel {
    enum Section: Equatable {
        case adults([Person])
        case kids([Person])
        case pets([Pet])
        case notes([Note])
        case published
    }

    enum SaveResult: Equatable {
        case saved
        /// Someone else changed it first. The card now shows their copy; the draft is still the user's.
        case conflict
        case failed
    }

    private(set) var household: Household
    private(set) var isLoading = false
    private(set) var failed = false

    let mapID: String
    let api: APIClient
    /// Hands each fresh copy back to the map so its pins stay current.
    private let changed: (Household) -> Void

    init(household: Household, mapID: String, api: APIClient, changed: @escaping (Household) -> Void) {
        self.household = household
        self.mapID = mapID
        self.api = api
        self.changed = changed
    }

    var path: String { "/v1/maps/\(mapID)/households/\(household.id)" }

    /// Non-empty sections in card order. Notes show once fetched, even when there are none, so "no notes yet" is
    /// distinguishable from "not loaded".
    var sections: [Section] {
        let mine = household.mine
        let people = mine.people ?? []
        var sections: [Section] = []
        let adults = people.filter { $0.role == .adult }
        let kids = people.filter { $0.role == .kid }
        if !adults.isEmpty { sections.append(.adults(adults)) }
        if !kids.isEmpty { sections.append(.kids(kids)) }
        if let pets = mine.pets, !pets.isEmpty { sections.append(.pets(pets)) }
        if let notes = mine.notes { sections.append(.notes(notes)) }
        if household.published != nil { sections.append(.published) }
        return sections
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            household = try await api.request(path)
            failed = false
            changed(household)
        } catch {
            failed = true
        }
    }

    /// Creates a person, or PATCHes only what changed against the card's latest copy of `id`.
    func savePerson(_ draft: PersonDraft, id: String?) async -> SaveResult {
        let people = household.mine.people ?? []
        do {
            if let id, let current = people.first(where: { $0.id == id }) {
                let patch = draft.patch(from: current)
                guard !patch.isEmpty else { return .saved }
                let person: Person = try await api.request("\(path)/people/\(id)", method: "PATCH", body: patch)
                household.mine.people = people.map { $0.id == id ? person : $0 }
            } else {
                let person: Person = try await api.request("\(path)/people", method: "POST", body: draft.create)
                household.mine.people = people + [person]
            }
        } catch APIError.conflict {
            await load()
            return .conflict
        } catch {
            return .failed
        }
        changed(household)
        return .saved
    }

    func deletePerson(_ id: String) async -> Bool {
        guard await delete("\(path)/people/\(id)") else { return false }
        household.mine.people?.removeAll { $0.id == id }
        changed(household)
        return true
    }

    /// True once the item is gone, including when someone else already deleted it (404).
    private func delete(_ path: String) async -> Bool {
        do {
            let _: Deleted = try await api.request(path, method: "DELETE")
            return true
        } catch APIError.server(status: 404, _) {
            return true
        } catch {
            return false
        }
    }
}

private struct Deleted: Decodable, Sendable {
    let id: String
}
