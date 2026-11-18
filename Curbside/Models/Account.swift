struct Account: Decodable, Equatable, Sendable {
    let accountID: String
    let displayName: String
    /// Absent from `POST /me`'s answer; `GET /me` always has it.
    var identities: [Identity]?

    enum CodingKeys: String, CodingKey {
        case identities
        case accountID = "account_id"
        case displayName = "display_name"
    }
}

/// One sign-in linked to the account. `provider` is the backend's "apple" or "google".
struct Identity: Decodable, Equatable, Identifiable, Sendable {
    let sub: String
    let provider: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case sub, provider
        case createdAt = "created_at"
    }

    var id: String { sub }

    var kind: IdentityProvider? {
        switch provider {
        case "apple": .apple
        case "google": .google
        default: nil
        }
    }

    var name: String { kind == .apple ? "Apple" : "Google" }
}
