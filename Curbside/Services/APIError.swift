enum APIError: Error, Equatable {
    case needsOnboarding
    case unauthorized
    /// `code` tells a version conflict from `identity_in_use`, `already_linked` or `last_identity`.
    case conflict(code: String?)
    case rateLimited
    case server(status: Int, code: String?)
    case malformed
}
