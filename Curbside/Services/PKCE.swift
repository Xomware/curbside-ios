import CryptoKit
import Foundation

/// RFC 7636 S256 pair. Cognito doesn't require PKCE, so every authorize request must carry it.
struct PKCE: Sendable {
    let verifier: String

    var challenge: String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func random() -> PKCE {
        PKCE(verifier: randomToken())
    }
}

/// 32 bytes from the system CSPRNG as base64url: 43 characters, the shortest verifier RFC 7636 allows.
func randomToken() -> String {
    base64URL(Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }))
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
