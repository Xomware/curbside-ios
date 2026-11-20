import Foundation

/// Someone on a street. `GET /maps/{id}/members` lists the owner first.
struct Member: Decodable, Equatable, Identifiable, Sendable {
    let accountID: String
    let displayName: String
    let role: Place.Role

    enum CodingKeys: String, CodingKey {
        case role
        case accountID = "account_id"
        case displayName = "display_name"
    }

    var id: String { accountID }
}

/// A single-use invite, live for 7 days.
struct Invite: Decodable, Equatable, Sendable {
    let code: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
    }

    var link: InviteLink { InviteLink(code: code) }
}

/// What an invite would join, for the accept sheet.
struct InvitePreview: Decodable, Equatable, Sendable {
    struct Street: Decodable, Equatable, Sendable {
        let id: String
        let name: String
    }

    let code: String
    let map: Street
    let invitedBy: String
    let alreadyMember: Bool

    enum CodingKeys: String, CodingKey {
        case code, map
        case invitedBy = "invited_by"
        case alreadyMember = "already_member"
    }
}

/// `https://curbside.xomware.com/invite/{code}`: the web app's route, and the path the AASA file hands to this app.
struct InviteLink: Equatable, Identifiable, Sendable {
    static let host = "curbside.xomware.com"

    let code: String

    var id: String { code }

    var url: URL { Self.base.appending(path: code) }

    // A literal URL: a typo fails the first time any invite is shared, so the force unwrap can't ship.
    private static let base = URL(string: "https://\(host)/invite")!

    init(code: String) {
        self.code = code
    }

    init?(_ url: URL) {
        let parts = url.pathComponents
        guard url.host() == Self.host, parts.count == 3, parts[1] == "invite", !parts[2].isEmpty else { return nil }
        code = parts[2]
    }
}
