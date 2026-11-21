import SwiftUI

/// Your friends, the streets you share with each, and a link to make a new one.
struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: FriendsModel
    @State private var removing: Friend?

    init(model: FriendsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    friends
                    if let message = model.message {
                        Text(message)
                            .font(CurbsideFont.detail)
                            .foregroundStyle(Palette.ink)
                    }
                    FriendLinkSection(model: model)
                        .padding(.top, Spacing.sm)
                }
                .padding(Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.background)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Palette.ink)
        .disabled(model.isBusy)
        .task { await model.load() }
        .confirmationDialog("Remove \(removing?.displayName ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible, presenting: removing) { friend in
            Button("Remove friend", role: .destructive) { Task { await model.remove(friend) } }
        } message: { _ in
            Text("Streets you share stay shared.")
        }
    }

    @ViewBuilder private var friends: some View {
        Text("YOUR FRIENDS")
            .font(CurbsideFont.label)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityAddTraits(.isHeader)
        if let friends = model.friends, !friends.isEmpty {
            VStack(spacing: 0) {
                ForEach(friends) { friend in
                    FriendRow(friend: friend) { removing = friend }
                    if friend.id != friends.last?.id { Divider() }
                }
            }
            .background(Palette.surface, in: .rect(cornerRadius: 8))
        } else if model.friends != nil {
            Text("No friends yet. Anyone who joins a street with your invite becomes one, or send a friend link.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else if model.message == nil {
            ProgressView()
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel("Loading your friends")
        } else {
            Button("Try again") { Task { await model.load() } }
                .font(CurbsideFont.button)
                .frame(minHeight: 44)
        }
    }
}

private struct FriendRow: View {
    let friend: Friend
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(friend.displayName)
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                Text(friend.detail)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Button("Remove", role: .destructive, action: remove)
                .font(CurbsideFont.detail)
                .foregroundStyle(Palette.stop)
                .frame(minHeight: 44)
                .buttonStyle(SignPressStyle())
                .accessibilityLabel("Remove \(friend.displayName)")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
    }
}
