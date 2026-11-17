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
}
