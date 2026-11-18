import CoreLocation
import Foundation
import Testing
@testable import Curbside

/// `capture_parse` / `capture_apply` output from the handlers under moto, with the backend's golden households and
/// its recorded model answers.
enum CaptureFixtures {
    static let place = #"{"id": "01M7NY1SNF7ZPWVN465J1GA2S4", "name": "Elm St", "center": {"lat": 40, "lng": -75}, "radius_m": 300, "footprint": {"status": "pending", "version": 0, "count": 0}, "version": 1, "created_at": "2026-11-17T23:39:07+00:00", "role": "owner"}"#
    static let mapID = "01M7NY1SNF7ZPWVN465J1GA2S4"
    static let blue = "01JCAPTVRE0000000000000HH1"
    static let households = [
        #"{"id": "01JCAPTVRE0000000000000HH1", "version": 3, "lat": 40, "lng": -75, "building_id": null, "private": {"label": "Blue house", "address": "14 Maple Ct, Springfield", "last_talked_at": null, "people": [{"id": "01JCAPTVRE00000000000000P1", "name": "Dana", "role": "adult", "birth_year": 1985, "birth_year_approx": false, "version": 2}, {"id": "01JCAPTVRE00000000000000P2", "name": "Theo", "role": "kid", "birth_year": 2018, "birth_year_approx": false, "version": 2}], "pets": [{"id": "01JCAPTVRE00000000000000X1", "name": "Biscuit", "species": "dog", "version": 2}]}, "published": null}"#,
        #"{"id": "01JCAPTVRE0000000000000HH2", "version": 3, "lat": 40.0001, "lng": -75, "building_id": null, "private": {"label": "Corner brick", "address": "18 Maple Ct, Springfield", "last_talked_at": null, "people": [{"id": "01JCAPTVRE00000000000000P3", "name": "Raj", "role": "adult", "birth_year_approx": false, "version": 2}, {"id": "01JCAPTVRE00000000000000P4", "name": "Priya", "role": "adult", "birth_year_approx": false, "version": 2}], "pets": []}, "published": null}"#,
        #"{"id": "01JCAPTVRE0000000000000HH3", "version": 3, "lat": 40.0002, "lng": -75, "building_id": null, "private": {"label": "Yellow duplex", "address": "22 Maple Ct, Springfield", "last_talked_at": null, "people": [], "pets": []}, "published": null}"#,
    ].map { HouseholdFixtures.household($0) }

    static let versions = #"{"01JCAPTVRE0000000000000HH1": 3, "01JCAPTVRE00000000000000P1": 2, "01JCAPTVRE00000000000000P2": 2, "01JCAPTVRE00000000000000X1": 2, "01JCAPTVRE0000000000000HH2": 3, "01JCAPTVRE00000000000000P3": 2, "01JCAPTVRE00000000000000P4": 2, "01JCAPTVRE0000000000000HH3": 3}"#
    static let newHousehold = parsed(#"[{"op": "create_household", "household_ref": "new:1", "target_id": null, "fields": {"label": "Gray house", "address": "30 Maple Ct"}, "evidence": "A new family moved into the gray house at 30 Maple Ct.", "confidence": 0.9, "needs_review": false, "checked": true}, {"op": "add_person", "household_ref": "new:1", "target_id": null, "fields": {"name": "Marcus", "role": "adult", "notes": "Dad of the new family"}, "evidence": "The dad is Marcus", "confidence": 0.9, "needs_review": false, "checked": true}, {"op": "add_person", "household_ref": "new:1", "target_id": null, "fields": {"name": "Ollie", "role": "kid", "birth_year": 2020, "birth_year_approx": true}, "evidence": "they have a kid about 6 named Ollie", "confidence": 0.85, "needs_review": false, "checked": true}]"#, unresolved: #"["Marcus's and Ollie's household is new; no last names given"]"#)
    /// The model named Sam before creating his house, and both need review.
    static let nextDoor = parsed(#"[{"op": "add_person", "household_ref": "new:1", "target_id": null, "fields": {"name": "Sam", "role": "adult"}, "evidence": "there's a guy named Sam who just moved in", "confidence": 0.5, "needs_review": true, "checked": false}, {"op": "create_household", "household_ref": "new:1", "target_id": null, "fields": {"label": "Next door to Dana (Sam's home)"}, "evidence": "Next door to Dana's there's a guy named Sam who just moved in.", "confidence": 0.4, "needs_review": true, "checked": false}]"#, unresolved: #"["Sam's house is only located as next door to Dana"]"#)
    static let birthday = parsed(#"[{"op": "update_person", "household_ref": "01JCAPTVRE0000000000000HH1", "target_id": "01JCAPTVRE00000000000000P2", "fields": {"birthday": "03-03"}, "evidence": "Theo's birthday is March 3rd.", "confidence": 0.9, "needs_review": false, "checked": true}]"#, unresolved: "[]")
    static let applied = StubURLProtocol.Reply(status: 200, body: #"{"data": [{"op": "create_household", "id": "01M7NY1SF2TQPPA21N63HFPHJT"}, {"op": "add_person", "id": "01M7NY1SF2567FQKDRV9GHTZ43"}], "error": null, "meta": {}}"#)
    static let conflict = StubURLProtocol.Reply(status: 409, body: #"{"data": null, "error": {"code": "version_conflict", "message": "Something changed since the parse; parse again"}, "meta": {}}"#)

    static func parsed(_ ops: String, unresolved: String) -> StubURLProtocol.Reply {
        .init(status: 200, body: #"{"data": {"operations": \#(ops), "unresolved": \#(unresolved), "base_versions": \#(versions)}, "error": null, "meta": {}}"#)
    }

    static func error(_ status: Int, _ code: String) -> StubURLProtocol.Reply {
        .init(status: status, body: #"{"data": null, "error": {"code": "\#(code)", "message": "x"}, "meta": {}}"#)
    }
}

private let here = CLLocationCoordinate2D(latitude: 40.0002, longitude: -75)
private let geo = Geo(locate: { here }, search: { _ in (here, nil) }, address: { _ in nil })

@MainActor
private func capture(_ replies: [StubURLProtocol.Reply], selection: Spot? = nil, focus: Household? = nil) -> CaptureModel {
    let place = try! JSONDecoder().decode(Place.self, from: Data(CaptureFixtures.place.utf8))
    let model = CaptureModel(place: place, households: CaptureFixtures.households, selection: selection, focus: focus, api: stubAPI(replies), geo: geo)
    model.transcript = "  Next door to Dana's there's a guy named Sam who just moved in. "
    model.source = .voice
    return model
}

private func sent(_ index: Int) throws -> NSDictionary {
    let request = try #require(StubURLProtocol.requests.withLock { $0.indices.contains(index) ? $0[index] : nil })
    return try #require(try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary)
}

@Suite struct CaptureRosterTests {
    @Test func nearestEightWithoutTheFocus() {
        let households = (0..<12).map { i in
            HouseholdFixtures.household(#"{"id": "H\#(i)", "version": 1, "lat": \#(40 + Double(i) * 0.0001), "lng": -75, "private": {"label": "L"}, "published": null}"#)
        }
        let ids = CaptureModel.roster(households, focus: "H0", near: CLLocationCoordinate2D(latitude: 40, longitude: -75))
        #expect(ids == (1...8).map { "H\($0)" })
    }

    @Test func mixedFieldTypesDecode() throws {
        let fields = try JSONDecoder().decode([String: Patch.Value].self, from: Data(#"{"b": true, "i": 2020, "d": 40.5, "s": "x", "n": null, "one": 1}"#.utf8))
        #expect(fields == ["b": .bool(true), "i": .int(2020), "d": .double(40.5), "s": .string("x"), "n": .null, "one": .int(1)])
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct CaptureModelTests {
        @Test func parseSendsTheTrimmedTranscriptAndTheRoster() async throws {
            let model = capture([CaptureFixtures.newHousehold], focus: CaptureFixtures.households[0])
            await model.parse()

            #expect(requestLog() == ["POST /v1/maps/\(CaptureFixtures.mapID)/capture/parse"])
            #expect(try sent(0) == [
                "transcript": "Next door to Dana's there's a guy named Sam who just moved in.",
                "source": "voice",
                "focus_household_id": CaptureFixtures.blue,
                "nearby_household_ids": ["01JCAPTVRE0000000000000HH3", "01JCAPTVRE0000000000000HH2"],
            ] as NSDictionary)
            #expect(model.phase == .review)
            #expect(model.ops.map(\.op) == [.createHousehold, .addPerson, .addPerson])
            #expect(model.ops[2].fields["birth_year_approx"] == .bool(true))
            #expect(model.unresolved.count == 1)
        }

        @Test func blankTranscriptIsNotSent() async {
            let model = capture([])
            model.transcript = "   "
            await model.parse()
            #expect(requestLog().isEmpty)
            #expect(model.phase == .input)
        }

        @Test func newHouseBlocksSaveUntilPlaced() async {
            let model = capture([CaptureFixtures.newHousehold])
            await model.parse()
            #expect(model.unplaced == ["new:1"])
            #expect(!model.canSave)

            model.place("new:1", at: Spot(here, buildingID: "osm:way/7"))
            #expect(model.canSave)
            #expect(model.checkedCount == 3)
        }

        @Test func openedOnAnEmptyBuildingPlacesTheFirstNewHouseThere() async {
            let spot = Spot(here, buildingID: "osm:way/7")
            let model = capture([CaptureFixtures.newHousehold], selection: spot)
            await model.parse()
            #expect(model.placements["new:1"] == spot)
            #expect(model.canSave)
        }

        @Test func uncheckingANewHouseTakesItsPeopleAndCheckingAPersonBringsItBack() async {
            let model = capture([CaptureFixtures.newHousehold])
            await model.parse()

            model.toggle(0)
            #expect(model.ops.map(\.checked) == [false, false, false])
            #expect(model.unplaced.isEmpty)

            model.toggle(2)
            #expect(model.ops.map(\.checked) == [true, false, true])
        }

        @Test func needsReviewStartsUncheckedAndCreatesGoFirstWithTheirSpot() async throws {
            var spot = Spot(CLLocationCoordinate2D(latitude: 40.0003, longitude: -75.0001), buildingID: "osm:way/7")
            spot.address = "26 Maple Ct"
            let model = capture([CaptureFixtures.nextDoor, CaptureFixtures.applied])
            await model.parse()
            #expect(model.checkedCount == 0)
            #expect(!model.canSave)

            model.toggle(0)
            model.place("new:1", at: spot)
            #expect(await model.apply())

            #expect(requestLog().last == "POST /v1/maps/\(CaptureFixtures.mapID)/capture/apply")
            let body = try sent(1)
            let ops = try #require(body["operations"] as? [NSDictionary])
            #expect(ops.map { $0["op"] as? String } == ["create_household", "add_person"])
            #expect(ops[0]["fields"] as? NSDictionary == [
                "label": "Next door to Dana (Sam's home)", "lat": 40.0003, "lng": -75.0001,
                "building_id": "osm:way/7", "address": "26 Maple Ct",
            ] as NSDictionary)
            #expect(ops[1]["household_ref"] as? String == "new:1")
            #expect((body["base_versions"] as? NSDictionary)?[CaptureFixtures.blue] as? Int == 3)
            #expect(body["source"] as? String == "voice")
            #expect(model.phase == .saved)
            #expect(model.transcript.isEmpty)
        }

        @Test func uncheckedChangesStayHome() async throws {
            let model = capture([CaptureFixtures.newHousehold, CaptureFixtures.applied])
            await model.parse()
            model.place("new:1", at: Spot(here, buildingID: nil))
            model.toggle(1)
            #expect(await model.apply())
            let ops = try #require(try sent(1)["operations"] as? [NSDictionary])
            #expect(ops.compactMap { ($0["fields"] as? NSDictionary)?["name"] as? String } == ["Ollie"])
            #expect((ops[0]["fields"] as? NSDictionary)?["building_id"] == nil)
            #expect((ops[0]["fields"] as? NSDictionary)?["address"] as? String == "30 Maple Ct")
        }

        @Test func conflictParsesAgainAndSaysSo() async {
            let model = capture([CaptureFixtures.birthday, CaptureFixtures.conflict, CaptureFixtures.birthday])
            await model.parse()
            #expect(await !model.apply())
            #expect(requestLog().map { $0.components(separatedBy: "/").last } == ["parse", "apply", "parse"])
            #expect(model.phase == .review)
            #expect(model.message?.hasPrefix("Something changed") == true)
            #expect(model.transcript.isEmpty == false)
        }

        @Test(arguments: [
            (CaptureFixtures.error(429, "quota_exceeded"), "today's 50"),
            (CaptureFixtures.error(502, "parse_failed"), "another way"),
            (CaptureFixtures.error(503, "model_unavailable"), "down for a moment"),
            (CaptureFixtures.error(500, "internal_error"), "Couldn't reach"),
        ])
        func parseFailureKeepsTheWordsAndExplains(_ reply: StubURLProtocol.Reply, _ phrase: String) async {
            let model = capture([reply])
            await model.parse()
            #expect(model.phase == .input)
            #expect(model.message?.contains(phrase) == true)
            #expect(!model.transcript.isEmpty)
        }

        @Test func tooManyChangesStaysOnTheReview() async {
            let model = capture([CaptureFixtures.birthday, CaptureFixtures.error(413, "too_many_operations")])
            await model.parse()
            #expect(await !model.apply())
            #expect(model.phase == .review)
            #expect(model.message?.contains("Uncheck some") == true)
        }

        @Test func refreshAfterApplyPicksUpTheNewHouses() async {
            let model = MapHomeModel(api: stubAPI([MapFixtures.list, MapFixtures.loaded, MapFixtures.footprintsPending, MapFixtures.loaded]))
            await model.load()
            await model.refresh()
            #expect(requestLog().last == "GET /v1/maps/\(MapFixtures.mapID)")
            #expect(model.households.count == 1)
            #expect(model.state == .ready)
        }
    }
}
