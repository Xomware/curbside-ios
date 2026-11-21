/// `GET /activity`: newest first, at most 50. The first `unread` items arrived since the feed was last opened.
struct ActivityFeed: Decodable, Equatable, Sendable {
    let items: [ActivityItem]
    let unread: Int
}

/// Something that happened on a street you share, or between you and a friend. Never something you did.
struct ActivityItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    /// Kept as the raw string so a kind added on the server later still decodes.
    let kind: String
    let actorName: String
    let mapID: String?
    let mapName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, kind
        case actorName = "actor_name"
        case mapID = "map_id"
        case mapName = "map_name"
        case createdAt = "created_at"
    }

    var text: String {
        let street = mapName ?? "a street"
        return switch kind {
        case "member_joined": "\(actorName) joined \(street)"
        case "added_to_street": "\(actorName) added you to \(street)"
        case "removed_from_street": "\(actorName) took you off \(street)"
        case "street_handed_to_you": "\(street) is yours now"
        case "household_added": "\(actorName) added a household to \(street)"
        case "friend_added": "You and \(actorName) are friends"
        default: "\(actorName) changed something on \(street)"
        }
    }

    /// The street to open on tap. Not one you were just taken off.
    var opens: String? {
        kind == "removed_from_street" ? nil : mapID
    }
}
