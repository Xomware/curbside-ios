import SwiftUI

/// Signed-in home: the open street's map, or place setup when the account has none yet. Household cards push by id.
struct HomeView: View {
    /// One slot, so an invite or friend link arriving over settings or sharing replaces it instead of being dropped.
    enum Sheet: Identifiable {
        case settings
        case activity
        case sharing(Place)
        case invite(InviteLink)
        case friends
        case friendInvite(FriendLink)

        var id: String {
            switch self {
            case .settings: "settings"
            case .activity: "activity"
            case .sharing(let place): "sharing-\(place.id)"
            case .invite(let link): "invite-\(link.code)"
            case .friends: "friends"
            case .friendInvite(let link): "friend-\(link.code)"
            }
        }
    }

    let root: RootModel

    @State private var model: MapHomeModel
    @State private var activity: ActivityModel
    @State private var path: [String] = []
    @State private var sheet: Sheet?
    @Environment(\.scenePhase) private var phase

    init(root: RootModel) {
        self.root = root
        _model = State(initialValue: MapHomeModel(api: root.api, defaults: root.defaults))
        _activity = State(initialValue: ActivityModel(api: root.api))
    }

    var body: some View {
        content
            .task { await model.load() }
            .task { await activity.refresh() }
            .task { await root.notifications.refresh() }
            .onChange(of: phase) { _, phase in
                if phase == .active { Task { await activity.refresh() } }
            }
            .onChange(of: root.pendingFriend, initial: true) { _, link in
                guard let link else { return }
                root.pendingFriend = nil
                sheet = .friendInvite(link)
            }
            .onChange(of: root.pendingActivity, initial: true) { _, pending in
                guard pending else { return }
                root.pendingActivity = false
                sheet = .activity
            }
            .onChange(of: model.households) { _, households in
                guard let place = model.place else { return }
                Task { await root.notifications.updateReminder(due: Notifications.due(households), street: place.name) }
            }
            .onChange(of: root.pendingInvite, initial: true) { _, link in
                guard let link else { return }
                root.pendingInvite = nil
                sheet = .invite(link)
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView(root: root, street: model.place.map { ($0.name, Notifications.due(model.households)) })
                case .activity:
                    ActivityView(model: activity) { id in
                        self.sheet = nil
                        open(id)
                    }
                case .sharing(let place):
                    if case .home(let account) = root.route {
                        SharingView(model: SharingModel(place: place, accountID: account.accountID, api: root.api)) {
                            self.sheet = nil
                            open(nil)
                        } invited: {
                            Task { await root.notifications.ask() }
                        }
                    }
                case .invite(let link):
                    InviteSheet(model: InviteModel(link: link, api: root.api)) { id in
                        self.sheet = nil
                        open(id)
                        Task { await root.notifications.ask() }
                    }
                    .presentationDetents([.medium, .large])
                case .friends:
                    FriendsView(model: FriendsModel(api: root.api))
                case .friendInvite(let link):
                    FriendInviteSheet(model: FriendInviteModel(link: link, api: root.api)) {
                        Task { await root.notifications.ask() }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
    }

    private func open(_ id: String?) {
        path = []
        Task { await model.open(id) }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .accessibilityLabel("Loading your map")
        case .failed:
            VStack(spacing: Spacing.md) {
                Text("Couldn't load your map.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                SignButton(title: "Try again") { Task { await model.load() } }
            }
            .padding(Spacing.md)
        case .noPlace:
            PlaceSetupView(api: model.api, created: model.show)
        case .ready:
            if let place = model.place {
                NavigationStack(path: $path) {
                    PlaceMap(model: model, place: place, header: header(place)) { path.append($0.id) }
                        .navigationTitle("Block")
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: String.self) { id in
                            if let card = model.card(for: id) {
                                HouseholdView(model: card)
                            }
                        }
                }
                .tint(Palette.ink)
            }
        }
    }

    private func header(_ place: Place) -> MapHeader {
        MapHeader(
            place: place,
            places: model.places,
            count: model.households.count,
            unread: activity.unread,
            open: { open($0) },
            activity: { sheet = .activity },
            sharing: { sheet = .sharing(place) },
            friends: { sheet = .friends },
            settings: { sheet = .settings }
        )
    }
}
