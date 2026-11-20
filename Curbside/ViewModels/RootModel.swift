import AuthenticationServices
import Foundation
import Observation

/// Decides which screen the app shows: sign-in, onboarding, or home.
@MainActor @Observable
final class RootModel {
    enum Route: Equatable {
        case signedOut
        case loading
        case onboarding
        case home(Account)
        case failed
    }

    let auth: AuthSession
    let api: APIClient
    let lock: AppLock
    let defaults: UserDefaults
    /// An opened invite link waits here through sign-in and onboarding; home shows it.
    var pendingInvite: InviteLink?
    private var state = Route.loading
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    /// Reads `auth` live, so a sign-out from anywhere (including a dead refresh token inside `APIClient`) lands on sign-in.
    var route: Route {
        auth.isSignedIn ? state : .signedOut
    }

    init(auth: AuthSession, api: APIClient, lock: AppLock = AppLock(), defaults: UserDefaults = .standard) {
        self.auth = auth
        self.api = api
        self.lock = lock
        self.defaults = defaults
    }

    static func live() -> RootModel {
        let auth = AuthSession(cognito: Config.cognito)
        return RootModel(auth: auth, api: APIClient(baseURL: Config.apiBaseURL, tokens: auth))
    }

    /// Trimmed name if the backend will accept it (1-80 characters), else nil.
    nonisolated static func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...80).contains(name.count) ? name : nil
    }

    func load() async {
        guard auth.isSignedIn else { return }
        state = .loading
        do {
            state = .home(try await api.request("/v1/me"))
        } catch APIError.needsOnboarding {
            state = .onboarding
        } catch APIError.unauthorized {
            // APIClient already signed out; `route` follows.
        } catch {
            state = .failed
        }
    }

    func signIn(with provider: IdentityProvider, authenticate: (URL) async throws -> URL) async {
        // Without this, the previous account's home flashes between token save and `GET /me`.
        state = .loading
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await auth.signIn(with: provider, authenticate: authenticate)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            errorMessage = "Sign-in didn't finish. Try again."
            return
        }
        await load()
    }

    func createAccount(named raw: String) async {
        guard let name = Self.validName(raw) else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            state = .home(try await api.request("/v1/me", method: "POST", body: DisplayName(displayName: name)))
        } catch APIError.unauthorized {
            // Signed out by APIClient; `route` follows.
        } catch {
            errorMessage = "Couldn't save your name. Try again."
        }
    }

    /// Onboarding's "I already use Curbside": sign in to that account with `provider`, then add the sign-in this phone
    /// holds to it and switch to the account. The server wants an ID token under 10 minutes old, so a stale one costs
    /// a fresh sign-in with the same provider. Nothing is adopted until the link lands.
    func linkExisting(_ provider: IdentityProvider, authenticate: (URL) async throws -> URL) async {
        guard let orphan = auth.tokens else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            let existing = try await auth.authorize(with: provider, authenticate: authenticate)
            let api = APIClient(baseURL: api.baseURL, tokens: Bearer(access: existing.access), session: api.session)
            do {
                try await Self.link(orphan.id, with: api)
            } catch APIError.server(status: 400, code: "invalid_id_token") {
                guard let again = orphan.provider else { throw AuthError.malformed }
                try await Self.link(try await auth.authorize(with: again, authenticate: authenticate).id, with: api)
            }
            try auth.adopt(existing)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch is AuthError {
            errorMessage = "Sign-in didn't finish. Try again."
            return
        } catch APIError.needsOnboarding {
            errorMessage = "That sign-in doesn't have a Curbside account either. Pick the one you set Curbside up with."
            return
        } catch APIError.conflict(code: "identity_in_use") {
            errorMessage = "That sign-in has its own Curbside account. Accounts can't be merged: export and delete one first."
            return
        } catch {
            errorMessage = "Couldn't add this sign-in to that account. Try again."
            return
        }
        await load()
    }

    /// `already_linked` is a retry of a link that landed.
    private static func link(_ idToken: String, with api: APIClient) async throws {
        do {
            _ = try await api.link(idToken: idToken)
        } catch APIError.conflict(code: "already_linked") {}
    }

    /// Settings' name change. False leaves the old name.
    func rename(to raw: String) async -> Bool {
        guard let name = Self.validName(raw) else { return false }
        do {
            update(try await api.request("/v1/me", method: "PATCH", body: DisplayName(displayName: name)))
            return true
        } catch {
            return false
        }
    }

    /// Settings changed the account (a sign-in added or removed).
    func update(_ account: Account) {
        if case .home = state { state = .home(account) }
    }

    func signOut() {
        errorMessage = nil
        auth.signOut()
    }
}

private struct DisplayName: Encodable, Sendable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

/// A fixed access token for one call made as another account. Fresh from sign-in, so there is nothing to refresh.
private struct Bearer: TokenProvider {
    let access: String

    func accessToken() async -> String? { access }
    func refreshAccessToken() async throws -> String { throw AuthError.signedOut }
    func signOut() async {}
}
