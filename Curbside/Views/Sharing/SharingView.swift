import SwiftUI

/// Who's on the open street. The owner invites and removes; a member can leave.
struct SharingView: View {
    /// Called once this account is off the street.
    let left: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: SharingModel
    @State private var removing: Member?
    @State private var leaving = false

    init(model: SharingModel, left: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.left = left
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StreetSign(name: model.place.name)
                    members
                    if let message = model.message {
                        Text(message)
                            .font(CurbsideFont.detail)
                            .foregroundStyle(Palette.ink)
                    }
                    if model.isOwner {
                        InviteSection(model: model)
                            .padding(.top, Spacing.sm)
                    } else {
                        leave
                    }
                }
                .padding(Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.background)
            .navigationTitle("Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Palette.ink)
        .disabled(model.isBusy)
        .task { await model.load() }
        .confirmationDialog("Remove \(removing?.displayName ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible, presenting: removing) { member in
            Button("Remove", role: .destructive) { Task { await model.remove(member) } }
        } message: { _ in
            Text("They'll lose access to \(model.place.name) until you invite them again.")
        }
        .confirmationDialog("Leave \(model.place.name)?", isPresented: $leaving, titleVisibility: .visible) {
            Button("Leave street", role: .destructive) {
                Task { if await model.leave() { left() } }
            }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("You'll lose access until the owner invites you again.")
        }
    }

    @ViewBuilder private var members: some View {
        Text("ON THIS STREET")
            .font(CurbsideFont.label)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityAddTraits(.isHeader)
        if let members = model.members {
            VStack(spacing: 0) {
                ForEach(members) { member in
                    MemberRow(member: member, isYou: member.accountID == model.accountID, canRemove: model.isOwner) {
                        removing = member
                    }
                    if member.id != members.last?.id { Divider() }
                }
            }
            .background(Palette.surface, in: .rect(cornerRadius: 8))
            if model.isOwner, model.isAlone {
                Text("Just you so far.")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
            }
        } else if model.message == nil {
            ProgressView()
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityLabel("Loading who's on this street")
        } else {
            Button("Try again") { Task { await model.load() } }
                .font(CurbsideFont.button)
                .frame(minHeight: 44)
        }
    }

    private var leave: some View {
        Button("Leave this street", role: .destructive) { leaving = true }
            .font(CurbsideFont.button)
            .foregroundStyle(Palette.stop)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(SignPressStyle())
            .padding(.top, Spacing.sm)
    }
}

private struct MemberRow: View {
    let member: Member
    let isYou: Bool
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(member.displayName)
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                if isYou {
                    Text("You")
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.sm)
            if member.role == .owner {
                YardSign(text: "OWNER", kind: .panel)
                    .accessibilityLabel("Owner")
            } else if canRemove {
                Button("Remove", role: .destructive, action: remove)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.stop)
                    .frame(minHeight: 44)
                    .buttonStyle(SignPressStyle())
                    .accessibilityLabel("Remove \(member.displayName)")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
    }
}
