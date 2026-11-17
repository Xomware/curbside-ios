import AuthenticationServices
import Foundation
import Testing
@testable import Curbside

private let cognito = Cognito(domain: URL(string: "https://auth.example.test")!, clientID: "client123")
private let signedIn = Tokens(access: "a1", id: "i1", refresh: "r1")

private let me = StubURLProtocol.Reply(
    status: 200,
    body: #"{"data": {"account_id": "acc1", "display_name": "Pumpernickel", "created_at": "2026-11-17T00:00:00+00:00", "identities": []}, "error": null, "meta": {}}"#
)
private let created = StubURLProtocol.Reply(status: 201, body: me.body)
private let needsOnboarding = StubURLProtocol.Reply(
    status: 404,
    body: #"{"data": null, "error": {"code": "needs_onboarding", "message": "No account"}, "meta": {}}"#
)
private let issued = StubURLProtocol.Reply(status: 200, body: #"{"access_token": "a1", "id_token": "i1", "refresh_token": "r1"}"#)
private let pumpernickel = Account(accountID: "acc1", displayName: "Pumpernickel")

/// One stub session serves both Cognito and the API, in reply order. The Keychain item is per test.
@MainActor
private func model(signedIn tokens: Tokens?, _ replies: [StubURLProtocol.Reply]) throws -> (RootModel, KeychainTokenStore) {
    let store = KeychainTokenStore(service: "com.Xomware.CurbsideTests.\(UUID())")
    if let tokens { try store.save(tokens) }
    let session = StubURLProtocol.session(replies)
    let auth = AuthSession(cognito: cognito, store: store, session: session)
    return (RootModel(auth: auth, api: APIClient(baseURL: URL(string: "https://api.example.test")!, tokens: auth, session: session)), store)
}

/// Plays Cognito's part: echoes the request's state back on the callback.
private func approve(_ url: URL) -> URL {
    let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value ?? ""
    return URL(string: "curbside://auth/callback?code=c1&state=\(state)")!
}

private func requested() -> [String] {
    StubURLProtocol.requests.withLock { $0.map { "\($0.httpMethod ?? "") \($0.url?.path() ?? "")" } }
}

extension StubbedNetwork {
    @MainActor @Suite struct RootModelTests {
        @Test func noTokensStaysOnSignInWithoutCallingTheAPI() async throws {
            let (model, _) = try model(signedIn: nil, [])
            await model.load()
            #expect(model.route == .signedOut)
            #expect(requested().isEmpty)
        }

        @Test func existingAccountGoesHome() async throws {
            let (model, store) = try model(signedIn: signedIn, [me])
            defer { try? store.delete() }
            await model.load()
            #expect(model.route == .home(pumpernickel))
            #expect(requested() == ["GET /v1/me"])
        }

        @Test func newAccountOnboardsThenGoesHome() async throws {
            let (model, store) = try model(signedIn: signedIn, [needsOnboarding, created])
            defer { try? store.delete() }
            await model.load()
            #expect(model.route == .onboarding)

            await model.createAccount(named: "  Pumpernickel ")

            #expect(model.route == .home(pumpernickel))
            let post = try #require(StubURLProtocol.requests.withLock { $0.last })
            #expect(post.httpMethod == "POST")
            #expect(StubURLProtocol.body(of: post) == #"{"display_name":"Pumpernickel"}"#)
        }

        @Test(arguments: ["", "   ", String(repeating: "x", count: 81)])
        func invalidNameIsNotSent(_ name: String) async throws {
            let (model, store) = try model(signedIn: signedIn, [needsOnboarding])
            defer { try? store.delete() }
            await model.load()
            await model.createAccount(named: name)
            #expect(model.route == .onboarding)
            #expect(requested() == ["GET /v1/me"])
        }

        @Test func deadRefreshTokenReturnsToSignIn() async throws {
            let (model, store) = try model(signedIn: signedIn, [
                .init(status: 401, body: #"{"message": "Unauthorized"}"#),
                .init(status: 400, body: #"{"error": "invalid_grant"}"#),
            ])
            await model.load()
            #expect(model.route == .signedOut)
            #expect(try store.load() == nil)
        }

        @Test func serverErrorOffersRetry() async throws {
            let (model, store) = try model(signedIn: signedIn, [.init(status: 502, body: "<html>"), me])
            defer { try? store.delete() }
            await model.load()
            #expect(model.route == .failed)
            await model.load()
            #expect(model.route == .home(pumpernickel))
        }

        @Test func signInRoutesFirstSignInToOnboarding() async throws {
            let (model, store) = try model(signedIn: nil, [issued, needsOnboarding])
            defer { try? store.delete() }
            await model.signIn(with: .google, authenticate: approve)
            #expect(model.route == .onboarding)
            #expect(requested() == ["POST /oauth2/token", "GET /v1/me"])
            #expect(try store.load() == signedIn)
        }

        @Test func cancelledSignInIsSilent() async throws {
            let (model, _) = try model(signedIn: nil, [])
            await model.signIn(with: .apple) { _ in throw ASWebAuthenticationSessionError(.canceledLogin) }
            #expect(model.route == .signedOut)
            #expect(model.errorMessage == nil)
        }

        @Test func signOutReturnsToSignIn() async throws {
            let (model, store) = try model(signedIn: signedIn, [me])
            await model.load()
            model.signOut()
            #expect(model.route == .signedOut)
            #expect(try store.load() == nil)
        }
    }
}
