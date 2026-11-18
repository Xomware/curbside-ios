import SwiftUI

/// Capture, from the TALK sign: say or type it, then check the changes and save. Closing drops the words.
struct CaptureView: View {
    @State private var model: CaptureModel
    @State private var recorder = Recorder()
    let place: Place
    let footprints: [Footprint]
    let saved: () async -> Void

    @Environment(\.dismiss) private var dismiss

    init(model: CaptureModel, place: Place, footprints: [Footprint], saved: @escaping () async -> Void) {
        _model = State(initialValue: model)
        self.place = place
        self.footprints = footprints
        self.saved = saved
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.background)
                .navigationTitle(reviewing ? "Check the changes" : "Talk")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    if model.phase == .review {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Record again", systemImage: "mic", action: model.revise)
                        }
                    }
                }
        }
        .tint(Palette.ink)
        .interactiveDismissDisabled(!model.transcript.isEmpty)
        .sensoryFeedback(.success, trigger: model.phase == .saved)
        .onDisappear { Task { await recorder.stop() } }
    }

    private var reviewing: Bool { [.review, .saving, .saved].contains(model.phase) }

    @ViewBuilder private var content: some View {
        if reviewing {
            CaptureReview(model: model, place: place, footprints: footprints, save: save) { dismiss() }
        } else {
            CaptureInput(model: model, recorder: recorder)
                .overlay {
                    if model.phase == .parsing {
                        ProgressView("Reading it")
                            .tint(Palette.signGreen)
                            .padding(Spacing.md)
                            .background(Palette.surface, in: .rect(cornerRadius: 8))
                    }
                }
        }
    }

    private func save() {
        Task {
            guard await model.apply() else { return }
            await saved()
            dismiss()
        }
    }
}
