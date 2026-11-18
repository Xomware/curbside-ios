import Foundation
import Testing
@testable import Curbside

/// `me_export` / `me_delete` output under moto.
private enum DataFixtures {
    static let export = StubURLProtocol.Reply(status: 200, body: #"{"data": {"account": {"account_id": "01M7NY1SNA41YEWBBEB2AY2XH0", "display_name": "Test Neighbor", "identities": [{"sub": "sub-test-1", "provider": "google", "created_at": "2026-11-17T23:39:07+00:00"}]}, "maps": [{"map": {"id": "01M7NY1SNF7ZPWVN465J1GA2S4", "name": "Elm St", "center": {"lat": 40, "lng": -75}, "radius_m": 300}, "households": [{"id": "01JCAPTVRE0000000000000HH1", "version": 3, "lat": 40.0001, "building_id": null, "private": {"label": "Blue house", "people": [{"name": "Theo", "birth_year": 2018, "birth_year_approx": false}], "notes": []}, "published": null}]}]}, "error": null, "meta": {}}"#)
    static let revoked = StubURLProtocol.Reply(status: 200, body: #"{"data": {"deleted": true, "apple_revoke": "revoked"}, "error": null, "meta": {}}"#)
    static let manual = StubURLProtocol.Reply(status: 200, body: #"{"data": {"deleted": true, "apple_revoke": "manual", "manual_revoke_url": "https://support.apple.com/en-us/102571"}, "error": null, "meta": {}}"#)
    static let stale = StubURLProtocol.Reply(status: 403, body: #"{"data": null, "error": {"code": "reauth_required", "message": "Sign in with Apple again to delete"}, "meta": {}}"#)
    static func tokens(_ sub: String, _ user: String) -> StubURLProtocol.Reply {
        .init(status: 200, body: #"{"access_token": "fresh", "id_token": "\#(jwt(["sub": sub, "cognito:username": user]))", "refresh_token": "r2"}"#)
    }
}

private let both = [Identity(sub: "sub-apple-1", provider: "apple", createdAt: ""), Identity(sub: "sub-test-1", provider: "google", createdAt: "")]
private let googleOnly = [both[1]]

extension StubbedNetwork {
    @MainActor @Suite struct AccountDataTests {
        @Test func exportWritesThePrettyJSONToATempFile() async throws {
            let (auth, api) = signedIn([DataFixtures.export])
            let model = AccountDataModel(api: api, auth: auth)
            let now = try #require("2026-11-18T09:00:00Z".isoDate)
            let url = try #require(await model.export(now: now))
            defer { try? FileManager.default.removeItem(at: url) }

            #expect(url.lastPathComponent == "curbside-export-2026-11-18.json")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.contains(#""birth_year" : 2018"#))
            #expect(text.contains(#""building_id" : null"#))
            #expect(text.contains(#""lat" : 40.0001"#))
            #expect(model.phase == .idle)
        }

        @Test func appleLinkedDeletesAfterAnAppleSignIn() async throws {
            let (auth, api) = signedIn([DataFixtures.tokens("sub-apple-1", "SignInWithApple_001"), DataFixtures.revoked])
            let model = AccountDataModel(api: api, auth: auth)
            var asked: URL?
            await model.delete(identities: both) { url in
                asked = url
                return cognitoCallback(url)
            }

            #expect(asked?.query()?.contains("identity_provider=SignInWithApple") == true)
            #expect(requestLog() == ["POST /oauth2/token", "DELETE /v1/me"])
            #expect(StubURLProtocol.requests.withLock { $0[1] }.value(forHTTPHeaderField: "Authorization") == "Bearer fresh")
            #expect(!auth.isSignedIn)
        }

        @Test func googleOnlyReauthsWithGoogle() {
            let (auth, api) = signedIn([])
            #expect(AccountDataModel(api: api, auth: auth).reauthProvider(googleOnly) == .google)
        }

        @Test func manualRevokeShowsTheLinkBeforeSigningOut() async {
            let (auth, api) = signedIn([DataFixtures.tokens("sub-apple-1", "SignInWithApple_001"), DataFixtures.manual])
            let model = AccountDataModel(api: api, auth: auth)
            await model.delete(identities: both) { cognitoCallback($0) }

            #expect(model.phase == .deleted(manualRevoke: URL(string: "https://support.apple.com/en-us/102571")!))
            #expect(auth.isSignedIn)
            model.finish()
            #expect(!auth.isSignedIn)
        }

        @Test func aSignInFromAnotherAccountIsTurnedAway() async {
            let (auth, api) = signedIn([DataFixtures.tokens("sub-someone-else", "SignInWithApple_999")])
            let model = AccountDataModel(api: api, auth: auth)
            await model.delete(identities: both) { cognitoCallback($0) }

            #expect(requestLog() == ["POST /oauth2/token"])
            #expect(auth.tokens == googleSession)
            #expect(model.message?.contains("isn't on this account") == true)
        }

        @Test func refusedDeleteSaysSo() async {
            let (auth, api) = signedIn([DataFixtures.tokens("sub-test-1", "Google_1"), DataFixtures.stale])
            let model = AccountDataModel(api: api, auth: auth)
            await model.delete(identities: googleOnly) { cognitoCallback($0) }
            #expect(model.phase == .idle)
            #expect(model.message != nil)
            #expect(auth.isSignedIn)
        }
    }
}
