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
/// `SignInFixtures.appleTokens` as the session they become.
private let apple = Tokens(access: "a9", id: "apple-id-token", refresh: "r9")
private let pumpernickel = Account(accountID: "acc1", displayName: "Pumpernickel", identities: [])

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

        @Test func linkingAddsThisSignInToTheOtherAccountThenSwitchesToIt() async throws {
            let (model, store) = try model(signedIn: googleSession, [needsOnboarding, SignInFixtures.appleTokens, SignInFixtures.linked, me])
            defer { try? store.delete() }
            await model.load()
            var providers: [String?] = []

            await model.linkExisting(.apple) { url in
                providers.append(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "identity_provider" }?.value)
                return approve(url)
            }

            #expect(providers == ["SignInWithApple"])
            #expect(requested() == ["GET /v1/me", "POST /oauth2/token", "POST /v1/me/identities", "GET /v1/me"])
            let post = StubURLProtocol.requests.withLock { $0[2] }
            #expect(StubURLProtocol.body(of: post) == #"{"id_token":"\#(googleSession.id)"}"#)
            #expect(post.value(forHTTPHeaderField: "Authorization") == "Bearer a9")
            #expect(try store.load() == apple)
            #expect(model.route == .home(pumpernickel))
            #expect(model.errorMessage == nil)
        }

        @Test func aStaleIDTokenCostsAFreshSignInWithTheSameProvider() async throws {
            let fresh = jwt(["sub": "sub-test-1", "cognito:username": "Google_1234", "auth_time": "now"])
            let (model, store) = try model(signedIn: googleSession, [
                needsOnboarding,
                SignInFixtures.appleTokens,
                .init(status: 400, body: #"{"data": null, "error": {"code": "invalid_id_token", "message": "Invalid ID token"}, "meta": {}}"#),
                .init(status: 200, body: #"{"access_token": "a2", "id_token": "\#(fresh)", "refresh_token": "r2"}"#),
                SignInFixtures.linked,
                me,
            ])
            defer { try? store.delete() }
            await model.load()
            var providers: [String?] = []

            await model.linkExisting(.apple) { url in
                providers.append(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "identity_provider" }?.value)
                return approve(url)
            }

            #expect(providers == ["SignInWithApple", "Google"])
            let posts = StubURLProtocol.requests.withLock { $0.filter { $0.url?.path() == "/v1/me/identities" } }
            #expect(posts.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer a9", "Bearer a9"])
            #expect(posts.map(StubURLProtocol.body(of:)) == [#"{"id_token":"\#(googleSession.id)"}"#, #"{"id_token":"\#(fresh)"}"#])
            #expect(try store.load() == apple)
            #expect(model.route == .home(pumpernickel))
        }

        @Test func anAlreadyLinkedSignInStillSwitches() async throws {
            let (model, store) = try model(signedIn: googleSession, [needsOnboarding, SignInFixtures.appleTokens, SignInFixtures.conflict("already_linked"), me])
            defer { try? store.delete() }
            await model.load()
            await model.linkExisting(.apple, authenticate: approve)
            #expect(try store.load() == apple)
            #expect(model.route == .home(pumpernickel))
        }

        @Test(arguments: [
            (needsOnboarding, "doesn't have a Curbside account either"),
            (SignInFixtures.conflict("identity_in_use"), "can't be merged"),
            (StubURLProtocol.Reply(status: 502, body: "<html>"), "Couldn't add this sign-in"),
        ])
        func aFailedLinkKeepsThisSignInOnOnboarding(_ reply: StubURLProtocol.Reply, _ message: String) async throws {
            let (model, store) = try model(signedIn: googleSession, [needsOnboarding, SignInFixtures.appleTokens, reply])
            defer { try? store.delete() }
            await model.load()
            await model.linkExisting(.apple, authenticate: approve)
            #expect(model.route == .onboarding)
            #expect(model.errorMessage?.contains(message) == true)
            #expect(try store.load() == googleSession)
        }

        @Test func cancellingTheOtherSignInIsSilent() async throws {
            let (model, store) = try model(signedIn: googleSession, [needsOnboarding])
            defer { try? store.delete() }
            await model.load()
            await model.linkExisting(.apple) { _ in throw ASWebAuthenticationSessionError(.canceledLogin) }
            #expect(model.route == .onboarding)
            #expect(model.errorMessage == nil)
            #expect(requested() == ["GET /v1/me"])
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
