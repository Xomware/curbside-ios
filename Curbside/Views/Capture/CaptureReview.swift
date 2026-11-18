import SwiftUI

/// Mockup 04, the work zone: what you said with the evidence painted in, the changes to keep or wave off, and the
/// phrases that couldn't be placed.
struct CaptureReview: View {
    let model: CaptureModel
    let place: Place
    let footprints: [Footprint]
    let save: () -> Void
    let discard: () -> Void

    @State private var placing: NewRef?
    @State private var editing: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                WorkZoneBanner(title: "CHANGES AHEAD", detail: "\(model.ops.count) found · check before saving")
                if let message = model.message {
                    Text(message)
                        .font(CurbsideFont.body)
                        .foregroundStyle(Palette.ink)
                }
                said
                VStack(alignment: .leading, spacing: 0) {
                    heading("SAVE THESE")
                    if model.ops.isEmpty {
                        Text("Nothing to save from that. Say more, or add it on the card.")
                            .font(CurbsideFont.body)
                            .foregroundStyle(Palette.ink)
                    }
                    ForEach(Array(model.ops.enumerated()), id: \.offset) { index, op in
                        OpRow(number: index + 1, op: op, summary: summary(op), placed: model.placements[op.householdRef]) {
                            model.toggle(index)
                        } placeIt: {
                            placing = NewRef(id: op.householdRef, label: newLabels[op.householdRef] ?? "the new house")
                        } edit: {
                            editing = index
                        }
                    }
                }
                ForEach(model.unresolved, id: \.self) { phrase in
                    WorkZoneBanner(title: "DETOUR", detail: "Couldn't place \u{201C}\(phrase)\u{201D}")
                }
            }
            .padding(Spacing.md)
        }
        .safeAreaInset(edge: .bottom) { actions }
        .sheet(item: Binding(get: { editing.map(EditIndex.init) }, set: { editing = $0?.id })) { target in
            OpEditor(op: model.ops[target.id]) { model.edit(target.id, $0) }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $placing) { ref in
            PlacePicker(place: place, footprints: footprints, households: model.households, label: ref.label) {
                model.place(ref.id, at: $0)
            }
        }
    }

    private var said: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            heading("WHAT YOU SAID")
            Text(marked)
                .font(CurbsideFont.body)
                .foregroundStyle(Palette.ink)
                .lineSpacing(Spacing.xs)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 8))
    }

    private var actions: some View {
        // SignButton fills its width, so each side gets a fixed share, 1 : 1.6 as in the mockup.
        HStack(spacing: Spacing.sm) {
            Button("Discard", action: discard)
                .font(CurbsideFont.button)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Palette.surface, in: .rect(cornerRadius: 8))
                .buttonStyle(SignPressStyle())
                .containerRelativeFrame(.horizontal) { width, _ in (width - Spacing.md * 2 - Spacing.sm) / 2.6 }
            SignButton(title: saveTitle, action: save)
                .disabled(!model.canSave)
                .opacity(model.canSave ? 1 : 0.5)
        }
        .padding(Spacing.md)
        .background(Palette.background)
    }

    private var saveTitle: String {
        if model.phase == .saving { return "Saving" }
        if !model.unplaced.isEmpty { return "Place the new house" }
        return model.checkedCount == 1 ? "Save 1 change" : "Save \(model.checkedCount) changes"
    }

    private var newLabels: [String: String] {
        Dictionary(model.ops.filter { $0.op == .createHousehold }.map { ($0.householdRef, $0.fields["label"]?.text ?? "New house") }) { a, _ in a }
    }

    private func summary(_ op: CaptureOp) -> CaptureSummary {
        CaptureSummary(op, households: model.households, newLabels: newLabels)
    }

    /// The transcript with each change's evidence highlighted like fresh paint and tagged with its row number.
    private var marked: AttributedString {
        let transcript = model.transcript
        var text = AttributedString()
        var cursor = transcript.startIndex
        for mark in evidenceMarks(in: transcript, evidence: model.ops.map(\.evidence)) {
            text += AttributedString(transcript[cursor..<mark.range.lowerBound])
            var paint = AttributedString(transcript[mark.range] + " \(mark.number)")
            paint.backgroundColor = Palette.warning.opacity(0.7)
            paint.foregroundColor = Palette.signInk
            text += paint
            cursor = mark.range.upperBound
        }
        return text + AttributedString(transcript[cursor...])
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(CurbsideFont.label)
            .foregroundStyle(Palette.inkSecondary)
            .padding(.bottom, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct EditIndex: Identifiable {
    let id: Int
}

private struct NewRef: Identifiable {
    let id: String
    let label: String
}

/// The orange work-zone panel: a diamond, a black-on-orange title and a line of detail.
struct WorkZoneBanner: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Diamond()
                .fill(Palette.workZone)
                .stroke(Palette.signInk, lineWidth: 2)
                .overlay { Image(systemName: "exclamationmark").font(.headline.weight(.black)) }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(CurbsideFont.signHeadline)
                Text(detail).font(CurbsideFont.detail.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Palette.signInk)
        .padding(Spacing.sm)
        .signFace(Palette.workZone, rule: Palette.signInk)
        .accessibilityElement(children: .combine)
    }
}
