import SwiftUI

/// Household status planted in the yard as a road sign.
struct YardSign: View {
    enum Kind {
        /// White regulatory panel, for settled facts ("MET").
        case panel
        /// Yellow warning diamond, for something new ("NEW").
        case warning
        /// Orange work-zone diamond, for something in progress ("MOWER OUT").
        case workZone
        /// Yellow no-passing pennant, for an event ("PARTY SAT").
        case pennant
    }

    let text: String
    let kind: Kind

    @ScaledMetric(relativeTo: .caption) private var diamond: CGFloat = 76
    @ScaledMetric(relativeTo: .caption) private var pennantHeight: CGFloat = 48

    var body: some View {
        label
            .font(CurbsideFont.label)
            .foregroundStyle(Palette.signInk)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .accessibilityLabel("Sign: \(text)")
    }

    @ViewBuilder private var label: some View {
        switch kind {
        case .panel:
            Text(text)
                .fixedSize()
                .padding(.horizontal, Spacing.sm + Spacing.xs)
                .padding(.vertical, Spacing.sm)
                .signFace(Palette.signWhite, rule: Palette.signInk, cornerRadius: 5)
        case .warning, .workZone:
            Text(text)
                .multilineTextAlignment(.center)
                .frame(width: diamond * 0.55, height: diamond * 0.55)
                .frame(width: diamond, height: diamond)
                .background { sign(Diamond(), fill: kind == .warning ? Palette.warning : Palette.workZone) }
        case .pennant:
            Text(text)
                .frame(width: pennantHeight, alignment: .leading)
                .padding(.leading, Spacing.sm)
                .frame(width: pennantHeight * 2.2, height: pennantHeight, alignment: .leading)
                .background { sign(Pennant(), fill: Palette.warning) }
        }
    }

    private func sign(_ shape: some Shape, fill: Color) -> some View {
        shape.fill(fill)
            .overlay { shape.stroke(Palette.signInk, style: StrokeStyle(lineWidth: 2, lineJoin: .round)) }
            .shadow(color: .black.opacity(0.28), radius: 0, x: 1.5, y: 2)
    }
}

#Preview("Light") {
    HStack(spacing: Spacing.md) {
        YardSign(text: "MET", kind: .panel)
        YardSign(text: "NEW", kind: .warning)
        YardSign(text: "MOWER OUT", kind: .workZone)
        YardSign(text: "PARTY SAT", kind: .pennant)
    }
    .padding()
    .background(Palette.background)
}

#Preview("Dark") {
    HStack(spacing: Spacing.md) {
        YardSign(text: "MET", kind: .panel)
        YardSign(text: "NEW", kind: .warning)
        YardSign(text: "MOWER OUT", kind: .workZone)
        YardSign(text: "PARTY SAT", kind: .pennant)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
