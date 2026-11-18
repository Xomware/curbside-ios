import AuthenticationServices
import Observation

/// The sign-ins linked to this account: add the other provider, or remove one. Accounts are never merged, so a
/// sign-in that already has its own account can't be added.
@MainActor @Observable
final class SignInsModel {
    private(set) var identities: [Identity] = []
    private(set) var isBusy = false
    private(set) var message: String?

    private let api: APIClient
    private let auth: AuthSession
    private let updated: (Account) -> Void

    init(api: APIClient, auth: AuthSession, updated: @escaping (Account) -> Void) {
        self.api = api
        self.auth = auth
        self.updated = updated
    }

    var currentSub: String? { auth.tokens?.sub }

    var addable: [IdentityProvider] {
        IdentityProvider.allCases.filter { provider in !identities.contains { $0.kind == provider } }
    }

    func load() async {
        do {
            accept(try await api.request("/v1/me"))
        } catch {
            message = "Couldn't load your sign-ins."
        }
    }

    /// A fresh sign-in with `provider`; its ID token links it. The session stays the one already signed in.
    func link(_ provider: IdentityProvider, authenticate: (URL) async throws -> URL) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            let tokens = try await auth.authorize(with: provider, authenticate: authenticate)
            _ = try await api.link(idToken: tokens.id)
            await load()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch APIError.conflict(code: "identity_in_use") {
            message = "That sign-in already has its own Curbside account. Delete that account first, then add it here."
        } catch APIError.conflict(code: "already_linked") {
            await load()
        } catch {
            message = "Couldn't add that sign-in. Try again."
        }
    }

    /// Removing the sign-in this phone uses signs it out: that sign-in no longer reaches the account.
    func unlink(_ identity: Identity) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            accept(try await api.request("/v1/me/identities/\(identity.sub)", method: "DELETE"))
            if identity.sub == currentSub { auth.signOut() }
        } catch APIError.conflict(code: "last_identity") {
            message = "That's your only sign-in, so it stays."
        } catch {
            message = "Couldn't remove that sign-in. Try again."
        }
    }

    private func accept(_ account: Account) {
        identities = account.identities ?? []
        updated(account)
    }
}
