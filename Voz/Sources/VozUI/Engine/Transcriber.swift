import AVFoundation
import VozKit
import Speech

/// A streaming speech-to-text session. Audio may be appended from any thread
/// as soon as the session exists, even before `start()` returns, so the first
/// words aren't lost while the model loads.
@MainActor
protocol LiveTranscriber: AnyObject {
    /// The whole transcript so far, including not-yet-final words.
    var onPartial: ((String) -> Void)? { get set }
    func start() async throws
    nonisolated func append(_ buffer: AVAudioPCMBuffer)
    /// Ends the audio and returns the final transcript.
    func finish() async -> String
    func cancel()
}

struct TranscriptionError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

enum Transcribers {
    /// Prefers the macOS 26 SpeechAnalyzer (much more accurate, always local);
    /// otherwise the older recognizer, forced to stay on-device.
    @MainActor static func make() async -> LiveTranscriber {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) {
            return AnalyzerTranscriber(locale: locale)
        }
        return LegacyTranscriber()
    }

    static var engineName: String {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable { return "SpeechAnalyzer" }
        return "On-device Speech"
    }
}

// MARK: - macOS 26: SpeechAnalyzer

@available(macOS 26, *)
@MainActor
final class AnalyzerTranscriber: LiveTranscriber {
    var onPartial: ((String) -> Void)?

    private let locale: Locale
    // Fed from the audio thread. AsyncStream's continuation is thread-safe and
    // each buffer is handed off, never touched again by the sender.
    nonisolated(unsafe) private let raw = AsyncStream.makeStream(of: AVAudioPCMBuffer.self)
    private var analyzer: SpeechAnalyzer?
    private var pump: Task<Void, Never>?
    private var results: Task<Void, Never>?
    private var finalized = ""
    private var volatile = ""

    init(locale: Locale) {
        self.locale = locale
    }

    func start() async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        // The first use of a language downloads Apple's speech model, shared
        // system-wide. Only the model is downloaded; audio never leaves the Mac.
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await install.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError("No audio format is compatible with the speech model.")
        }

        let (inputs, feed) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let converter = BufferConverter(to: format)
        let rawStream = raw.stream
        // Converts mic buffers (often 48 kHz float) to the model's format off the main thread.
        pump = Task.detached {
            for await buffer in rawStream {
                if let converted = converter.convert(buffer) { feed.yield(AnalyzerInput(buffer: converted)) }
            }
            feed.finish()
        }
        results = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        finalized = Transcript.join(finalized, text)
                        volatile = ""
                    } else {
                        volatile = text
                    }
                    onPartial?(Transcript.join(finalized, volatile))
                }
            } catch {}
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        try await analyzer.start(inputSequence: inputs)
    }

    nonisolated func append(_ buffer: AVAudioPCMBuffer) {
        raw.continuation.yield(buffer)
    }

    func finish() async -> String {
        raw.continuation.finish()
        await pump?.value
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await results?.value
        return Transcript.join(finalized, volatile).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        raw.continuation.finish()
        results?.cancel()
        let analyzer = analyzer
        Task { await analyzer?.cancelAndFinishNow() }
    }
}

/// Resamples buffers to the speech model's format. Used only by one task at a time.
final class BufferConverter: @unchecked Sendable {
    private let format: AVAudioFormat
    private var converter: AVAudioConverter?

    init(to format: AVAudioFormat) {
        self.format = format
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none // no silence padding between chunks of a live stream
        }
        guard let converter else { return nil }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : output
    }
}

// MARK: - macOS 14–15: SFSpeechRecognizer

@MainActor
final class LegacyTranscriber: LiveTranscriber {
    var onPartial: ((String) -> Void)?

    // Appended from the audio thread; `append` is documented as thread-safe.
    nonisolated(unsafe) private let request = SFSpeechAudioBufferRecognitionRequest()
    private var recognizer: SFSpeechRecognizer? // held for the session's lifetime
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var done = false
    private var waiter: CheckedContinuation<Void, Never>?

    func start() async throws {
        guard Permissions.speech == .granted else {
            throw TranscriptionError("Allow Speech Recognition in Quick Setup.")
        }
        guard let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError("Speech recognition isn't available for your language.")
        }
        // Without on-device support the recognizer would send audio to Apple's
        // servers. Refuse instead: that would break Voz's privacy promise.
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError("On-device recognition isn't installed for \(recognizer.locale.identifier). Turn on Dictation in System Settings › Keyboard to download it.")
        }
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognizer.queue = .main
        self.recognizer = recognizer
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let result {
                    self.latest = result.bestTranscription.formattedString
                    self.onPartial?(self.latest)
                }
                if result?.isFinal == true || error != nil { self.complete() }
            }
        }
    }

    nonisolated func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
    }

    func finish() async -> String {
        request.endAudio()
        if !done {
            // The final result usually lands within a second; never leave the HUD hanging.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.complete()
            }
            await withCheckedContinuation { waiter = $0 }
        }
        return latest.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        task?.cancel()
        complete()
    }

    private func complete() {
        done = true
        waiter?.resume()
        waiter = nil
    }
}
