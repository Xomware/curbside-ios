import Observation

/// An opened invite link: who invited you to which street, then join. Nothing is joined without the tap.
@MainActor @Observable
final class InviteModel {
    enum State: Equatable {
        case loading
        case ready(InvitePreview)
        /// Spent, expired, or its street was deleted.
        case gone
        case failed
    }

    private(set) var state = State.loading
    private(set) var isJoining = false
    private(set) var joinFailed = false

    let link: InviteLink
    private let api: APIClient

    init(link: InviteLink, api: APIClient) {
        self.link = link
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            state = .ready(try await api.request("/v1/invites/\(link.code)"))
        } catch APIError.server(status: 404, code: "invite_not_found") {
            state = .gone
        } catch {
            state = .failed
        }
    }

    /// The joined street's id, or nil with `joinFailed` set. Accepting a street you're already on answers 200 too.
    func join() async -> String? {
        isJoining = true
        defer { isJoining = false }
        joinFailed = false
        do {
            let place: Place = try await api.request("/v1/invites/\(link.code)/accept", method: "POST")
            return place.id
        } catch APIError.server(status: 404, code: "invite_not_found") {
            state = .gone
            return nil
        } catch {
            joinFailed = true
            return nil
        }
    }
}
