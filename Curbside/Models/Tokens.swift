import Foundation

struct Tokens: Codable, Equatable, Sendable {
    var access: String
    var id: String
    var refresh: String

    /// The ID token's claims. Read, never trusted: the server verifies every token it acts on.
    var claims: [String: Any] {
        let parts = id.split(separator: ".")
        guard parts.count == 3 else { return [:] }
        var payload = String(parts[1]).replacing("-", with: "+").replacing("_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    var sub: String? { claims["sub"] as? String }

    /// Cognito names federated users `<IdP>_<id>`, e.g. `SignInWithApple_001234`.
    var provider: IdentityProvider? {
        let prefix = (claims["cognito:username"] as? String)?.split(separator: "_").first.map(String.init)
        return IdentityProvider.allCases.first { $0.rawValue.lowercased() == prefix?.lowercased() }
    }
}
