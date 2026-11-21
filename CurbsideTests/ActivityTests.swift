import Foundation
import Testing
import UserNotifications
@testable import Curbside

/// Bodies follow the API contract for `GET /activity`, `POST /activity/seen` and `PUT/DELETE /devices/{token}`.
private enum ActivityFixtures {
    static let feed = StubURLProtocol.Reply(status: 200, body: #"{"data": {"items": [{"id": "a2", "kind": "household_added", "actor_name": "Sam", "map_id": "\#(MapFixtures.mapID)", "map_name": "Quillfeather Ln", "created_at": "2026-11-20T15:10:00+00:00"}, {"id": "a1", "kind": "friend_added", "actor_name": "Odette", "created_at": "2026-11-19T18:42:00+00:00"}], "unread": 1}, "error": null, "meta": {}}"#)
    static let quiet = StubURLProtocol.Reply(status: 200, body: #"{"data": {"items": [], "unread": 0}, "error": null, "meta": {}}"#)
    static let noContent = StubURLProtocol.Reply(status: 204, body: "")
    static let failure = StubURLProtocol.Reply(status: 500, body: "{}")

    static func item(_ kind: String, map: String? = "Quillfeather Ln") throws -> ActivityItem {
        let street = map.map { #", "map_id": "m1", "map_name": "\#($0)""# } ?? ""
        let json = #"{"id": "a1", "kind": "\#(kind)", "actor_name": "Sam"\#(street), "created_at": "2026-11-20T15:10:00+00:00"}"#
        return try JSONDecoder().decode(ActivityItem.self, from: Data(json.utf8))
    }
}

@Suite struct ActivityItemTests {
    @Test(arguments: [
        ("member_joined", "Sam joined Quillfeather Ln"),
        ("added_to_street", "Sam added you to Quillfeather Ln"),
        ("removed_from_street", "Sam took you off Quillfeather Ln"),
        ("street_handed_to_you", "Quillfeather Ln is yours now"),
        ("household_added", "Sam added a household to Quillfeather Ln"),
        ("friend_added", "You and Sam are friends"),
        ("something_new", "Sam changed something on Quillfeather Ln"),
    ])
    func eachKindReadsAsASentence(_ kind: String, _ text: String) throws {
        #expect(try ActivityFixtures.item(kind).text == text)
    }

    @Test func aStreetYouWereTakenOffDoesntOpen() throws {
        #expect(try ActivityFixtures.item("member_joined").opens == "m1")
        #expect(try ActivityFixtures.item("removed_from_street").opens == nil)
        #expect(try ActivityFixtures.item("friend_added", map: nil).opens == nil)
    }

    @Test func theDemoFeedDecodes() throws {
        let url = try #require(Bundle.main.url(forResource: "demo-activity", withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let feed = try JSONDecoder().decode(ActivityFeed.self, from: JSONSerialization.data(withJSONObject: try #require(json?["data"])))
        #expect(feed.unread == 2)
    }
}

@Suite struct HelloReminderTests {
    @Test func nobodyDueMeansNoReminder() {
        #expect(Notifications.reminder(due: 0, street: "Quillfeather Ln") == nil)
    }

    @Test func theReminderCountsWhoIsDueAndRepeatsSaturdayMornings() throws {
        let request = try #require(Notifications.reminder(due: 3, street: "Quillfeather Ln"))
        #expect(request.identifier == Notifications.reminderID)
        #expect(request.content.body == "3 neighbors on Quillfeather Ln are due for a hello.")
        #expect(Notifications.reminder(due: 1, street: "Quillfeather Ln")?.content.body == "1 neighbor on Quillfeather Ln is due for a hello.")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.weekday == 7)
        #expect(trigger.dateComponents.hour == 10)
    }

    @Test func dueIsNeverTalkedOrOverAMonthAgo() throws {
        let now = try Date("2026-11-20T12:00:00Z", strategy: .iso8601)
        func household(_ talked: String?) -> Household {
            var household = HouseholdFixtures.household()
            household.mine.lastTalkedAt = talked
            return household
        }
        let households = [
            household(nil),
            household("2026-10-01T12:00:00+00:00"),
            household("2026-11-01T12:00:00+00:00"),
            household("2026-11-19T12:00:00+00:00"),
        ]
        #expect(Notifications.due(households, now: now) == 2)
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct ActivityModelTests {
        @Test func openingLoadsThenMarksSeen() async {
            let model = ActivityModel(api: stubAPI([ActivityFixtures.feed, ActivityFixtures.noContent]))
            await model.open()
            #expect(requestLog() == ["GET /v1/activity", "POST /v1/activity/seen"])
            #expect(model.items?.map(\.id) == ["a2", "a1"])
            #expect(model.fresh == 1)
            #expect(model.unread == 0)
        }

        @Test func nothingUnreadSkipsTheSeenMarker() async {
            let model = ActivityModel(api: stubAPI([ActivityFixtures.quiet]))
            await model.open()
            #expect(requestLog() == ["GET /v1/activity"])
            #expect(model.items == [])
        }

        @Test func aFailedOpenOffersRetry() async {
            let model = ActivityModel(api: stubAPI([ActivityFixtures.failure, ActivityFixtures.quiet]))
            await model.open()
            #expect(model.failed)
            #expect(model.items == nil)
            await model.open()
            #expect(!model.failed)
        }

        @Test func aFailedRefreshKeepsTheBadge() async {
            let model = ActivityModel(api: stubAPI([ActivityFixtures.feed, ActivityFixtures.failure]))
            await model.refresh()
            #expect(model.unread == 1)
            await model.refresh()
            #expect(model.unread == 1)
        }
    }

    @MainActor @Suite struct DeviceTests {
        private let token = Data([0x0a, 0xff, 0x10])

        private func defaults() -> UserDefaults {
            let name = "DeviceTests-\(UUID())"
            return UserDefaults(suiteName: name) ?? .standard
        }

        @Test func theTokenIsPutWithThisBuildsEnvironment() async throws {
            let defaults = defaults()
            let notifications = Notifications(api: stubAPI([ActivityFixtures.noContent]), defaults: defaults, environment: "sandbox")
            await notifications.registered(token)
            #expect(requestLog() == ["PUT /v1/devices/0aff10"])
            let request = try #require(StubURLProtocol.requests.withLock { $0.first })
            let body = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary
            #expect(body == ["platform": "ios", "env": "sandbox"] as NSDictionary)
            #expect(defaults.string(forKey: Notifications.tokenKey) == "0aff10")
        }

        @Test func aFailedPutIsntRemembered() async {
            let defaults = defaults()
            let notifications = Notifications(api: stubAPI([ActivityFixtures.failure]), defaults: defaults, environment: "production")
            await notifications.registered(token)
            #expect(defaults.string(forKey: Notifications.tokenKey) == nil)
        }

        @Test func signingOutDeletesTheTokenAndTheReminder() async {
            let defaults = defaults()
            defaults.set("0aff10", forKey: Notifications.tokenKey)
            defaults.set(true, forKey: Notifications.reminderKey)
            let notifications = Notifications(api: stubAPI([]), defaults: defaults)
            #expect(notifications.reminderOn)
            await notifications.forget(using: stubAPI([ActivityFixtures.noContent]))
            #expect(requestLog() == ["DELETE /v1/devices/0aff10"])
            #expect(!notifications.reminderOn)
            #expect(defaults.string(forKey: Notifications.tokenKey) == nil)
        }

        @Test func noTokenNoDelete() async {
            let notifications = Notifications(api: stubAPI([]), defaults: defaults())
            await notifications.forget(using: stubAPI([]))
            #expect(requestLog().isEmpty)
        }
    }
}
