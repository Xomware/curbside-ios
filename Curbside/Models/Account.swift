struct Account: Decodable, Equatable, Sendable {
    let accountID: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case displayName = "display_name"
    }
}
