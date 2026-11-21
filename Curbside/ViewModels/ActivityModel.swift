import Observation

/// The activity feed and its unread count. Home keeps one for the header badge; opening the feed marks it seen.
@MainActor @Observable
final class ActivityModel {
    /// Nil while loading, and after a failed load (with `failed` set).
    private(set) var items: [ActivityItem]?
    /// The header badge.
    private(set) var unread = 0
    /// How many rows to mark new while the feed is open, frozen before the seen marker clears `unread`.
    private(set) var fresh = 0
    private(set) var failed = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    /// Refreshes the badge. A failure keeps the old count; the next refresh catches up.
    func refresh() async {
        guard let feed: ActivityFeed = try? await api.request("/v1/activity") else { return }
        items = feed.items
        unread = feed.unread
    }

    /// The feed opened: load it, then mark everything seen.
    func open() async {
        failed = false
        do {
            let feed: ActivityFeed = try await api.request("/v1/activity")
            items = feed.items
            fresh = feed.unread
            unread = feed.unread
        } catch {
            failed = true
            return
        }
        guard unread > 0 else { return }
        // Unmarked, the badge just comes back on the next refresh.
        try? await api.send("/v1/activity/seen", method: "POST")
        unread = 0
    }
}
