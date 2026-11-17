import SwiftUI

/// One proposed change: checkbox, whose house, what changes, and the words it came from. A new house also says
/// where it goes on the map, since apply needs a spot.
struct OpRow: View {
    let number: Int
    let op: CaptureOp
    let summary: CaptureSummary
    let placed: Spot?
    let toggle: () -> Void
    let placeIt: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Toggle(isOn: Binding(get: { op.checked }, set: { _ in toggle() })) {
                Text("Save: \(summary.who), \(summary.change)")
            }
            .toggleStyle(CheckboxStyle())
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    if let number = summary.number {
                        Text(number)
                            .font(CurbsideFont.mono)
                            .foregroundStyle(Palette.signInk)
                            .padding(.horizontal, Spacing.xs)
                            .background(Palette.signWhite, in: .rect(cornerRadius: 3))
                    }
                    Text(summary.who)
                        .font(CurbsideFont.label)
                        .foregroundStyle(Palette.inkSecondary)
                    if op.needsReview {
                        Text("CHECK")
                            .font(CurbsideFont.label)
                            .foregroundStyle(Palette.signInk)
                            .padding(.horizontal, Spacing.xs)
                            .background(Palette.workZone, in: .rect(cornerRadius: 3))
                            .accessibilityLabel("Check this: placed by position, not by name")
                    }
                }
                Text(summary.change)
                    .font(CurbsideFont.button)
                    .foregroundStyle(op.checked ? Palette.ink : Palette.inkSecondary)
                Text("\(number) · \u{201C}\(op.evidence)\u{201D}")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
                if op.op == .createHousehold, op.checked {
                    placement
                }
            }
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.inkSecondary.opacity(0.3)).frame(height: 2)
        }
    }

    @ViewBuilder private var placement: some View {
        if let placed {
            Text(placed.address.map { "Goes at \($0)" } ?? "Placed on the map")
                .font(CurbsideFont.detail)
                .foregroundStyle(Palette.ink)
        }
        Button(action: placeIt) {
            Label(placed == nil ? "Place it on the map" : "Move it", systemImage: "mappin.and.ellipse")
                .font(CurbsideFont.detail.weight(.bold))
                .foregroundStyle(Palette.signInk)
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 44)
                .signFace(placed == nil ? Palette.workZone : Palette.signWhite, rule: Palette.signInk, cornerRadius: 6)
        }
        .buttonStyle(SignPressStyle())
    }
}

#Preview {
    let ops = [
        CaptureOp(op: .addPerson, householdRef: "new:1", targetID: nil, fields: ["name": .string("Ollie"), "role": .string("kid"), "birth_year": .int(2020), "birth_year_approx": .bool(true)], evidence: "a kid about 6 named Ollie", confidence: 0.85, needsReview: false, checked: true),
        CaptureOp(op: .createHousehold, householdRef: "new:1", targetID: nil, fields: ["label": .string("Gray house")], evidence: "the gray house", confidence: 0.4, needsReview: true, checked: true),
    ]
    VStack(spacing: 0) {
        ForEach(Array(ops.enumerated()), id: \.offset) { index, op in
            OpRow(number: index + 1, op: op, summary: CaptureSummary(op, households: [], newLabels: ["new:1": "Gray house"]), placed: nil) {} placeIt: {}
        }
    }
    .padding()
    .background(Palette.background)
}
