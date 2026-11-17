import Foundation
import Testing
@testable import Curbside

/// Juniper as the map and `households_get` return her: version 2, notes set, no birthday.
private let juniper = HouseholdFixtures.household().mine.people![0]
private let juniperID = "01M7MYZ2HQV0211WPK9QDKNCXT"

private func json(_ patch: Patch) throws -> NSDictionary? {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? NSDictionary
}

@Suite struct PersonDraftTests {
    @Test func unchangedDraftIsAnEmptyPatch() {
        #expect(PersonDraft(juniper).patch(from: juniper).isEmpty)
    }

    @Test func patchCarriesVersionAndOnlyWhatChanged() throws {
        var draft = PersonDraft(juniper)
        draft.name = " Juniper Rose "
        draft.approx = true
        #expect(try json(draft.patch(from: juniper)) == ["version": 2, "name": "Juniper Rose", "birth_year_approx": true] as NSDictionary)
    }

    @Test func blankingAFieldSendsNull() throws {
        var draft = PersonDraft(juniper)
        draft.birthYear = ""
        draft.notes = "  "
        #expect(try json(draft.patch(from: juniper)) == ["version": 2, "birth_year": NSNull(), "notes": NSNull()] as NSDictionary)
    }

    @Test(arguments: [
        ("", "2018", "Add a name."),
        ("Odo", "1899", "Birth year should be between 1900 and 2026."),
        ("Odo", "2027", "Birth year should be between 1900 and 2026."),
        ("Odo", "soon", "Birth year should be between 1900 and 2026."),
        ("Odo", "", nil),
        ("Odo", "2021", nil),
    ] as [(String, String, String?)])
    func validationMatchesTheBackend(_ name: String, _ year: String, _ problem: String?) {
        var draft = PersonDraft()
        draft.name = name
        draft.birthYear = year
        #expect(draft.problem(thisYear: 2026) == problem)
    }
}

/// `people_*` handler output under moto.
private let createdOdo = StubURLProtocol.Reply(status: 201, body: #"{"data": {"id": "01M7MYZ2HQV0211WPK9QDKNCXV", "name": "Odo", "role": "kid", "birth_year": 2021, "birth_year_approx": true, "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}, "error": null, "meta": {}}"#)
private let updated = StubURLProtocol.Reply(status: 200, body: #"{"data": {"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "name": "Juniper Rose", "role": "kid", "birth_year": 2018, "birth_year_approx": false, "version": 3, "created_at": "2026-11-17T14:35:52+00:00", "notes": "Collects rocks"}, "error": null, "meta": {}}"#)
private let conflict = StubURLProtocol.Reply(status: 409, body: #"{"data": null, "error": {"code": "version_conflict", "message": "Person was changed by someone else; refetch it"}, "meta": {}}"#)
private let deleted = StubURLProtocol.Reply(status: 200, body: #"{"data": {"id": "01M7MYZ2HQV0211WPK9QDKNCXT"}, "error": null, "meta": {}}"#)
private let gone = StubURLProtocol.Reply(status: 404, body: #"{"data": null, "error": {"code": "person_not_found", "message": "Person not found"}, "meta": {}}"#)

@MainActor
private func card(_ replies: [StubURLProtocol.Reply], changed: @escaping (Household) -> Void = { _ in }) -> HouseholdModel {
    HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI(replies), changed: changed)
}

private var personPath: String { "/v1/maps/\(MapFixtures.mapID)/households/\(HouseholdFixtures.id)/people" }

extension StubbedNetwork {
    @MainActor @Suite struct EditPeopleTests {
        @Test func addingPostsTheDraftAndAppends() async throws {
            var handedBack: Household?
            let model = card([createdOdo]) { handedBack = $0 }
            var draft = PersonDraft()
            draft.name = "Odo"
            draft.role = .kid
            draft.birthYear = "2021"
            draft.approx = true

            #expect(await model.savePerson(draft, id: nil) == .saved)

            #expect(requestLog() == ["POST \(personPath)"])
            let body = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: try #require(StubURLProtocol.requests.withLock { $0.first })).utf8)) as? NSDictionary
            #expect(body == ["name": "Odo", "role": "kid", "birth_year": 2021, "birth_year_approx": true] as NSDictionary)
            #expect(model.household.mine.people?.map(\.name) == ["Juniper", "Odo"])
            #expect(handedBack?.mine.people?.count == 2)
        }

        @Test func editingPatchesAndReplaces() async {
            let model = card([updated])
            var draft = PersonDraft(juniper)
            draft.name = "Juniper Rose"
            #expect(await model.savePerson(draft, id: juniperID) == .saved)
            #expect(requestLog() == ["PATCH \(personPath)/\(juniperID)"])
            #expect(model.household.mine.people?.first?.version == 3)
        }

        @Test func noChangesSendsNothing() async {
            let model = card([])
            #expect(await model.savePerson(PersonDraft(juniper), id: juniperID) == .saved)
            #expect(requestLog().isEmpty)
        }

        @Test func conflictRefetchesAndTheRetryUsesTheFreshVersion() async throws {
            let fresh = HouseholdFixtures.full.replacingOccurrences(of: #""version": 2, "created_at""#, with: #""version": 5, "created_at""#)
            let model = card([conflict, .init(status: 200, body: #"{"data": \#(fresh), "error": null, "meta": {}}"#), updated])
            var draft = PersonDraft(juniper)
            draft.name = "Juniper Rose"

            #expect(await model.savePerson(draft, id: juniperID) == .conflict)
            #expect(model.household.mine.people?.first?.version == 5)
            #expect(await model.savePerson(draft, id: juniperID) == .saved)

            let retry = try #require(StubURLProtocol.requests.withLock { $0.last })
            let body = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: retry).utf8)) as? NSDictionary
            #expect(body?["version"] as? Int == 5)
        }

        @Test func serverErrorLeavesThePersonAlone() async {
            let model = card([.init(status: 500, body: "{}")])
            var draft = PersonDraft(juniper)
            draft.name = "Juniper Rose"
            #expect(await model.savePerson(draft, id: juniperID) == .failed)
            #expect(model.household.mine.people?.first?.name == "Juniper")
        }

        @Test(arguments: [deleted, gone])
        func deleteRemovesEvenIfAlreadyGone(_ reply: StubURLProtocol.Reply) async {
            let model = card([reply])
            #expect(await model.deletePerson(juniperID))
            #expect(requestLog() == ["DELETE \(personPath)/\(juniperID)"])
            #expect(model.household.mine.people?.isEmpty == true)
        }

        @Test func failedDeleteKeepsThePerson() async {
            let model = card([.init(status: 500, body: "{}")])
            #expect(await !model.deletePerson(juniperID))
            #expect(model.household.mine.people?.count == 1)
        }
    }
}
