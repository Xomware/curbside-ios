import Foundation
import Testing
@testable import Curbside

private let cognito = Cognito(domain: URL(string: "https://auth.example.test")!, clientID: "client123")
private let issued = StubURLProtocol.Reply(
    status: 200,
    body: #"{"access_token": "a1", "id_token": "i1", "refresh_token": "r1", "expires_in": 3600, "token_type": "Bearer"}"#
)
private let refreshed = StubURLProtocol.Reply(
    status: 200,
    body: #"{"access_token": "a2", "id_token": "i2", "expires_in": 3600, "token_type": "Bearer"}"#
)

private func query(_ url: URL) -> [String: String] {
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

private func form(_ body: String) -> [String: String] {
    query(URL(string: "x:?\(body)")!)
}

private func testStore() -> KeychainTokenStore {
    KeychainTokenStore(service: "com.Xomware.CurbsideTests.\(UUID())")
}

@Test func pkceMatchesRFC7636Vector() {
    let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

@Test func randomVerifierIsURLSafeAndUnique() {
    let a = PKCE.random().verifier
    #expect(a.count == 43)
    #expect(a.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    #expect(a != PKCE.random().verifier)
}

@Test(arguments: IdentityProvider.allCases)
func authorizeURLCarriesPKCEAndState(_ provider: IdentityProvider) {
    let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    let url = cognito.authorizeURL(provider, pkce: pkce, state: "s1")
    #expect(url.host() == "auth.example.test")
    #expect(url.path() == "/oauth2/authorize")
    #expect(query(url) == [
        "response_type": "code",
        "client_id": "client123",
        "redirect_uri": "curbside://auth/callback",
        "identity_provider": provider.rawValue,
        "scope": "openid",
        "state": "s1",
        "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        "code_challenge_method": "S256",
    ])
}

@Test func callbackYieldsTheCode() throws {
    #expect(try cognito.code(from: URL(string: "curbside://auth/callback?code=abc&state=s1")!, state: "s1") == "abc")
}

@Test(arguments: [
    ("curbside://auth/callback?code=abc&state=forged", AuthError.stateMismatch),
    ("curbside://auth/callback?code=abc", .stateMismatch),
    ("curbside://auth/callback?error=access_denied&error_description=Nope&state=s1", .denied("Nope")),
    ("curbside://auth/callback?state=s1", .missingCode),
])
func badCallbackIsRejected(_ callback: String, _ expected: AuthError) {
    #expect(throws: expected) {
        try cognito.code(from: URL(string: callback)!, state: "s1")
    }
}

@Test func tokenRequestIsFormEncoded() throws {
    let request = cognito.tokenRequest(["grant_type": "refresh_token", "refresh_token": "a+b/c="])
    #expect(request.url?.absoluteString == "https://auth.example.test/oauth2/token")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
    let body = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(body == "client_id=client123&grant_type=refresh_token&refresh_token=a%2Bb%2Fc%3D")
}

extension StubbedNetwork {
    @Suite struct TokenExchangeTests {
        @Test func parsesIssuedTokens() async throws {
            let tokens = try await cognito.exchange([:], session: StubURLProtocol.session([issued]))
            #expect(tokens == Tokens(access: "a1", id: "i1", refresh: "r1"))
        }

        @Test func refreshResponseKeepsTheRefreshToken() async throws {
            let tokens = try await cognito.exchange([:], session: StubURLProtocol.session([refreshed]), keepingRefresh: "r1")
            #expect(tokens == Tokens(access: "a2", id: "i2", refresh: "r1"))
        }

        @Test(arguments: [
            (400, #"{"error": "invalid_grant"}"#, AuthError.rejected("invalid_grant")),
            (400, "<html>", .malformed),
            (200, #"{"access_token": "a2"}"#, .malformed),
            (200, refreshed.body, .malformed),
        ])
        func failuresMapToAuthError(_ status: Int, _ body: String, _ expected: AuthError) async {
            await #expect(throws: expected) {
                _ = try await cognito.exchange([:], session: StubURLProtocol.session([.init(status: status, body: body)]))
            }
        }

        @Test func serverErrorIsTransient() async {
            await #expect(throws: URLError.self) {
                _ = try await cognito.exchange([:], session: StubURLProtocol.session([.init(status: 503, body: "")]))
            }
        }

        @MainActor @Test func signInExchangesTheCodeWithTheVerifier() async throws {
            let store = testStore()
            defer { try? store.delete() }
            let auth = AuthSession(cognito: cognito, store: store, session: StubURLProtocol.session([issued]))
            var challenge = ""

            try await auth.signIn(with: .google) { url in
                let params = query(url)
                challenge = params["code_challenge"] ?? ""
                return URL(string: "curbside://auth/callback?code=c1&state=\(params["state"] ?? "")")!
            }

            #expect(auth.tokens == Tokens(access: "a1", id: "i1", refresh: "r1"))
            #expect(try store.load() == auth.tokens)
            let sent = form(StubURLProtocol.body(of: try #require(StubURLProtocol.requests.withLock { $0.first })))
            #expect(sent["grant_type"] == "authorization_code")
            #expect(sent["code"] == "c1")
            #expect(sent["redirect_uri"] == "curbside://auth/callback")
            #expect(PKCE(verifier: sent["code_verifier"] ?? "").challenge == challenge)
        }

        @MainActor @Test func forgedCallbackNeverReachesTheTokenEndpoint() async {
            let auth = AuthSession(cognito: cognito, store: testStore(), session: StubURLProtocol.session([]))
            await #expect(throws: AuthError.stateMismatch) {
                try await auth.signIn(with: .apple) { _ in URL(string: "curbside://auth/callback?code=c1&state=forged")! }
            }
            #expect(StubURLProtocol.requests.withLock { $0.isEmpty })
            #expect(!auth.isSignedIn)
        }

        @MainActor @Test func concurrentRefreshesShareOneRequest() async throws {
            let store = testStore()
            defer { try? store.delete() }
            try store.save(Tokens(access: "a1", id: "i1", refresh: "r1"))
            let auth = AuthSession(cognito: cognito, store: store, session: StubURLProtocol.session([refreshed]))
            #expect(auth.isSignedIn)

            async let first = auth.refreshAccessToken()
            async let second = auth.refreshAccessToken()
            #expect(try await [first, second] == ["a2", "a2"])

            #expect(StubURLProtocol.requests.withLock { $0.count } == 1)
            #expect(try store.load() == Tokens(access: "a2", id: "i2", refresh: "r1"))
        }

        @MainActor @Test func signOutClearsTheKeychain() throws {
            let store = testStore()
            try store.save(Tokens(access: "a1", id: "i1", refresh: "r1"))
            let auth = AuthSession(cognito: cognito, store: store)

            auth.signOut()

            #expect(!auth.isSignedIn)
            #expect(try store.load() == nil)
            #expect(!AuthSession(cognito: cognito, store: store).isSignedIn)
        }
    }
}
