import SwiftUI

/// An opened friend link. Becoming friends takes the tap.
struct FriendInviteSheet: View {
    /// Called once you're friends: the moment to ask about notifications.
    let befriended: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: FriendInviteModel

    init(model: FriendInviteModel, befriended: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.befriended = befriended
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                content
            }
            .padding(Spacing.md)
            .padding(.top, Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.background)
        .task { await model.load() }
        .onChange(of: model.state) { _, state in
            if case .accepted = state { befriended() }
        }
        .sensoryFeedback(.success, trigger: model.state) { _, state in
            if case .accepted = state { true } else { false }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("Opening your friend link")
        case .ready(let invite):
            StreetSign(name: invite.inviter.displayName)
            paragraph("\(invite.inviter.displayName) wants to be friends on Curbside. Friends can add each other to their streets without an invite link.")
            if model.acceptFailed {
                Text("Couldn't accept. Try again.")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.ink)
            }
            SignButton(title: model.isAccepting ? "Accepting…" : "Be friends") { Task { await model.accept() } }
                .disabled(model.isAccepting)
            close("Not now")
        case .accepted(let friend):
            StreetSign(name: "Friends")
            paragraph("You and \(friend.displayName) are friends. Add them to a street from its sharing screen.")
            close("Done")
        case .gone:
            StreetSign(name: "Link used up")
            paragraph("This friend link was already used or has expired. Ask for a new one.")
            close("Close")
        case .own:
            StreetSign(name: "Your own link")
            paragraph("This is the friend link you made. Send it to someone else.")
            close("Close")
        case .failed:
            paragraph("Couldn't open this friend link.")
            SignButton(title: "Try again") { Task { await model.load() } }
            close("Not now")
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(CurbsideFont.body)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func close(_ title: String) -> some View {
        Button(title) { dismiss() }
            .font(CurbsideFont.button)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(SignPressStyle())
    }
}
