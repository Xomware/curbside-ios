import Foundation
import Testing
@testable import Curbside

private var path: String { "/v1/maps/\(MapFixtures.mapID)/households/\(HouseholdFixtures.id)" }

/// `notes_create` and `households_update` output under moto. The PATCH response has no people, pets or notes.
private let createdNote = StubURLProtocol.Reply(status: 201, body: #"{"data": {"id": "01M7MYZ2J0CM2F9M32E2MA5MB6", "text": "Lent them our ladder", "source": "manual", "created_at": "2026-11-18T09:00:00+00:00"}, "error": null, "meta": {}}"#)
private let patched = StubURLProtocol.Reply(status: 200, body: #"{"data": {"id": "01M7MYZ2HN482TDYCDP6CB5D9W", "version": 2, "lat": 37.1, "lng": -122.1, "building_id": "osm:way/1", "private": {"label": "Pumpernickel", "address": "11 Quillfeather Ln", "last_talked_at": "2026-11-18T15:00:00Z"}, "published": null}, "error": null, "meta": {}}"#)

private func sentBody() throws -> NSDictionary? {
    let request = try #require(StubURLProtocol.requests.withLock { $0.last })
    return try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary
}

@MainActor
private func loadedCard(_ replies: [StubURLProtocol.Reply]) async -> HouseholdModel {
    let model = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([HouseholdFixtures.got] + replies)) { _ in }
    await model.load()
    return model
}

extension StubbedNetwork {
    @MainActor @Suite struct NotesTests {
        @Test func noteGoesFirstAndTouchesLastTalkedWithoutAVersionBump() async throws {
            let model = await loadedCard([createdNote])
            #expect(await model.addNote("  Lent them our ladder \n"))

            #expect(requestLog().last == "POST \(path)/notes")
            #expect(try sentBody() == ["text": "Lent them our ladder", "source": "manual"] as NSDictionary)
            #expect(model.household.mine.notes?.map(\.text) == ["Lent them our ladder", "Mom visiting"])
            #expect(model.household.mine.lastTalkedAt == "2026-11-18T09:00:00+00:00")
            #expect(model.household.version == 1)
        }

        @Test(arguments: ["", "   ", String(repeating: "x", count: 2001)])
        func blankOrOverlongNoteIsNotSent(_ text: String) async {
            let model = await loadedCard([])
            #expect(await !model.addNote(text))
            #expect(requestLog().count == 1)
        }

        @Test func deletingANoteLeavesLastTalkedAlone() async {
            let model = await loadedCard([.init(status: 200, body: #"{"data": {"id": "01M7MYZ2J0CM2F9M32E2MA5MB5"}, "error": null, "meta": {}}"#)])
            let talked = model.household.mine.lastTalkedAt
            #expect(await model.deleteNote("01M7MYZ2J0CM2F9M32E2MA5MB5"))
            #expect(requestLog().last == "DELETE \(path)/notes/01M7MYZ2J0CM2F9M32E2MA5MB5")
            #expect(model.household.mine.notes?.isEmpty == true)
            #expect(model.household.mine.lastTalkedAt == talked)
        }

        @Test func talkedTodayPatchesTheTimeAndKeepsTheChildren() async throws {
            let model = await loadedCard([patched])
            let now = try #require("2026-11-18T15:00:00Z".isoDate)

            #expect(await model.talkedToday(now: now) == .saved)

            #expect(requestLog().last == "PATCH \(path)")
            #expect(try sentBody() == ["version": 1, "last_talked_at": "2026-11-18T15:00:00Z"] as NSDictionary)
            #expect(model.household.version == 2)
            #expect(model.household.mine.lastTalkedAt == "2026-11-18T15:00:00Z")
            #expect(model.household.mine.people?.count == 1)
            #expect(model.household.mine.notes?.count == 1)
        }

        @Test func talkedTodayConflictRefetches() async {
            let conflict = StubURLProtocol.Reply(status: 409, body: #"{"data": null, "error": {"code": "version_conflict", "message": "Household was changed by someone else; refetch it"}, "meta": {}}"#)
            let model = await loadedCard([conflict, HouseholdFixtures.got])
            #expect(await model.talkedToday() == .conflict)
            #expect(requestLog().last == "GET \(path)")
        }
    }
}
