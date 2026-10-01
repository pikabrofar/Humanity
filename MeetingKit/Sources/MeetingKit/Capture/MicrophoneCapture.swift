import AVFoundation

/// The local microphone, captured with AVAudioEngine like Murmur's recorder.
@MainActor
final class MicrophoneCapture {
    private var engine = AVAudioEngine()
    private var configObserver: NSObjectProtocol?
    /// Why the mic stopped mid-meeting, when a device change left no usable input.
    var failure: Error?

    func start(onBuffer: @escaping BufferHandler) throws {
        // A fresh engine picks up the current input device and its format.
        engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError("No microphone is available.") }
        // nil = the node's own format. Passing a format that no longer matches
        // the hardware (e.g. AirPods just connected) raises an uncatchable exception.
        input.installTap(onBus: 0, bufferSize: 4096, format: nil, block: Self.tap(onBuffer))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        // A device change stops the engine and buffers silently stop arriving: rebuild
        // on the new device. The writer pads the gap and converts the new format.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.engine.isRunning else { return }
                self.stop()
                do { try self.start(onBuffer: onBuffer) } catch { self.failure = error }
            }
        }
    }

    func stop() {
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Built as a static so the realtime tap closure captures nothing actor-isolated.
    nonisolated private static func tap(_ onBuffer: @escaping BufferHandler) -> AVAudioNodeTapBlock {
        { buffer, time in
            onBuffer(buffer, time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime) : nil)
        }
    }
}
