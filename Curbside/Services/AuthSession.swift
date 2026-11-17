import Foundation
import Observation

/// The signed-in Cognito session: PKCE sign-in, refresh and sign-out, with tokens kept in the Keychain.
@MainActor @Observable
final class AuthSession: TokenProvider {
    private(set) var tokens: Tokens?
    var isSignedIn: Bool { tokens != nil }

    private let cognito: Cognito
    private let store: KeychainTokenStore
    private let session: URLSession
    @ObservationIgnored private var refreshing: Task<Tokens, any Error>?

    init(cognito: Cognito, store: KeychainTokenStore = KeychainTokenStore(), session: URLSession = .shared) {
        self.cognito = cognito
        self.store = store
        self.session = session
        // Unreadable tokens are no session; signing in again overwrites the item.
        tokens = try? store.load()
    }

    /// `authenticate` presents the authorize URL and returns the `curbside://` callback URL.
    func signIn(with provider: IdentityProvider, authenticate: (URL) async throws -> URL) async throws {
        let pkce = PKCE.random()
        let state = randomToken()
        let callback = try await authenticate(cognito.authorizeURL(provider, pkce: pkce, state: state))
        let code = try cognito.code(from: callback, state: state)
        let tokens = try await cognito.exchange([
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": pkce.verifier,
            "redirect_uri": Cognito.redirectURI,
        ], session: session)
        try store.save(tokens)
        self.tokens = tokens
    }

    func accessToken() -> String? {
        tokens?.access
    }

    /// Concurrent 401s share one refresh request instead of each spending the refresh token.
    func refreshAccessToken() async throws -> String {
        if let refreshing { return try await refreshing.value.access }
        guard let refresh = tokens?.refresh else { throw AuthError.signedOut }

        let task = Task {
            try await cognito.exchange(
                ["grant_type": "refresh_token", "refresh_token": refresh],
                session: session,
                keepingRefresh: refresh
            )
        }
        refreshing = task
        defer { refreshing = nil }
        let fresh = try await task.value

        // A sign-out while the request was in flight wins; don't resurrect the session.
        guard tokens?.refresh == refresh else { throw AuthError.signedOut }
        try store.save(fresh)
        tokens = fresh
        return fresh.access
    }

    func signOut() {
        tokens = nil
        // The protocol can't throw and there is nothing to retry; a failed delete only means a stale item at next launch.
        try? store.delete()
    }
}
