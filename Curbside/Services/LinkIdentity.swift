extension APIClient {
    /// `POST /me/identities`: adds the sign-in behind `idToken` to this client's account. The server takes only an ID
    /// token whose `auth_time` is under 10 minutes old, so call it straight after that sign-in.
    func link(idToken: String) async throws -> Identity {
        try await request("/v1/me/identities", method: "POST", body: LinkBody(idToken: idToken))
    }
}

private struct LinkBody: Encodable, Sendable {
    let idToken: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
    }
}
