import Observation

/// An opened friend link: who made it, then accept. Nothing changes without the tap.
@MainActor @Observable
final class FriendInviteModel {
    enum State: Equatable {
        case loading
        case ready(FriendInvitePreview)
        case accepted(Friend)
        /// Spent, expired, or its maker's account is gone.
        case gone
        /// You made this link.
        case own
        case failed
    }

    private(set) var state = State.loading
    private(set) var isAccepting = false
    private(set) var acceptFailed = false

    let link: FriendLink
    private let api: APIClient

    init(link: FriendLink, api: APIClient) {
        self.link = link
        self.api = api
    }

    private var path: String { "/v1/friends/invites/\(link.code)" }

    func load() async {
        state = .loading
        do {
            state = .ready(try await api.request(path))
        } catch APIError.server(status: 404, code: "invite_not_found") {
            state = .gone
        } catch {
            state = .failed
        }
    }

    /// Already being friends answers with the friend too.
    func accept() async {
        isAccepting = true
        defer { isAccepting = false }
        acceptFailed = false
        do {
            state = .accepted(try await api.request("\(path)/accept", method: "POST"))
        } catch APIError.server(status: 404, code: "invite_not_found") {
            state = .gone
        } catch APIError.conflict(code: "own_invite") {
            state = .own
        } catch {
            acceptFailed = true
        }
    }
}
