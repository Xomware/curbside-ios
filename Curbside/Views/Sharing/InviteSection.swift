import SwiftUI

/// The owner's invite: the explainer and a button that makes a link, then the link to share.
struct InviteSection: View {
    let model: SharingModel

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
                ShareLink(item: invite.link.url, subject: Text("Curbside"), message: Text("Join \(model.place.name) on Curbside")) {
                    Text("SHARE INVITE LINK")
                        .font(CurbsideFont.button)
                        .foregroundStyle(Palette.signWhite)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .signFace(Palette.signGreen, rule: Palette.signWhite)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityLabel("Share invite link")
                Text("Works once, until \(SharingModel.expiry(invite)).")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
            } else {
                Text("Share \(model.place.name) with someone you live with. They'll see and edit every household, person, pet and note on it.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                SignButton(title: "Invite someone") { Task { await model.makeInvite() } }
            }
        }
    }
}
