import SwiftUI

/// The explainer and a button that makes a friend link, then the link to share.
struct FriendLinkSection: View {
    let model: FriendsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let invite = model.invite {
                Text(invite.link.url.absoluteString)
                    .font(CurbsideFont.mono)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
                ShareLink(item: invite.link.url, subject: Text("Curbside"), message: Text("Be my friend on Curbside")) {
                    Text("SHARE FRIEND LINK")
                        .font(CurbsideFont.button)
                        .foregroundStyle(Palette.signWhite)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .signFace(Palette.signGreen, rule: Palette.signWhite)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityLabel("Share friend link")
                Text("Works once, until \(invite.expiresAt.isoDate?.formatted(.dateTime.month(.abbreviated).day()) ?? "next week").")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                Text("A friend can be added to any of your streets straight from its sharing screen, no invite needed. Friends don't see your streets until you add them.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                SignButton(title: "Make a friend link") { Task { await model.makeInvite() } }
            }
        }
    }
}
