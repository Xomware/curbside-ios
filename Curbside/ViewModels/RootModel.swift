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
    private var state = Route.loading
    private(set) var isBusy = false
    private(set) var errorMessage: String?

    /// Reads `auth` live, so a sign-out from anywhere (including a dead refresh token inside `APIClient`) lands on sign-in.
    var route: Route {
        auth.isSignedIn ? state : .signedOut
    }

    init(auth: AuthSession, api: APIClient) {
        self.auth = auth
        self.api = api
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
            state = .home(try await api.request("/v1/me", method: "POST", body: NewAccount(displayName: name)))
        } catch APIError.unauthorized {
            // Signed out by APIClient; `route` follows.
        } catch {
            errorMessage = "Couldn't save your name. Try again."
        }
    }

    func signOut() {
        errorMessage = nil
        auth.signOut()
    }
}

private struct NewAccount: Encodable, Sendable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}
