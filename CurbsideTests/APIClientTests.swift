import Foundation
import Testing
@testable import Curbside

private actor StubTokens: TokenProvider {
    var access: String? = "old"
    var refreshResult: Result<String, any Error> = .success("new")
    var refreshCount = 0
    var signedOut = false

    init(refresh: Result<String, any Error> = .success("new")) {
        refreshResult = refresh
    }

    func accessToken() -> String? { access }
    func refreshAccessToken() throws -> String {
        refreshCount += 1
        return try refreshResult.get()
    }
    func signOut() { signedOut = true }
}

private struct Spot: Codable, Equatable, Sendable {
    let name: String
}

private struct RefreshRejected: Error {}

private let base = URL(string: "https://api.example.test")!
private let ok = StubURLProtocol.Reply(status: 200, body: #"{"data": {"name": "Maple"}, "error": null, "meta": {}}"#)
private let expired = StubURLProtocol.Reply(status: 401, body: #"{"message": "Unauthorized"}"#)

private func client(_ replies: [StubURLProtocol.Reply], tokens: StubTokens = StubTokens()) -> APIClient {
    APIClient(baseURL: base, tokens: tokens, session: StubURLProtocol.session(replies))
}

private func sentTokens() -> [String?] {
    StubURLProtocol.requests.withLock { $0.map { $0.value(forHTTPHeaderField: "Authorization") } }
}

extension StubbedNetwork {
    @Suite
    struct APIClientTests {
        @Test func decodesDataAndSendsBearer() async throws {
            let spot: Spot = try await client([ok]).request("/spots/1")
            #expect(spot == Spot(name: "Maple"))
            #expect(sentTokens() == ["Bearer old"])
            #expect(StubURLProtocol.requests.withLock { $0.first?.url?.path } == "/spots/1")
        }

        @Test func encodesJSONBody() async throws {
            let _: Spot = try await client([ok]).request("/spots", method: "POST", body: Spot(name: "Maple"))
            let request = try #require(StubURLProtocol.requests.withLock { $0.first })
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        }

        @Test(arguments: [
            (#"{"data": null, "error": null, "meta": {}}"#, 200),
            (#"{"data": {"title": "Maple"}, "error": null, "meta": {}}"#, 200),
            ("<html>Bad Gateway</html>", 200),
        ])
        func malformedSuccessThrows(_ body: String, _ status: Int) async {
            await #expect(throws: APIError.malformed) {
                let _: Spot = try await client([.init(status: status, body: body)]).request("/spots/1")
            }
        }

        @Test(arguments: [
            (404, #"{"data": null, "error": {"code": "needs_onboarding", "message": "No account"}, "meta": {}}"#, APIError.needsOnboarding),
            (409, #"{"data": null, "error": {"code": "conflict", "message": "Taken"}, "meta": {}}"#, .conflict(code: "conflict")),
            (429, #"{"message": "Too Many Requests"}"#, .rateLimited),
            (400, #"{"data": null, "error": {"code": "invalid_request", "message": "Bad"}, "meta": {}}"#, .server(status: 400, code: "invalid_request")),
            (502, "<html>Bad Gateway</html>", .server(status: 502, code: nil)),
        ])
        func errorEnvelopeMaps(_ status: Int, _ body: String, _ expected: APIError) async {
            await #expect(throws: expected) {
                let _: Spot = try await client([.init(status: status, body: body)]).request("/me")
            }
        }

        @Test func refreshesOnceThenRetries() async throws {
            let tokens = StubTokens()
            let spot: Spot = try await client([expired, ok], tokens: tokens).request("/spots/1")
            #expect(spot == Spot(name: "Maple"))
            #expect(sentTokens() == ["Bearer old", "Bearer new"])
            #expect(await tokens.refreshCount == 1)
            #expect(await tokens.signedOut == false)
        }

        @Test func secondUnauthorizedSignsOutWithoutLooping() async {
            let tokens = StubTokens()
            await #expect(throws: APIError.unauthorized) {
                let _: Spot = try await client([expired, expired], tokens: tokens).request("/spots/1")
            }
            #expect(StubURLProtocol.requests.withLock { $0.count } == 2)
            #expect(await tokens.refreshCount == 1)
            #expect(await tokens.signedOut)
        }

        @Test func rejectedRefreshSignsOut() async {
            let tokens = StubTokens(refresh: .failure(RefreshRejected()))
            await #expect(throws: APIError.unauthorized) {
                let _: Spot = try await client([expired], tokens: tokens).request("/spots/1")
            }
            #expect(StubURLProtocol.requests.withLock { $0.count } == 1)
            #expect(await tokens.signedOut)
        }

        @Test func offlineRefreshKeepsSession() async {
            let tokens = StubTokens(refresh: .failure(URLError(.notConnectedToInternet)))
            await #expect(throws: URLError.self) {
                let _: Spot = try await client([expired], tokens: tokens).request("/spots/1")
            }
            #expect(await tokens.signedOut == false)
        }
    }
}
