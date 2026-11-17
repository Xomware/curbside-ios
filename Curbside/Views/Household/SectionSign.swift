import SwiftUI

/// The road-sign pictogram fronting each card section: white panel for adults, school-zone pentagon for kids,
/// warning diamond for pets, blue information sign for notes.
struct SectionSign: View {
    enum Kind {
        case adults, kids, pets, notes
    }

    let kind: Kind

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.bold))
            .foregroundStyle(kind == .notes ? Palette.signWhite : Palette.signInk)
            .frame(width: size, height: size)
            .background { plate }
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch kind {
        case .adults: "figure.stand"
        case .kids: "figure.and.child.holdinghands"
        case .pets: "pawprint.fill"
        case .notes: "text.alignleft"
        }
    }

    @ViewBuilder private var plate: some View {
        switch kind {
        case .adults: sign(RoundedRectangle(cornerRadius: 5), Palette.signWhite)
        case .kids: sign(Pentagon(), Palette.school)
        case .pets: sign(Diamond(), Palette.warning)
        case .notes: sign(RoundedRectangle(cornerRadius: 5), Palette.infoBlue)
        }
    }

    private func sign(_ shape: some Shape, _ fill: Color) -> some View {
        shape.fill(fill).overlay { shape.stroke(Palette.signInk, style: StrokeStyle(lineWidth: 2, lineJoin: .round)) }
    }
}
