import Foundation

/// A mutual connection between accounts, across streets. `GET /friends` sorts by name.
struct Friend: Decodable, Equatable, Identifiable, Sendable {
    struct Street: Decodable, Equatable, Sendable {
        let mapID: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case name
            case mapID = "map_id"
        }
    }

    let accountID: String
    let displayName: String
    let since: String
    let sharedMaps: [Street]

    enum CodingKeys: String, CodingKey {
        case since
        case accountID = "account_id"
        case displayName = "display_name"
        case sharedMaps = "shared_maps"
    }

    var id: String { accountID }

    /// "On Quillfeather Ln and Bramblewick Ct", or "Friends since Nov 2026" with no street in common.
    var detail: String {
        if !sharedMaps.isEmpty { return "On " + sharedMaps.map(\.name).formatted(.list(type: .and)) }
        return "Friends since " + (since.isoDate?.formatted(.dateTime.month(.abbreviated).year()) ?? "recently")
    }
}

/// A single-use friend link, live for 7 days.
struct FriendInvite: Decodable, Equatable, Sendable {
    let code: String
    let expiresAt: String

    enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
    }

    var link: FriendLink { FriendLink(code: code) }
}

/// Who made an opened friend link, for the accept sheet.
struct FriendInvitePreview: Decodable, Equatable, Sendable {
    struct Inviter: Decodable, Equatable, Sendable {
        let displayName: String

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    let inviter: Inviter
}

/// `https://curbside.xomware.com/friend/{code}`: the web app's route, and a path the AASA file hands to this app.
struct FriendLink: Equatable, Identifiable, Sendable {
    let code: String

    var id: String { code }

    var url: URL { Self.base.appending(path: code) }

    // A literal URL: a typo fails the first time any friend link is shared, so the force unwrap can't ship.
    private static let base = URL(string: "https://\(InviteLink.host)/friend")!

    init(code: String) {
        self.code = code
    }

    init?(_ url: URL) {
        let parts = url.pathComponents
        guard url.host() == InviteLink.host, parts.count == 3, parts[1] == "friend", !parts[2].isEmpty else { return nil }
        code = parts[2]
    }
}
