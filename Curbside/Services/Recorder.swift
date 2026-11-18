import AVFoundation
import Observation
import Speech

/// Dictation with `SpeechAnalyzer`, which runs only on device: there is no server recognition in this API to fall
/// back to, so audio and words never leave the phone. Nothing is saved; `text` is all there is.
@MainActor @Observable
final class Recorder {
    enum State: Equatable {
        case idle
        case starting
        case recording
        /// Why voice can't be used; typing still works.
        case unavailable(String)
    }

    private(set) var state = State.idle
    /// What was already typed, then everything heard so far.
    private(set) var text = ""

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var analyzer: SpeechAnalyzer?
    @ObservationIgnored private var input: AsyncStream<AnalyzerInput>.Continuation?
    @ObservationIgnored private var listening: Task<Void, Never>?

    func start(after typed: String) async {
        state = .starting
        guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else {
            state = .unavailable("Voice isn't available on this iPhone. Type it instead.")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .unavailable("The microphone is off for Curbside. Type it, or turn it on in Settings.")
            return
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        do {
            // First use per language downloads Apple's on-device model.
            if let download = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await download.downloadAndInstall()
            }
            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw CocoaError(.featureUnsupported)
            }
            let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
            try AVAudioSession.sharedInstance().setActive(true)
            Self.tap(engine.inputNode, converting: format, into: continuation)
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: stream)
            self.analyzer = analyzer
            input = continuation
        } catch {
            teardown()
            state = .unavailable("Couldn't start listening. Type it instead.")
            return
        }

        let lead = typed.isEmpty ? "" : typed + " "
        text = typed
        state = .recording
        listening = Task {
            var heard = ""
            do {
                for try await result in transcriber.results {
                    let words = String(result.text.characters)
                    if result.isFinal { heard += words }
                    text = lead + heard + (result.isFinal ? "" : words)
                }
            } catch {
                // The analyzer ended early; what was heard so far stays.
            }
        }
    }

    func stop() async {
        guard state == .recording || state == .starting else { return }
        teardown()
        // Flushes the last words still being decided; a failure here only loses those.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await listening?.value
        analyzer = nil
        listening = nil
        state = .idle
    }

    private func teardown() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        input?.finish()
        input = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The tap runs on the audio thread, so it is built outside the main actor.
    nonisolated private static func tap(_ node: AVAudioInputNode, converting format: AVAudioFormat, into continuation: AsyncStream<AnalyzerInput>.Continuation) {
        let natural = node.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: natural, to: format) else { return }
        node.installTap(onBus: 0, bufferSize: 4096, format: natural) { buffer, _ in
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / natural.sampleRate) + 1
            guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
            // `convert` calls its input block synchronously on this thread before returning, so neither escapes; the
            // block is only typed @Sendable.
            nonisolated(unsafe) let buffer = buffer
            nonisolated(unsafe) var fed = false
            let status = converter.convert(to: converted, error: nil) { _, outStatus in
                if fed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                fed = true
                outStatus.pointee = .haveData
                return buffer
            }
            if status != .error { continuation.yield(AnalyzerInput(buffer: converted)) }
        }
    }
}
