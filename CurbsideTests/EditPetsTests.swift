import Foundation
import Testing
@testable import Curbside

/// Waffles as `households_get` returns him: species set, no notes.
private let waffles = HouseholdFixtures.household().mine.pets![0]
private let wafflesID = "01M7MYZ2HYK2HABX0PK0M9JEJT"
private var petPath: String { "/v1/maps/\(MapFixtures.mapID)/households/\(HouseholdFixtures.id)/pets" }

private func json(_ patch: Patch) throws -> NSDictionary? {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? NSDictionary
}

private func sentBody() throws -> NSDictionary? {
    let request = try #require(StubURLProtocol.requests.withLock { $0.last })
    return try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary
}

@Suite struct PetDraftTests {
    @Test func clearingTheSpeciesSendsNull() throws {
        var draft = PetDraft(waffles)
        draft.species = " "
        draft.notes = "Barks at the mail truck"
        #expect(try json(draft.patch(from: waffles)) == ["version": 1, "species": NSNull(), "notes": "Barks at the mail truck"] as NSDictionary)
    }

    @Test func unchangedIsEmpty() {
        #expect(PetDraft(waffles).patch(from: waffles).isEmpty)
    }

    @Test func nameIsRequired() {
        #expect(PetDraft().problem == "Add a name.")
    }
}

/// `pets_*` handler output under moto.
private let created = StubURLProtocol.Reply(status: 201, body: #"{"data": {"id": "01M7MYZ2HYK2HABX0PK0M9JEJV", "name": "Admiral Snooze", "species": "cat", "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}, "error": null, "meta": {}}"#)
private let updated = StubURLProtocol.Reply(status: 200, body: #"{"data": {"id": "01M7MYZ2HYK2HABX0PK0M9JEJT", "name": "Waffles", "version": 2, "created_at": "2026-11-17T14:35:52+00:00"}, "error": null, "meta": {}}"#)

@MainActor
private func card(_ replies: [StubURLProtocol.Reply]) -> HouseholdModel {
    HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI(replies)) { _ in }
}

extension StubbedNetwork {
    @MainActor @Suite struct EditPetsTests {
        @Test func addingPostsOnlyFilledFields() async throws {
            let model = card([created])
            var draft = PetDraft()
            draft.name = "Admiral Snooze"
            draft.species = "cat"
            #expect(await model.savePet(draft, id: nil) == .saved)
            #expect(requestLog() == ["POST \(petPath)"])
            #expect(try sentBody() == ["name": "Admiral Snooze", "species": "cat"] as NSDictionary)
            #expect(model.household.mine.pets?.map(\.name) == ["Waffles", "Admiral Snooze"])
        }

        @Test func editingReplacesWithTheServerCopy() async {
            let model = card([updated])
            var draft = PetDraft(waffles)
            draft.species = ""
            #expect(await model.savePet(draft, id: wafflesID) == .saved)
            #expect(requestLog() == ["PATCH \(petPath)/\(wafflesID)"])
            #expect(model.household.mine.pets?.first?.species == nil)
            #expect(model.household.mine.pets?.first?.version == 2)
        }

        @Test func conflictRefetches() async {
            let conflict = StubURLProtocol.Reply(status: 409, body: #"{"data": null, "error": {"code": "version_conflict", "message": "Pet was changed by someone else; refetch it"}, "meta": {}}"#)
            let model = card([conflict, HouseholdFixtures.got])
            var draft = PetDraft(waffles)
            draft.name = "Sir Waffles"
            #expect(await model.savePet(draft, id: wafflesID) == .conflict)
            #expect(requestLog().last == "GET /v1/maps/\(MapFixtures.mapID)/households/\(HouseholdFixtures.id)")
        }

        @Test func deleteRemovesThePet() async {
            let model = card([.init(status: 200, body: #"{"data": {"id": "\#(wafflesID)"}, "error": null, "meta": {}}"#)])
            #expect(await model.deletePet(wafflesID))
            #expect(model.household.mine.pets?.isEmpty == true)
        }
    }
}
