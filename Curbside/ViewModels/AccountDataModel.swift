import AuthenticationServices
import Foundation
import Observation

/// Your data: export it as a JSON file, or delete the account and everything it owns.
@MainActor @Observable
final class AccountDataModel {
    enum Phase: Equatable {
        case idle
        case working
        /// Gone. Apple couldn't be told to forget the sign-in, so the user does it at this link before signing out.
        case deleted(manualRevoke: URL)
    }

    private(set) var phase = Phase.idle
    private(set) var message: String?

    private let api: APIClient
    private let auth: AuthSession

    init(api: APIClient, auth: AuthSession) {
        self.api = api
        self.auth = auth
    }

    /// The export as a file in the temporary directory, for the share sheet. The caller deletes it afterwards.
    func export(now: Date = .now) async -> URL? {
        phase = .working
        defer { phase = .idle }
        message = nil
        do {
            let tree: JSONTree = try await api.request("/v1/me/export")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let url = FileManager.default.temporaryDirectory.appending(path: "curbside-export-\(now.formatted(.iso8601.year().month().day())).json")
            try encoder.encode(tree).write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            message = "Couldn't export your data. Try again."
            return nil
        }
    }

    /// The server deletes only after a sign-in in the last 10 minutes, with Apple when Apple is linked.
    func reauthProvider(_ identities: [Identity]) -> IdentityProvider {
        identities.contains { $0.kind == .apple } ? .apple : auth.tokens?.provider ?? .google
    }

    /// Signs in again, then deletes. A sign-in that isn't on this account is turned away before it replaces the
    /// session, so picking the wrong Apple ID can't strand the user.
    func delete(identities: [Identity], authenticate: (URL) async throws -> URL) async {
        phase = .working
        message = nil
        do {
            let fresh = try await auth.authorize(with: reauthProvider(identities), authenticate: authenticate)
            guard let sub = fresh.sub, identities.contains(where: { $0.sub == sub }) else {
                phase = .idle
                message = "That sign-in isn't on this account. Use the one you added in Sign-ins."
                return
            }
            try auth.adopt(fresh)
            let result: Deleted = try await api.request("/v1/me", method: "DELETE")
            if result.appleRevoke == "manual", let link = result.manualRevokeURL.flatMap(URL.init(string:)) {
                phase = .deleted(manualRevoke: link)
            } else {
                auth.signOut()
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            phase = .idle
        } catch {
            phase = .idle
            message = "Couldn't finish deleting your account. Try again; it picks up where it stopped."
        }
    }

    func finish() {
        auth.signOut()
    }
}

private struct Deleted: Decodable, Sendable {
    let appleRevoke: String
    let manualRevokeURL: String?

    enum CodingKeys: String, CodingKey {
        case appleRevoke = "apple_revoke"
        case manualRevokeURL = "manual_revoke_url"
    }
}
