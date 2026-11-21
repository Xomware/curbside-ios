import Foundation
import Testing
@testable import Curbside

/// `households_get` output from the handlers under moto: one kid, one pet, one note.
enum HouseholdFixtures {
    static let id = "01M7MYZ2HN482TDYCDP6CB5D9W"
    static let full = #"{"id": "01M7MYZ2HN482TDYCDP6CB5D9W", "version": 1, "lat": 37.1, "lng": -122.1, "building_id": "osm:way/1", "private": {"label": "Pumpernickel", "address": "11 Quillfeather Ln", "last_talked_at": "2026-11-17T14:35:52+00:00", "people": [{"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "name": "Juniper", "role": "kid", "birth_year": 2018, "birth_year_approx": false, "version": 2, "created_at": "2026-11-17T14:35:52+00:00", "notes": "Collects rocks"}], "pets": [{"id": "01M7MYZ2HYK2HABX0PK0M9JEJT", "name": "Waffles", "species": "dog", "version": 1, "created_at": "2026-11-17T14:35:52+00:00"}], "notes": [{"id": "01M7MYZ2J0CM2F9M32E2MA5MB5", "text": "Mom visiting", "source": "manual", "created_at": "2026-11-17T14:35:52+00:00"}]}, "published": null}"#
    static let got = StubURLProtocol.Reply(status: 200, body: #"{"data": \#(full), "error": null, "meta": {}}"#)

    static func household(_ json: String = MapFixtures.household) -> Household {
        try! JSONDecoder().decode(Household.self, from: Data(json.utf8))
    }

    static func person(_ fields: String) -> Person {
        try! JSONDecoder().decode(Person.self, from: Data(#"{"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "version": 1, "name": "Odo", "role": "kid", "birth_year_approx": false\#(fields)}"#.utf8))
    }
}

@Suite struct PersonTests {
    @Test func ageFromBirthYear() {
        let kid = HouseholdFixtures.person(#", "birth_year": 2018"#)
        #expect(kid.age(in: 2026) == "8")
        #expect(kid.born == "Born 2018")
    }

    @Test func guessedYearReadsAsApproximate() {
        let kid = HouseholdFixtures.person(#", "birth_year": 2021"#).with { $0.birthYearApprox = true }
        #expect(kid.age(in: 2026) == "~5")
        #expect(kid.born == "Born ~2021, a guess")
    }

    @Test func noBirthYearNoAge() {
        let kid = HouseholdFixtures.person("")
        #expect(kid.age(in: 2026) == nil)
        #expect(kid.born == nil)
    }

    @Test func backendTimestampsParse() {
        #expect("2026-11-17T14:35:52+00:00".isoDate == Date(timeIntervalSince1970: 1_794_926_152))
    }
}

private extension Person {
    func with(_ change: (inout Person) -> Void) -> Person {
        var copy = self
        change(&copy)
        return copy
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct HouseholdModelTests {
        @Test func mapCopyRendersBeforeTheFetchWithoutNotes() {
            let model = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([])) { _ in }
            #expect(model.sections.map(\.name) == ["kids", "pets"])
        }

        @Test func fetchAddsNotesAndUpdatesTheMap() async {
            var handedBack: Household?
            let model = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([HouseholdFixtures.got])) {
                handedBack = $0
            }
            await model.load()

            #expect(requestLog() == ["GET /v1/maps/\(MapFixtures.mapID)/households/\(HouseholdFixtures.id)"])
            #expect(model.sections.map(\.name) == ["kids", "pets", "notes"])
            #expect(model.household.mine.notes?.first?.text == "Mom visiting")
            #expect(handedBack?.mine.notes?.count == 1)
            #expect(!model.failed)
        }

        @Test func noNotesStillShowsTheSectionOnceLoaded() async {
            let empty = HouseholdFixtures.full.replacingOccurrences(of: #""notes": [{"id": "01M7MYZ2J0CM2F9M32E2MA5MB5", "text": "Mom visiting", "source": "manual", "created_at": "2026-11-17T14:35:52+00:00"}]"#, with: #""notes": []"#)
            let model = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([.init(status: 200, body: #"{"data": \#(empty), "error": null, "meta": {}}"#)])) { _ in }
            await model.load()
            #expect(model.sections.last == .notes([]))
        }

        @Test func publishedSectionOnlyWhenPresent() {
            let card = MapFixtures.household.replacingOccurrences(of: #""published": null"#, with: #""published": {"display_name": "B"}"#)
            let withCard = HouseholdModel(household: HouseholdFixtures.household(card), mapID: MapFixtures.mapID, api: stubAPI([])) { _ in }
            let without = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([])) { _ in }
            #expect(withCard.sections.last == .published)
            #expect(!without.sections.contains(.published))
        }

        @Test func failedFetchKeepsTheMapCopyAndOffersRetry() async {
            let model = HouseholdModel(household: HouseholdFixtures.household(), mapID: MapFixtures.mapID, api: stubAPI([.init(status: 500, body: "{}"), HouseholdFixtures.got])) { _ in }
            await model.load()
            #expect(model.failed)
            #expect(model.household.mine.label == "Pumpernickel")
            await model.load()
            #expect(!model.failed)
        }

        @Test func mapOpensCardsAndTakesTheirUpdates() async {
            let map = MapHomeModel(api: stubAPI([MapFixtures.list, MapFixtures.loaded, HouseholdFixtures.got]))
            await map.load()
            let card = map.card(for: HouseholdFixtures.id)
            #expect(card != nil)
            #expect(map.card(for: "01M7MYZ2HN482TDYCDP6CB5D9X") == nil)
            await card?.load()
            #expect(map.households.first?.mine.notes?.count == 1)
            #expect(map.households.count == 1)
        }
    }
}

private extension HouseholdModel.Section {
    var name: String {
        switch self {
        case .adults: "adults"
        case .kids: "kids"
        case .pets: "pets"
        case .notes: "notes"
        case .published: "published"
        }
    }
}
