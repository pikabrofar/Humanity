import Accelerate
import AVFoundation
import Speech

public protocol FileTranscribing: Sendable {
    /// Words with times in seconds from the start of the file.
    func transcribe(_ audioURL: URL) async throws -> [TimedWord]
}

public struct TranscriptionError: LocalizedError {
    public let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// On-device transcription of a recorded track, mirroring bocaS's engine choice:
/// the macOS 26 SpeechAnalyzer when available (far more accurate), otherwise
/// SFSpeechRecognizer forced to stay on-device. Nothing is sent to a server.
public struct SpeechFileTranscriber: FileTranscribing {
    public var locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public static var engineName: String {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable { return "SpeechAnalyzer" }
        return "On-device Speech"
    }

    public func transcribe(_ audioURL: URL) async throws -> [TimedWord] {
        if #available(macOS 26, *), SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            return try await analyze(audioURL, locale: supported)
        }
        return try await recognizeLegacy(audioURL)
    }

    // MARK: - macOS 26: SpeechAnalyzer

    @available(macOS 26, *)
    private func analyze(_ url: URL, locale: Locale) async throws -> [TimedWord] {
        // Final results only, each run tagged with its audio time range: that is what
        // lets words be matched to diarization segments.
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                            reportingOptions: [], attributeOptions: [.audioTimeRange])
        // The first use of a language downloads Apple's shared speech model; only the
        // model is downloaded, the audio stays on the Mac.
        if let install = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await install.downloadAndInstall()
        }
        let collector = Task {
            var words: [TimedWord] = []
            for try await result in transcriber.results {
                for run in result.text.runs {
                    guard let range = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] else { continue }
                    let text = String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { words.append(TimedWord(text: text, start: range.start.seconds, end: range.end.seconds)) }
                }
            }
            return words
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let file = try AVAudioFile(forReading: url)
        if let end = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: end)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value
    }

    // MARK: - macOS 14–15: SFSpeechRecognizer

    private func recognizeLegacy(_ url: URL) async throws -> [TimedWord] {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { done in SFSpeechRecognizer.requestAuthorization { _ in done.resume() } }
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError("Allow Speech Recognition in System Settings › Privacy & Security.")
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError("Speech recognition isn't available for your language.")
        }
        // Without on-device support the recognizer would upload audio. Refuse instead.
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError("On-device recognition isn't installed for \(recognizer.locale.identifier). Turn on Dictation in System Settings › Keyboard to download it.")
        }

        // The legacy recognizer is built for utterances and drops or restarts text on long
        // input, so feed it windows of under a minute, cut at the quietest moment near the
        // end of each so words are rarely split.
        let file = try AVAudioFile(forReading: url)
        let rate = file.processingFormat.sampleRate
        let maxFrames = AVAudioFrameCount(rate * 50)
        var words: [TimedWord] = []
        while file.framePosition < file.length {
            let offset = Double(file.framePosition) / rate
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: maxFrames) else { break }
            try file.read(into: buffer, frameCount: maxFrames)
            if buffer.frameLength == 0 { break }
            if file.framePosition < file.length {
                let cut = Self.quietestFrame(in: buffer, after: AVAudioFrameCount(rate * 40), block: AVAudioFrameCount(rate / 10))
                file.framePosition -= AVAudioFramePosition(buffer.frameLength - cut)
                buffer.frameLength = cut
            }
            words += try await recognize(buffer, with: recognizer).map {
                TimedWord(text: $0.text, start: $0.start + offset, end: $0.end + offset)
            }
        }
        return words
    }

    private func recognize(_ buffer: AVAudioPCMBuffer, with recognizer: SFSpeechRecognizer) async throws -> [TimedWord] {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.append(buffer)
        request.endAudio()
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed, result?.isFinal == true || error != nil else { return }
                resumed = true
                // A window with no speech ends in a "no speech detected" error; that's just empty.
                // Anything else is a real failure and must not pass for silence.
                if let error, !Self.isNoSpeech(error) { return continuation.resume(throwing: error) }
                let segments = result?.bestTranscription.segments ?? []
                continuation.resume(returning: segments.map {
                    TimedWord(text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration)
                })
            }
        }
    }

    static func isNoSpeech(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == "kAFAssistantErrorDomain" && error.code == 1110
    }

    /// Middle of the quietest `block`-sized stretch at or after `after` (by RMS of channel 0).
    static func quietestFrame(in buffer: AVAudioPCMBuffer, after: AVAudioFrameCount, block: AVAudioFrameCount) -> AVAudioFrameCount {
        guard let samples = buffer.floatChannelData?[0], block > 0, buffer.frameLength > after + block else {
            return buffer.frameLength
        }
        var best = buffer.frameLength, bestRMS = Float.greatestFiniteMagnitude
        var start = after
        while start + block <= buffer.frameLength {
            var rms: Float = 0
            vDSP_rmsqv(samples + Int(start), 1, &rms, vDSP_Length(block))
            if rms < bestRMS { bestRMS = rms; best = start + block / 2 }
            start += block
        }
        return best
    }
}
