import Foundation
import Testing
@testable import Curbside

/// Bodies follow the API contract for `/friends`, `/friends/invites` and `POST /maps/{id}/members`.
private enum FriendsFixtures {
    static let rosalind = "01M7MYZ2HMEMBER00000000000"
    static let wendell = "01M7MYZ2HWENDELL0000000000"
    static let list = StubURLProtocol.Reply(status: 200, body: #"{"data": [{"account_id": "\#(rosalind)", "display_name": "Rosalind", "since": "2026-11-14T12:00:00+00:00", "shared_maps": [{"map_id": "\#(MapFixtures.mapID)", "name": "Quillfeather Ln"}]}, {"account_id": "\#(wendell)", "display_name": "Wendell", "since": "2026-11-19T18:42:00+00:00", "shared_maps": []}], "error": null, "meta": {}}"#)
    static let invite = StubURLProtocol.Reply(status: 201, body: #"{"data": {"code": "4FRNDQ2K7M", "expires_at": "2026-11-27T12:00:00+00:00"}, "error": null, "meta": {}}"#)
    static let preview = StubURLProtocol.Reply(status: 200, body: #"{"data": {"inviter": {"display_name": "Wendell"}, "expires_at": "2026-11-27T12:00:00+00:00"}, "error": null, "meta": {}}"#)
    static let accepted = StubURLProtocol.Reply(status: 200, body: #"{"data": {"account_id": "\#(wendell)", "display_name": "Wendell", "since": "2026-11-20T12:00:00+00:00", "shared_maps": []}, "error": null, "meta": {}}"#)
    static let memberAdded = StubURLProtocol.Reply(status: 201, body: #"{"data": {"account_id": "\#(wendell)", "display_name": "Wendell", "role": "member", "created_at": "2026-11-20T12:00:00+00:00"}, "error": null, "meta": {}}"#)
    static let members = StubURLProtocol.Reply(status: 200, body: #"{"data": [{"account_id": "01M7MYZ2HA0WNER00000000000", "display_name": "Clementine", "role": "owner", "created_at": "2026-11-17T14:35:52+00:00"}, {"account_id": "\#(rosalind)", "display_name": "Rosalind", "role": "member", "created_at": "2026-11-18T09:00:00+00:00"}], "error": null, "meta": {}}"#)
    static let notFound = StubURLProtocol.Reply(status: 404, body: #"{"data": null, "error": {"code": "invite_not_found", "message": "Invite not found or expired"}, "meta": {}}"#)
    static let own = StubURLProtocol.Reply(status: 409, body: #"{"data": null, "error": {"code": "own_invite", "message": "That's your own friend link"}, "meta": {}}"#)
    static let notFriend = StubURLProtocol.Reply(status: 403, body: #"{"data": null, "error": {"code": "not_friend", "message": "Not your friend"}, "meta": {}}"#)
    static let noContent = StubURLProtocol.Reply(status: 204, body: "")
    static let failure = StubURLProtocol.Reply(status: 500, body: "{}")

    static func place() throws -> Place {
        try JSONDecoder().decode(Place.self, from: Data(MapFixtures.place.utf8))
    }
}

@Suite struct FriendLinkTests {
    @Test(arguments: [
        ("https://curbside.xomware.com/friend/4FRNDQ2K7M", "4FRNDQ2K7M"),
        ("https://curbside.xomware.com/friend/4FRNDQ2K7M/", "4FRNDQ2K7M"),
        ("https://curbside.xomware.com/friend/", nil),
        ("https://curbside.xomware.com/invite/4FRNDQ2K7M", nil),
        ("https://example.com/friend/4FRNDQ2K7M", nil),
    ] as [(String, String?)])
    func readsTheCodeFromAFriendLink(_ url: String, _ code: String?) throws {
        #expect(FriendLink(try #require(URL(string: url)))?.code == code)
    }

    @Test func aFriendLinkIsNotAnInvite() throws {
        #expect(InviteLink(try #require(URL(string: "https://curbside.xomware.com/friend/4FRNDQ2K7M"))) == nil)
        #expect(FriendLink(code: "4FRNDQ2K7M").url.absoluteString == "https://curbside.xomware.com/friend/4FRNDQ2K7M")
    }

    @Test(arguments: ["demo-friends", "demo-friend-invite", "demo-friend-invite-created", "demo-friend-accepted", "demo-member-added"])
    func demoFixturesDecode(_ name: String) throws {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let data = try JSONSerialization.data(withJSONObject: try #require(json?["data"]))
        switch name {
        case "demo-friends": _ = try JSONDecoder().decode([Friend].self, from: data)
        case "demo-friend-invite": _ = try JSONDecoder().decode(FriendInvitePreview.self, from: data)
        case "demo-friend-invite-created": _ = try JSONDecoder().decode(FriendInvite.self, from: data)
        case "demo-member-added": _ = try JSONDecoder().decode(Member.self, from: data)
        default: _ = try JSONDecoder().decode(Friend.self, from: data)
        }
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct FriendsModelTests {
        @Test func listsFriendsWithTheirStreets() async {
            let model = FriendsModel(api: stubAPI([FriendsFixtures.list]))
            await model.load()
            #expect(requestLog() == ["GET /v1/friends"])
            #expect(model.friends?.first?.detail == "On Quillfeather Ln")
            #expect(model.friends?.last?.detail.hasPrefix("Friends since Nov") == true)
        }

        @Test func aFailedLoadSaysSo() async {
            let model = FriendsModel(api: stubAPI([FriendsFixtures.failure]))
            await model.load()
            #expect(model.friends == nil)
            #expect(model.message == "Couldn't load your friends.")
        }

        @Test func removingDeletesAndDrops() async throws {
            let model = FriendsModel(api: stubAPI([FriendsFixtures.list, FriendsFixtures.noContent]))
            await model.load()
            await model.remove(try #require(model.friends?.last))
            #expect(requestLog().last == "DELETE /v1/friends/\(FriendsFixtures.wendell)")
            #expect(model.friends?.map(\.displayName) == ["Rosalind"])
        }

        @Test func aFailedRemoveKeepsThem() async throws {
            let model = FriendsModel(api: stubAPI([FriendsFixtures.list, FriendsFixtures.failure]))
            await model.load()
            await model.remove(try #require(model.friends?.last))
            #expect(model.friends?.count == 2)
            #expect(model.message == "Couldn't remove Wendell.")
        }

        @Test func makesAFriendLink() async {
            let model = FriendsModel(api: stubAPI([FriendsFixtures.invite]))
            await model.makeInvite()
            #expect(requestLog() == ["POST /v1/friends/invites"])
            #expect(model.invite?.link.url.absoluteString == "https://curbside.xomware.com/friend/4FRNDQ2K7M")
        }
    }

    @MainActor @Suite struct FriendInviteModelTests {
        private let link = FriendLink(code: "4FRNDQ2K7M")

        @Test func previewsThenAccepts() async {
            let model = FriendInviteModel(link: link, api: stubAPI([FriendsFixtures.preview, FriendsFixtures.accepted]))
            await model.load()
            #expect(model.state == .ready(FriendInvitePreview(inviter: .init(displayName: "Wendell"))))
            await model.accept()
            #expect(requestLog() == ["GET /v1/friends/invites/4FRNDQ2K7M", "POST /v1/friends/invites/4FRNDQ2K7M/accept"])
            guard case .accepted(let friend) = model.state else {
                Issue.record("expected accepted, got \(model.state)")
                return
            }
            #expect(friend.displayName == "Wendell")
        }

        @Test func aDeadLinkIsUsedUp() async {
            let model = FriendInviteModel(link: link, api: stubAPI([FriendsFixtures.notFound]))
            await model.load()
            #expect(model.state == .gone)
        }

        @Test func yourOwnLinkSaysSo() async {
            let model = FriendInviteModel(link: link, api: stubAPI([FriendsFixtures.preview, FriendsFixtures.own]))
            await model.load()
            await model.accept()
            #expect(model.state == .own)
        }

        @Test func aFailedAcceptCanBeRetried() async {
            let model = FriendInviteModel(link: link, api: stubAPI([FriendsFixtures.preview, FriendsFixtures.failure, FriendsFixtures.accepted]))
            await model.load()
            await model.accept()
            #expect(model.acceptFailed)
            await model.accept()
            #expect(!model.acceptFailed)
        }
    }

    @MainActor @Suite struct AddFriendTests {
        @Test func onlyFriendsOffTheStreetAreOffered() async throws {
            let model = SharingModel(place: try FriendsFixtures.place(), accountID: "01M7MYZ2HA0WNER00000000000", api: stubAPI([FriendsFixtures.members, FriendsFixtures.list]))
            await model.load()
            await model.loadFriends()
            #expect(model.addable.map(\.displayName) == ["Wendell"])
        }

        @Test func addingPostsTheAccountAndListsThem() async throws {
            let model = SharingModel(place: try FriendsFixtures.place(), accountID: "01M7MYZ2HA0WNER00000000000", api: stubAPI([FriendsFixtures.members, FriendsFixtures.list, FriendsFixtures.memberAdded]))
            await model.load()
            await model.loadFriends()
            await model.add(try #require(model.addable.first))
            #expect(requestLog().last == "POST /v1/maps/\(MapFixtures.mapID)/members")
            let request = try #require(StubURLProtocol.requests.withLock { $0.last })
            let body = try JSONSerialization.jsonObject(with: Data(StubURLProtocol.body(of: request).utf8)) as? NSDictionary
            #expect(body == ["account_id": FriendsFixtures.wendell] as NSDictionary)
            #expect(model.members?.map(\.displayName) == ["Clementine", "Rosalind", "Wendell"])
            #expect(model.addable.isEmpty)
        }

        @Test func aNonFriendIsRefused() async throws {
            let model = SharingModel(place: try FriendsFixtures.place(), accountID: "01M7MYZ2HA0WNER00000000000", api: stubAPI([FriendsFixtures.members, FriendsFixtures.list, FriendsFixtures.notFriend]))
            await model.load()
            await model.loadFriends()
            await model.add(try #require(model.addable.first))
            #expect(model.members?.count == 2)
            #expect(model.message == "Couldn't add Wendell.")
        }
    }
}
