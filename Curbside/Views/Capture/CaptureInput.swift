import SwiftUI

/// Say it or type it. The stop sign starts and stops on-device listening; "Read it" sends the words to be parsed.
struct CaptureInput: View {
    @Bindable var model: CaptureModel
    let recorder: Recorder

    @FocusState private var typing: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Who did you talk to? What's new with them?")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.inkSecondary)
                TextField("Ran into Clementine walking Waffles...", text: $model.transcript, axis: .vertical)
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(6...)
                    .focused($typing)
                    .disabled(recorder.state == .recording)
                    .padding(Spacing.sm)
                    .background(Palette.surface, in: .rect(cornerRadius: 8))
                    .accessibilityLabel("What happened")
                HStack {
                    Label("ON DEVICE", systemImage: "lock.fill")
                        .accessibilityLabel("Voice stays on this iPhone")
                    Spacer()
                    Text("\(model.transcript.count)/\(CaptureModel.limit)")
                        .foregroundStyle(tooLong ? Palette.stop : Palette.inkSecondary)
                        .accessibilityLabel("\(model.transcript.count) of \(CaptureModel.limit) characters")
                }
                .font(CurbsideFont.mono)
                .foregroundStyle(Palette.inkSecondary)
                ForEach([unavailable, model.message].compactMap(\.self), id: \.self) { message in
                    Text(message)
                        .font(CurbsideFont.body)
                        .foregroundStyle(Palette.ink)
                }
                StopSignButton(title: recorder.state == .recording ? "STOP" : "TALK", accessibilityLabel: recorder.state == .recording ? "Stop listening" : "Talk") {
                    Task { await talk() }
                }
                .frame(maxWidth: .infinity)
                .disabled(recorder.state == .starting)
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            SignButton(title: model.phase == .parsing ? "Reading it" : "Read it") {
                Task {
                    await recorder.stop()
                    await model.parse()
                }
            }
            .disabled(!canRead)
            .opacity(canRead ? 1 : 0.5)
            .padding(Spacing.md)
            .background(Palette.background)
        }
        .onChange(of: recorder.text) { _, heard in
            model.transcript = heard
            model.source = .voice
        }
    }

    private var tooLong: Bool { model.transcript.count > CaptureModel.limit }

    private var canRead: Bool {
        model.phase == .input && !tooLong && !model.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var unavailable: String? {
        if case .unavailable(let reason) = recorder.state { reason } else { nil }
    }

    private func talk() async {
        if recorder.state == .recording {
            await recorder.stop()
        } else {
            typing = false
            await recorder.start(after: model.transcript)
        }
    }
}
