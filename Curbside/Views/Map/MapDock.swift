import SwiftUI

/// Bottom of the map: the empty-street sign, the OSM credit, and the "Near me" sign.
struct MapDock: View {
    let isEmpty: Bool
    let showsCredit: Bool
    let nearMe: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                if isEmpty {
                    YardSign(text: "NOBODY ADDED YET", kind: .panel)
                }
                Spacer()
                if showsCredit {
                    // ODbL: the outlines are OSM data, so the credit sits on the map wherever they are drawn.
                    Text("© OpenStreetMap contributors")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.horizontal, Spacing.xs)
                        .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 3))
                }
            }
            .padding(Spacing.sm)
            Button(action: nearMe) {
                Label("Near me", systemImage: "location.north.line.fill")
                    .font(CurbsideFont.button)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.signWhite)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .signFace(Palette.infoBlue, rule: Palette.signWhite)
            }
            .buttonStyle(SignPressStyle())
            .padding([.horizontal, .bottom], Spacing.md)
        }
    }
}
