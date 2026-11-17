import SwiftUI

/// A house-number plaque fused to a street-name blade carrying the household name.
/// A `nil` name is a house nobody has added yet: a dashed, unpainted blade that reads "+ ADD".
/// A `nil` number (no street address yet) drops the white number tab.
struct HousePlaque: View {
    enum Size {
        case regular
        /// Map pin: smaller type, so neighbouring houses' plaques overlap less.
        case pin
        /// Map pin zoomed out: the number tab alone, or the name's initial when there is no number.
        case tab
    }

    let number: String?
    let name: String?
    var size = Size.regular

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if size == .tab {
                Text(number ?? String(name?.prefix(1) ?? "+"))
                    .font(CurbsideFont.pinNumber)
                    .foregroundStyle(Palette.signInk)
                    .padding(.horizontal, Spacing.xs)
                    .background(Palette.signWhite, in: .rect(cornerRadius: 3))
            } else {
                plaque
            }
        }
        .padding(Spacing.xxs)
        .background { blade.shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var plaque: some View {
        if let number {
            Text(number)
                .font(size == .pin ? CurbsideFont.pinNumber : CurbsideFont.number)
                .foregroundStyle(Palette.signInk)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Palette.signWhite, in: .rect(cornerRadius: 3))
        }
        Text(name?.uppercased() ?? "+ ADD")
            .font(size == .pin ? CurbsideFont.pinName : CurbsideFont.button)
            .foregroundStyle(name == nil ? Palette.inkSecondary : Palette.signWhite)
            .lineLimit(1)
            .padding(.leading, number == nil ? Spacing.xs : 0)
            .padding(.trailing, Spacing.xs)
    }

    private var accessibilityText: String {
        let who = name.map { "\($0) household" } ?? "nobody added yet"
        return number.map { "\($0), \(who)" } ?? who
    }

    @ViewBuilder private var blade: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        if name == nil {
            shape.fill(Palette.surface)
                .overlay { shape.strokeBorder(Palette.inkSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])) }
        } else {
            shape.fill(Palette.signGreen)
                .overlay { shape.strokeBorder(Palette.signWhite, lineWidth: 1.5) }
        }
    }
}

#Preview("Light") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HousePlaque(number: "11", name: "Pumpernickel")
        HousePlaque(number: "15", name: nil)
    }
    .padding()
    .background(Palette.background)
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HousePlaque(number: "11", name: "Pumpernickel")
        HousePlaque(number: "15", name: nil)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
