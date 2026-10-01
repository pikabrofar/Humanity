import Accelerate
import AVFoundation
import MeetingKit

/// Captures the microphone with AVAudioEngine, writes AAC to disk, and hands
/// every buffer to the transcriber.
@MainActor
final class AudioRecorder {
    private var engine = AVAudioEngine()
    private var writer: TrackWriter?
    private var startedAt: Date?
    private var configObserver: NSObjectProtocol?

    /// - Parameter onLost: called when the input device changes or disconnects
    ///   mid-recording; the engine has stopped itself by then.
    func start(writingTo url: URL?,
               onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               onLevel: @escaping @Sendable (Float) -> Void,
               onLost: @escaping @MainActor () -> Void) throws {
        // A fresh engine picks up the current input device and its format.
        engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MessageError("No microphone is available.") }

        // Converts to 48 kHz mono AAC: the encoder rejects some device formats (96 kHz,
        // more than two channels), which used to lose the audio without a word.
        writer = url.map { TrackWriter(url: $0, channels: 1) }
        // nil = the node's own format. Passing a format that no longer matches
        // the hardware (e.g. AirPods just connected) raises an uncatchable exception.
        input.installTap(onBus: 0, bufferSize: 1024, format: nil,
                         block: Self.tap(writer: writer, onBuffer: onBuffer, onLevel: onLevel))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            writer = nil
            throw MessageError("Couldn't start the microphone. Check System Settings › Sound › Input.")
        }
        // A device change stops the engine; buffers silently stop arriving unless we notice.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                if self?.engine.isRunning == false { onLost() }
            }
        }
        startedAt = Date()
    }

    /// - Returns: the recording's length in seconds, and why audio wasn't saved, if it wasn't.
    @discardableResult
    func stop() -> (duration: TimeInterval, audioError: Error?) {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        writer?.finish() // finalizes the m4a
        let audioError = writer?.status.error
        writer = nil
        defer { startedAt = nil }
        return (startedAt.map { Date().timeIntervalSince($0) } ?? 0, audioError)
    }

    /// Built outside the main actor because the tap runs on a realtime audio
    /// thread; a main-actor closure there would trip Swift's isolation checks.
    nonisolated private static func tap(writer: TrackWriter?,
                                        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
                                        onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            writer?.write(buffer, at: nil)
            onBuffer(buffer)
            onLevel(level(of: buffer))
        }
    }

    /// RMS of the first channel mapped from -50…0 dBFS to 0…1, which tracks
    /// how loud speech feels better than a linear scale.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(buffer.frameLength))
        let db = 20 * log10(max(rms, 1e-6))
        return min(max((db + 50) / 50, 0), 1)
    }
}
