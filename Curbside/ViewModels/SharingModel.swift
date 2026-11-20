import Foundation
import Observation

/// Who's on a street. The owner makes single-use invite links and removes people; a member can leave.
@MainActor @Observable
final class SharingModel {
    /// Nil while loading, and after a failed load (with `message` set).
    private(set) var members: [Member]?
    private(set) var invite: Invite?
    private(set) var isBusy = false
    private(set) var message: String?

    let place: Place
    let accountID: String
    private let api: APIClient

    init(place: Place, accountID: String, api: APIClient) {
        self.place = place
        self.accountID = accountID
        self.api = api
    }

    var isOwner: Bool { place.role == .owner }

    /// Nobody has joined yet.
    var isAlone: Bool { members?.count == 1 }

    private var path: String { "/v1/maps/\(place.id)" }

    func load() async {
        message = nil
        do {
            members = try await api.request("\(path)/members")
        } catch {
            message = "Couldn't load who's on this street."
        }
    }

    func makeInvite() async {
        await run("Couldn't make an invite link.") {
            invite = try await api.request("\(path)/invites", method: "POST")
        }
    }

    func remove(_ member: Member) async {
        await run("Couldn't remove \(member.displayName).") {
            let _: Removed = try await api.request("\(path)/members/\(member.accountID)", method: "DELETE")
            members?.removeAll { $0.id == member.id }
        }
    }

    /// True once this account is off the street; the caller then opens another.
    func leave() async -> Bool {
        var left = false
        await run("Couldn't leave this street.") {
            let _: Removed = try await api.request("\(path)/members/\(accountID)", method: "DELETE")
            left = true
        }
        return left
    }

    /// "Nov 27": the day the link stops working, in the phone's calendar.
    static func expiry(_ invite: Invite) -> String {
        invite.expiresAt.isoDate?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    }

    private func run(_ failure: String, _ work: () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            try await work()
        } catch {
            message = failure
        }
    }
}

private struct Removed: Decodable, Sendable {
    let removed: Bool
}
