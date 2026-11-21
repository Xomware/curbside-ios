import SwiftUI

/// Put a friend straight on the street, no invite link.
struct AddFriendSection: View {
    let model: SharingModel

    var body: some View {
        if let friends = model.friends {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if model.addable.isEmpty {
                    Text(friends.isEmpty ? "Friends can be added here without a link. Make some from Friends in the map's menu." : "All your friends are on this street.")
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.inkSecondary)
                } else {
                    Menu {
                        ForEach(model.addable) { friend in
                            Button(friend.displayName) { Task { await model.add(friend) } }
                        }
                    } label: {
                        Text("ADD A FRIEND")
                            .font(CurbsideFont.button)
                            .foregroundStyle(Palette.signWhite)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .signFace(Palette.signGreen, rule: Palette.signWhite)
                    }
                    .buttonStyle(SignPressStyle())
                    .accessibilityLabel("Add a friend")
                    Text("They'll see and edit everything on \(model.place.name) straight away.")
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }
}
