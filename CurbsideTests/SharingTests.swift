import Foundation
import Testing
@testable import Curbside

/// Bodies follow curbside-backend's `members_list`, `invites_*` and `members_delete` handlers.
private enum SharingFixtures {
    static let owner = "01M7MYZ2HA0WNER00000000000"
    static let member = "01M7MYZ2HMEMBER00000000000"
    static let members = StubURLProtocol.Reply(status: 200, body: #"{"data": [{"account_id": "\#(owner)", "display_name": "Clementine", "role": "owner", "created_at": "2026-11-17T14:35:52+00:00"}, {"account_id": "\#(member)", "display_name": "Rosalind", "role": "member", "created_at": "2026-11-18T09:00:00+00:00"}], "error": null, "meta": {}}"#)
    static let invite = StubURLProtocol.Reply(status: 201, body: #"{"data": {"code": "7KQ2M9XH4D", "expires_at": "2026-11-27T14:35:52+00:00"}, "error": null, "meta": {}}"#)
    static let removed = StubURLProtocol.Reply(status: 200, body: #"{"data": {"removed": true}, "error": null, "meta": {}}"#)
    static let preview = StubURLProtocol.Reply(status: 200, body: #"{"data": {"code": "7KQ2M9XH4D", "map": {"id": "\#(MapFixtures.mapID)", "name": "Quillfeather Ln"}, "invited_by": "Clementine", "expires_at": "2026-11-27T14:35:52+00:00", "already_member": false}, "error": null, "meta": {}}"#)
    static let accepted = StubURLProtocol.Reply(status: 200, body: #"{"data": \#(MapFixtures.shared), "error": null, "meta": {}}"#)
    static let notFound = StubURLProtocol.Reply(status: 404, body: #"{"data": null, "error": {"code": "invite_not_found", "message": "Invite not found or expired"}, "meta": {}}"#)
    static let failure = StubURLProtocol.Reply(status: 500, body: "{}")

    static func place(_ role: Place.Role) throws -> Place {
        let json = MapFixtures.place.replacingOccurrences(of: #""role": "owner""#, with: #""role": "\#(role.rawValue)""#)
        return try JSONDecoder().decode(Place.self, from: Data(json.utf8))
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct SharingModelTests {
        @Test func loadsMembersOwnerFirst() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.owner), accountID: SharingFixtures.owner, api: stubAPI([SharingFixtures.members]))
            await model.load()
            #expect(requestLog() == ["GET /v1/maps/\(MapFixtures.mapID)/members"])
            #expect(model.members?.map(\.displayName) == ["Clementine", "Rosalind"])
            #expect(model.members?.first?.role == .owner)
            #expect(model.isOwner)
            #expect(!model.isAlone)
        }

        @Test func aFailedLoadSaysSoAndRetries() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.owner), accountID: SharingFixtures.owner, api: stubAPI([SharingFixtures.failure, SharingFixtures.members]))
            await model.load()
            #expect(model.members == nil)
            #expect(model.message == "Couldn't load who's on this street.")
            await model.load()
            #expect(model.members?.count == 2)
            #expect(model.message == nil)
        }

        @Test func theOwnerMakesASingleUseLink() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.owner), accountID: SharingFixtures.owner, api: stubAPI([SharingFixtures.invite]))
            await model.makeInvite()
            #expect(requestLog() == ["POST /v1/maps/\(MapFixtures.mapID)/invites"])
            let invite = try #require(model.invite)
            #expect(invite.link.url.absoluteString == "https://curbside.xomware.com/invite/7KQ2M9XH4D")
            #expect(SharingModel.expiry(invite).contains("27"))
        }

        @Test func theOwnerRemovesSomeone() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.owner), accountID: SharingFixtures.owner, api: stubAPI([SharingFixtures.members, SharingFixtures.removed]))
            await model.load()
            let rosalind = try #require(model.members?.last)
            await model.remove(rosalind)
            #expect(requestLog().last == "DELETE /v1/maps/\(MapFixtures.mapID)/members/\(SharingFixtures.member)")
            #expect(model.members?.map(\.displayName) == ["Clementine"])
            #expect(model.isAlone)
        }

        @Test func aFailedRemoveKeepsThemListed() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.owner), accountID: SharingFixtures.owner, api: stubAPI([SharingFixtures.members, SharingFixtures.failure]))
            await model.load()
            await model.remove(try #require(model.members?.last))
            #expect(model.members?.count == 2)
            #expect(model.message == "Couldn't remove Rosalind.")
        }

        @Test func aMemberLeavesByRemovingThemself() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.member), accountID: SharingFixtures.member, api: stubAPI([SharingFixtures.removed]))
            #expect(!model.isOwner)
            #expect(await model.leave())
            #expect(requestLog() == ["DELETE /v1/maps/\(MapFixtures.mapID)/members/\(SharingFixtures.member)"])
        }

        @Test func aFailedLeaveStays() async throws {
            let model = SharingModel(place: try SharingFixtures.place(.member), accountID: SharingFixtures.member, api: stubAPI([SharingFixtures.failure]))
            #expect(await model.leave() == false)
            #expect(model.message == "Couldn't leave this street.")
        }
    }

    @MainActor @Suite struct InviteModelTests {
        private let link = InviteLink(code: "7KQ2M9XH4D")

        @Test func previewsWithoutJoining() async throws {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.preview]))
            await model.load()
            guard case .ready(let invite) = model.state else {
                Issue.record("expected a preview, got \(model.state)")
                return
            }
            #expect(invite.invitedBy == "Clementine")
            #expect(invite.map.name == "Quillfeather Ln")
            #expect(!invite.alreadyMember)
            #expect(requestLog() == ["GET /v1/invites/7KQ2M9XH4D"])
        }

        @Test func aSpentInviteIsUsedUp() async {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.notFound]))
            await model.load()
            #expect(model.state == .gone)
        }

        @Test func aServerErrorOffersRetry() async {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.failure]))
            await model.load()
            #expect(model.state == .failed)
        }

        @Test func joiningAnswersWithTheStreetToOpen() async {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.preview, SharingFixtures.accepted]))
            await model.load()
            #expect(await model.join() == MapFixtures.sharedID)
            #expect(requestLog().last == "POST /v1/invites/7KQ2M9XH4D/accept")
            #expect(!model.joinFailed)
        }

        @Test func anInviteSpentWhileOpenTurnsUsedUp() async {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.preview, SharingFixtures.notFound]))
            await model.load()
            #expect(await model.join() == nil)
            #expect(model.state == .gone)
        }

        @Test func aFailedJoinCanBeRetried() async {
            let model = InviteModel(link: link, api: stubAPI([SharingFixtures.preview, SharingFixtures.failure, SharingFixtures.accepted]))
            await model.load()
            #expect(await model.join() == nil)
            #expect(model.joinFailed)
            #expect(await model.join() == MapFixtures.sharedID)
            #expect(!model.joinFailed)
        }
    }
}

@Suite struct InviteLinkTests {
    @Test(arguments: [
        ("https://curbside.xomware.com/invite/7KQ2M9XH4D", "7KQ2M9XH4D"),
        ("https://curbside.xomware.com/invite/7KQ2M9XH4D/", "7KQ2M9XH4D"),
        ("https://curbside.xomware.com/invite/", nil),
        ("https://curbside.xomware.com/privacy", nil),
        ("https://curbside.xomware.com/invite/7KQ2M9XH4D/extra", nil),
        ("https://example.com/invite/7KQ2M9XH4D", nil),
        ("curbside://auth/callback?code=c1", nil),
    ] as [(String, String?)])
    func readsTheCodeFromAnInviteLink(_ url: String, _ code: String?) throws {
        #expect(InviteLink(try #require(URL(string: url)))?.code == code)
    }

    @Test(arguments: ["demo-maps", "demo-map-shared", "demo-members", "demo-members-shared", "demo-invite", "demo-invite-created", "demo-invite-accepted"])
    func demoFixturesDecode(_ name: String) throws {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "json"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let data = try JSONSerialization.data(withJSONObject: try #require(json?["data"]))
        struct Loaded: Decodable { let map: Place; let households: [Household] }
        switch name {
        case "demo-maps": _ = try JSONDecoder().decode([Place].self, from: data)
        case "demo-map-shared": _ = try JSONDecoder().decode(Loaded.self, from: data)
        case "demo-members", "demo-members-shared": _ = try JSONDecoder().decode([Member].self, from: data)
        case "demo-invite": _ = try JSONDecoder().decode(InvitePreview.self, from: data)
        case "demo-invite-created": _ = try JSONDecoder().decode(Invite.self, from: data)
        default: _ = try JSONDecoder().decode(Place.self, from: data)
        }
    }
}
