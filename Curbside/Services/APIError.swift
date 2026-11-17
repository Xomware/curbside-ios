enum APIError: Error, Equatable {
    case needsOnboarding
    case unauthorized
    case conflict(message: String?)
    case rateLimited
    case server(status: Int, code: String?)
    case malformed
}
