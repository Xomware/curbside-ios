import Observation

/// Your friends and the streets you share with each, plus a single-use link to make a new one.
@MainActor @Observable
final class FriendsModel {
    /// Nil while loading, and after a failed load (with `message` set).
    private(set) var friends: [Friend]?
    private(set) var invite: FriendInvite?
    private(set) var isBusy = false
    private(set) var message: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        message = nil
        do {
            friends = try await api.request("/v1/friends")
        } catch {
            message = "Couldn't load your friends."
        }
    }

    func makeInvite() async {
        await run("Couldn't make a friend link.") {
            invite = try await api.request("/v1/friends/invites", method: "POST")
        }
    }

    /// Unfriends both ways. Streets you share stay shared.
    func remove(_ friend: Friend) async {
        await run("Couldn't remove \(friend.displayName).") {
            try await api.send("/v1/friends/\(friend.accountID)", method: "DELETE")
            friends?.removeAll { $0.id == friend.id }
        }
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
