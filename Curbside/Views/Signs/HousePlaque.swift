import SwiftUI

/// A house-number plaque fused to a street-name blade carrying the household name.
/// A `nil` name is a house nobody has added yet: a dashed, unpainted blade that reads "+ ADD".
struct HousePlaque: View {
    let number: String
    let name: String?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(number)
                .font(CurbsideFont.number)
                .foregroundStyle(Palette.signInk)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Palette.signWhite, in: .rect(cornerRadius: 3))
            Text(name?.uppercased() ?? "+ ADD")
                .font(CurbsideFont.button)
                .foregroundStyle(name == nil ? Palette.inkSecondary : Palette.signWhite)
                .lineLimit(1)
                .padding(.trailing, Spacing.xs)
        }
        .padding(Spacing.xxs)
        .background { blade.shadow(color: .black.opacity(0.3), radius: 0, x: 1, y: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name.map { "\(number), \($0) household" } ?? "\(number), nobody added yet")
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
