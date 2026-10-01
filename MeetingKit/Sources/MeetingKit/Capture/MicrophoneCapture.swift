import AVFoundation

/// The local microphone, captured with AVAudioEngine like Murmur's recorder.
final class MicrophoneCapture {
    private var engine = AVAudioEngine()

    func start(onBuffer: @escaping BufferHandler) throws {
        // A fresh engine picks up the current input device and its format.
        engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError("No microphone is available.") }
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tap(onBuffer))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Built as a static so the realtime tap closure captures nothing actor-isolated.
    private static func tap(_ onBuffer: @escaping BufferHandler) -> AVAudioNodeTapBlock {
        { buffer, time in
            onBuffer(buffer, time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime) : nil)
        }
    }
}
