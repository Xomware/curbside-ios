import SwiftUI

/// Bottom of the map: how to add a house, recenter, the OSM credit, and the add, "Near me" and TALK signs.
struct MapDock: View {
    let isEmpty: Bool
    let showsCredit: Bool
    let add: () -> Void
    let recenter: () -> Void
    let nearMe: () -> Void
    let talk: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(alignment: .bottom, spacing: Spacing.sm) {
                if isEmpty {
                    Text("Tap a house on the map to add who lives there.")
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, Spacing.sm + Spacing.xs)
                        .padding(.vertical, Spacing.sm)
                        .background(Palette.surface, in: .rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
                }
                Spacer(minLength: 0)
                Button(action: recenter) {
                    Image(systemName: "scope")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 48, height: 48)
                        .background(Palette.surface, in: .rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityLabel("Recenter the map")
            }
            HStack(spacing: Spacing.sm) {
                PanelButton(title: "Add a house", systemImage: "plus", action: add)
                Button(action: nearMe) {
                    Label("Near me", systemImage: "location.north.line.fill")
                        .font(CurbsideFont.button)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Palette.signWhite)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .signFace(Palette.infoBlue, rule: Palette.signWhite)
                }
                .buttonStyle(SignPressStyle())
                StopSignButton(title: "TALK", accessibilityLabel: "Talk: capture by voice or text", action: talk)
            }
            if showsCredit {
                // ODbL: the outlines are OSM data, so the credit sits on the map wherever they are drawn.
                Text("© OpenStreetMap contributors")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 3))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding([.horizontal, .bottom], Spacing.md)
        .padding(.top, Spacing.sm)
    }
}
