import Foundation

enum IdentityProvider: String, Sendable, CaseIterable {
    case apple = "SignInWithApple"
    case google = "Google"
}

enum AuthError: Error, Equatable {
    case stateMismatch
    case denied(String)
    case missingCode
    /// The token endpoint's OAuth `error`, e.g. `invalid_grant` for a revoked or expired refresh token.
    case rejected(String)
    case malformed
    case signedOut
}

/// The hosted-UI OAuth endpoints of the Cognito app client.
struct Cognito: Sendable {
    static let callbackScheme = "curbside"
    static let redirectURI = "curbside://auth/callback"

    let domain: URL
    let clientID: String

    func authorizeURL(_ provider: IdentityProvider, pkce: PKCE, state: String) -> URL {
        domain.appending(path: "oauth2/authorize").appending(queryItems: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "identity_provider", value: provider.rawValue),
            URLQueryItem(name: "scope", value: "openid"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ])
    }

    /// The authorization code from the callback. State is checked first so a forged callback never gets further.
    func code(from callback: URL, state: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        guard value("state") == state else { throw AuthError.stateMismatch }
        if let error = value("error") { throw AuthError.denied(value("error_description") ?? error) }
        guard let code = value("code") else { throw AuthError.missingCode }
        return code
    }

    func tokenRequest(_ form: [String: String]) -> URLRequest {
        var request = URLRequest(url: domain.appending(path: "oauth2/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs = form.merging(["client_id": clientID]) { a, _ in a }
            .sorted { $0.key < $1.key }
            .map { "\(formEncode($0.key))=\(formEncode($0.value))" }
        request.httpBody = Data(pairs.joined(separator: "&").utf8)
        return request
    }

    /// `keepingRefresh` fills in the refresh token, which Cognito leaves out of refresh-grant responses.
    func exchange(_ form: [String: String], session: URLSession, keepingRefresh: String? = nil) async throws -> Tokens {
        let (data, response) = try await session.data(for: tokenRequest(form))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // An outage is not a rejection: URLError makes APIClient keep the session instead of signing out.
        if status >= 500 { throw URLError(.badServerResponse) }
        guard status == 200 else {
            throw (try? decoder.decode(TokenFailure.self, from: data)).map { AuthError.rejected($0.error) } ?? AuthError.malformed
        }
        guard let body = try? decoder.decode(TokenResponse.self, from: data),
              let refresh = body.refreshToken ?? keepingRefresh else { throw AuthError.malformed }
        return Tokens(access: body.accessToken, id: body.idToken, refresh: refresh)
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
}

private struct TokenFailure: Decodable {
    let error: String
}

private func formEncode(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}
