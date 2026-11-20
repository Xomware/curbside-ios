import SwiftUI

/// An opened invite link. Joining takes the tap; `open` gets the street's id to show.
struct InviteSheet: View {
    let open: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: InviteModel

    init(model: InviteModel, open: @escaping (String) -> Void) {
        _model = State(initialValue: model)
        self.open = open
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
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("Opening your invite")
        case .ready(let invite):
            ready(invite)
        case .gone:
            StreetSign(name: "Invite used up")
            paragraph("This link was already used or has expired. Ask for a new one.")
            notNow("Close")
        case .failed:
            paragraph("Couldn't open this invite.")
            SignButton(title: "Try again") { Task { await model.load() } }
            notNow("Not now")
        }
    }

    @ViewBuilder private func ready(_ invite: InvitePreview) -> some View {
        Text("\(invite.invitedBy) invited you to")
            .font(CurbsideFont.body)
            .foregroundStyle(Palette.inkSecondary)
        StreetSign(name: invite.map.name)
        if invite.alreadyMember {
            paragraph("You're already on this street.")
            SignButton(title: "Open it") { open(invite.map.id) }
        } else {
            paragraph("You'll both see and edit every household, person, pet and note on it. Only people on the street can see it.")
            if model.joinFailed {
                Text("Couldn't join. Try again.")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.ink)
            }
            SignButton(title: model.isJoining ? "Joining…" : "Join \(invite.map.name)") {
                Task {
                    if let id = await model.join() { open(id) }
                }
            }
            .disabled(model.isJoining)
            notNow("Not now")
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(CurbsideFont.body)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func notNow(_ title: String) -> some View {
        Button(title) { dismiss() }
            .font(CurbsideFont.button)
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(SignPressStyle())
    }
}
