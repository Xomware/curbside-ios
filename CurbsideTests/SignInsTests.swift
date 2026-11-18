import Foundation
import Testing
@testable import Curbside

/// An unsigned JWT with these claims; the client only reads them.
func jwt(_ claims: [String: String]) -> String {
    let payload = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString()
        .replacing("+", with: "-").replacing("/", with: "_").replacing("=", with: "")
    return "e30.\(payload).sig"
}

let googleSession = Tokens(access: "a1", id: jwt(["sub": "sub-test-1", "cognito:username": "Google_1234"]), refresh: "r1")

/// `me_get` / `me_unlink` output under moto: Google signed in here, Apple linked.
enum SignInFixtures {
    static let two = #"{"account_id": "01M7P0AH23SVXMJFETTW7BEWM3", "display_name": "Test Neighbor", "created_at": "2026-11-18T00:18:50+00:00", "identities": [{"sub": "sub-apple-1", "provider": "apple", "created_at": "2026-11-18T00:18:50+00:00"}, {"sub": "sub-test-1", "provider": "google", "created_at": "2026-11-18T00:18:50+00:00"}]}"#
    static let one = #"{"account_id": "01M7P0AH23SVXMJFETTW7BEWM3", "display_name": "Test Neighbor", "created_at": "2026-11-18T00:18:50+00:00", "identities": [{"sub": "sub-test-1", "provider": "google", "created_at": "2026-11-18T00:18:50+00:00"}]}"#
    static func me(_ account: String) -> StubURLProtocol.Reply { .init(status: 200, body: #"{"data": \#(account), "error": null, "meta": {}}"#) }
    static let appleTokens = StubURLProtocol.Reply(status: 200, body: #"{"access_token": "a9", "id_token": "apple-id-token", "refresh_token": "r9"}"#)
    static let linked = StubURLProtocol.Reply(status: 201, body: #"{"data": {"sub": "sub-apple-1", "provider": "apple", "created_at": "2026-11-18T00:18:50+00:00"}, "error": null, "meta": {}}"#)
    static func conflict(_ code: String) -> StubURLProtocol.Reply {
        .init(status: 409, body: #"{"data": null, "error": {"code": "\#(code)", "message": "x"}, "meta": {}}"#)
    }
}

/// Answers the authorize URL like Cognito would, echoing its state.
func cognitoCallback(_ url: URL) -> URL {
    let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value ?? ""
    return URL(string: "curbside://auth/callback?code=c1&state=\(state)")!
}

@MainActor
func signedIn(_ replies: [StubURLProtocol.Reply]) -> (AuthSession, APIClient) {
    let store = KeychainTokenStore(service: "com.Xomware.CurbsideTests.\(UUID())")
    try! store.save(googleSession)
    let session = StubURLProtocol.session(replies)
    let auth = AuthSession(cognito: Cognito(domain: URL(string: "https://auth.example.test")!, clientID: "c"), store: store, session: session)
    return (auth, APIClient(baseURL: URL(string: "https://api.example.test")!, tokens: auth, session: session))
}

@Suite struct TokenClaimsTests {
    @Test func subAndProviderComeFromTheIDToken() {
        let apple = Tokens(access: "a", id: jwt(["sub": "s1", "cognito:username": "SignInWithApple_000123.abc"]), refresh: "r")
        #expect(apple.sub == "s1")
        #expect(apple.provider == .apple)
        #expect(googleSession.provider == .google)
        #expect(Tokens(access: "a", id: "opaque", refresh: "r").sub == nil)
    }

    /// `me_create` answers with the profile only.
    @Test func newAccountDecodesWithoutIdentities() throws {
        let account = try JSONDecoder().decode(Account.self, from: Data(#"{"account_id": "a", "display_name": "D", "created_at": "2026-11-18T00:18:50+00:00"}"#.utf8))
        #expect(account.identities == nil)
    }
}

extension StubbedNetwork {
    @MainActor @Suite struct SignInsTests {
        @Test func listsSignInsAndHandsTheAccountBack() async {
            let (auth, api) = signedIn([SignInFixtures.me(SignInFixtures.two)])
            var handed: Account?
            let model = SignInsModel(api: api, auth: auth) { handed = $0 }
            await model.load()
            #expect(model.identities.map(\.name) == ["Apple", "Google"])
            #expect(model.currentSub == "sub-test-1")
            #expect(model.addable.isEmpty)
            #expect(handed?.identities?.count == 2)
        }

        @Test func linkPostsTheNewIDTokenAndKeepsTheSession() async throws {
            let (auth, api) = signedIn([SignInFixtures.me(SignInFixtures.one), SignInFixtures.appleTokens, SignInFixtures.linked, SignInFixtures.me(SignInFixtures.two)])
            let model = SignInsModel(api: api, auth: auth) { _ in }
            await model.load()
            #expect(model.addable == [.apple])

            await model.link(.apple) { cognitoCallback($0) }

            #expect(requestLog() == ["GET /v1/me", "POST /oauth2/token", "POST /v1/me/identities", "GET /v1/me"])
            let post = StubURLProtocol.requests.withLock { $0[2] }
            #expect(StubURLProtocol.body(of: post) == #"{"id_token":"apple-id-token"}"#)
            #expect(post.value(forHTTPHeaderField: "Authorization") == "Bearer a1")
            #expect(auth.tokens == googleSession)
            #expect(model.identities.count == 2)
            #expect(model.message == nil)
        }

        @Test func aSignInWithItsOwnAccountIsRefused() async {
            let (auth, api) = signedIn([SignInFixtures.appleTokens, SignInFixtures.conflict("identity_in_use")])
            let model = SignInsModel(api: api, auth: auth) { _ in }
            await model.link(.apple) { cognitoCallback($0) }
            #expect(model.message?.contains("own Curbside account") == true)
            #expect(auth.tokens == googleSession)
        }

        @Test func removingAnotherSignInKeepsThisOne() async {
            let (auth, api) = signedIn([SignInFixtures.me(SignInFixtures.two), SignInFixtures.me(SignInFixtures.one)])
            let model = SignInsModel(api: api, auth: auth) { _ in }
            await model.load()
            await model.unlink(model.identities[0])
            #expect(requestLog().last == "DELETE /v1/me/identities/sub-apple-1")
            #expect(model.identities.map(\.name) == ["Google"])
            #expect(auth.isSignedIn)
        }

        @Test func removingThisPhonesSignInSignsOut() async {
            let (auth, api) = signedIn([SignInFixtures.me(SignInFixtures.two), SignInFixtures.me(#"{"account_id": "x", "display_name": "x", "identities": [{"sub": "sub-apple-1", "provider": "apple", "created_at": "2026-11-18T00:18:50+00:00"}]}"#)])
            let model = SignInsModel(api: api, auth: auth) { _ in }
            await model.load()
            await model.unlink(model.identities[1])
            #expect(!auth.isSignedIn)
        }

        @Test func theLastSignInStays() async {
            let (auth, api) = signedIn([SignInFixtures.conflict("last_identity")])
            let model = SignInsModel(api: api, auth: auth) { _ in }
            await model.unlink(Identity(sub: "sub-test-1", provider: "google", createdAt: ""))
            #expect(model.message == "That's your only sign-in, so it stays.")
            #expect(auth.isSignedIn)
        }
    }
}
