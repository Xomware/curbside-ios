import SwiftUI

/// Three cards on how the map works, shown once. Same cards as the web's tour.
struct TourView: View {
    let done: () -> Void

    @State private var at = 0

    private struct Card {
        let title: String
        let body: String
        let art: Art
    }

    private enum Art {
        case plaque(number: String?, name: String?)
        case sign
    }

    private static let cards = [
        Card(
            title: "Tap a house",
            body: "Its sign opens the card: who lives there, their kids and pets, and what you last talked about.",
            art: .plaque(number: "11", name: "Pumpernickel")
        ),
        Card(
            title: "Tap anywhere to add a neighbor",
            body: "Tap any spot on the map, put a name on the sign, then add the people and pets you meet.",
            art: .plaque(number: nil, name: nil)
        ),
        Card(
            title: "Share the street",
            body: "More, then Sharing, makes an invite link. Neighbors who join see and edit the same map, and nobody else can.",
            art: .sign
        ),
    ]

    private var card: Card { Self.cards[at] }
    private var isLast: Bool { at == Self.cards.count - 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                art
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .background(Palette.background, in: .rect(cornerRadius: 8))
                    .accessibilityHidden(true)
                Text("\(at + 1) OF \(Self.cards.count)")
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityLabel("Tip \(at + 1) of \(Self.cards.count)")
                Text(card.title)
                    .font(CurbsideFont.signHeadline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(card.body)
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .background(Palette.surface, in: .rect(cornerRadius: 12))
            .padding(Spacing.md)
            HStack(spacing: Spacing.sm) {
                if at > 0 {
                    PanelButton(title: "Back", systemImage: "chevron.left") { at -= 1 }
                }
                SignButton(title: isLast ? "Open my street" : "Next") {
                    if isLast { done() } else { at += 1 }
                }
            }
            .padding(.horizontal, Spacing.md)
            if !isLast {
                SkipButton(title: "Skip the tour", action: done)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.selection, trigger: at)
    }

    @ViewBuilder private var art: some View {
        switch card.art {
        case .plaque(let number, let name):
            HousePlaque(number: number, name: name)
        case .sign:
            StreetSign(name: "Quillfeather Ln")
        }
    }
}
