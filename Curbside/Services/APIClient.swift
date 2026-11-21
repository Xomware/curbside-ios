import Foundation

/// The auth session behind `APIClient`. S2b's Cognito session implements it.
protocol TokenProvider: Sendable {
    func accessToken() async -> String?
    /// Returns a new access token. Any error other than `URLError` signs the user out.
    func refreshAccessToken() async throws -> String
    func signOut() async
}

struct APIClient: Sendable {
    let baseURL: URL
    let tokens: any TokenProvider
    var session: URLSession = .shared

    func request<T: Decodable & Sendable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable & Sendable)? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            return try await send(request, token: await tokens.accessToken())
        } catch APIError.unauthorized {
            // One refresh, one retry. A second 401 means the session is dead, not stale.
            let fresh: String
            do {
                fresh = try await tokens.refreshAccessToken()
            } catch let error as URLError {
                throw error
            } catch {
                await tokens.signOut()
                throw APIError.unauthorized
            }
            do {
                return try await send(request, token: fresh)
            } catch APIError.unauthorized {
                await tokens.signOut()
                throw APIError.unauthorized
            }
        }
    }

    private func send<T: Decodable>(_ request: URLRequest, token: String?) async throws -> T {
        var request = request
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data)

        if status == 204, let none = NoContent() as? T { return none }
        if (200..<300).contains(status) {
            guard let value = envelope?.data else { throw APIError.malformed }
            return value
        }
        // API Gateway's authorizer and throttling answer with a bare `{"message": ...}`, so match on status first.
        switch (status, envelope?.error?.code) {
        case (401, _): throw APIError.unauthorized
        case (429, _): throw APIError.rateLimited
        case (409, _): throw APIError.conflict(code: envelope?.error?.code)
        case (_, "needs_onboarding"): throw APIError.needsOnboarding
        case (_, let code): throw APIError.server(status: status, code: code)
        }
    }
}

/// A 204's answer: no envelope, nothing to decode.
struct NoContent: Decodable, Sendable {}

extension APIClient {
    func send(_ path: String, method: String, body: (any Encodable & Sendable)? = nil) async throws {
        let _: NoContent = try await request(path, method: method, body: body)
    }
}

private struct Envelope<T: Decodable>: Decodable {
    struct Failure: Decodable {
        let code: String
        let message: String
    }

    let data: T?
    let error: Failure?
}
