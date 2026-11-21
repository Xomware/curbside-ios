import SwiftUI

/// What's happened on your streets and with your friends, newest first. Opening it marks everything seen.
struct ActivityView: View {
    let model: ActivityModel
    /// A row with a street opens it.
    let open: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content
                }
                .padding(Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.background)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(Palette.ink)
        .task { await model.open() }
    }

    @ViewBuilder private var content: some View {
        if let items = model.items, !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ActivityRow(item: item, isNew: index < model.fresh, open: item.opens.map { id in { open(id) } })
                    if item.id != items.last?.id { Divider() }
                }
            }
            .background(Palette.surface, in: .rect(cornerRadius: 8))
        } else if model.items != nil {
            StreetSign(name: "All quiet")
            Text("When someone joins a street you share, adds a household, or becomes your friend, it shows up here.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else if model.failed {
            Text("Couldn't load your activity.")
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
            SignButton(title: "Try again") { Task { await model.open() } }
        } else {
            ProgressView()
                .controlSize(.large)
                .tint(Palette.signGreen)
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("Loading activity")
        }
    }
}

private struct ActivityRow: View {
    let item: ActivityItem
    let isNew: Bool
    let open: (() -> Void)?

    var body: some View {
        if let open {
            Button(action: open) { label }
                .buttonStyle(SignPressStyle())
                .accessibilityHint("Opens the street")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(item.text)
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                if let date = item.createdAt.isoDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.sm)
            if isNew {
                YardSign(text: "NEW", kind: .panel)
                    .accessibilityLabel("New")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 56)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
