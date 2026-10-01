import Accelerate
import AVFoundation

/// Writes one track as AAC, padding silence so that frame N of every track is
/// N / sampleRate seconds after the meeting started. Both files then share one
/// timeline, which is what lets mic and system words interleave correctly.
final class TrackWriter: @unchecked Sendable {
    private let url: URL
    private let meetingStart: Double // host-clock seconds
    private let lock = NSLock() // capture callbacks and stop() run on different threads
    private var file: AVAudioFile?
    private var framesWritten: AVAudioFramePosition = 0
    private var failure: Error?
    private var finished = false

    init(url: URL, meetingStart: Double) {
        self.url = url
        self.meetingStart = meetingStart
    }

    /// - Parameter hostSeconds: host-clock time of the buffer's first frame, when known.
    func write(_ buffer: AVAudioPCMBuffer, at hostSeconds: Double?) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, buffer.frameLength > 0 else { return }
        do {
            // Created on the first buffer so the file matches whatever format the
            // device or tap delivers; AVAudioFile then never has to convert.
            if file == nil {
                let format = buffer.format
                file = try AVAudioFile(forWriting: url, settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ], commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            }
            guard let file else { return }
            if let hostSeconds {
                let missing = Self.paddingFrames(at: hostSeconds, meetingStart: meetingStart,
                                                 sampleRate: buffer.format.sampleRate, framesWritten: framesWritten)
                try writeSilence(missing, format: buffer.format, to: file)
            }
            try file.write(from: buffer)
            framesWritten += AVAudioFramePosition(buffer.frameLength)
        } catch {
            // A failed write loses a buffer, not the meeting; keep going, but remember why.
            if failure == nil { failure = error }
        }
    }

    /// Frames on disk (0 means the file was never created) and the first write error.
    var status: (frames: AVAudioFramePosition, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        return (framesWritten, failure)
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        finished = true
        // Closing finalizes the m4a; before macOS 15 that happens on deallocation.
        if #available(macOS 15, *) { file?.close() }
        file = nil
    }

    /// Silence needed before a buffer that starts at `hostSeconds`. Small drift is
    /// ignored (it's clock jitter, not a gap); a buffer arriving early never truncates.
    static func paddingFrames(at hostSeconds: Double, meetingStart: Double,
                              sampleRate: Double, framesWritten: AVAudioFramePosition) -> AVAudioFramePosition {
        // `exactly` turns a NaN or absurd timestamp into "no padding" instead of a trap.
        guard let expected = AVAudioFramePosition(exactly: ((hostSeconds - meetingStart) * sampleRate).rounded()) else { return 0 }
        let missing = expected - framesWritten
        return missing > AVAudioFramePosition(sampleRate * 0.05) ? missing : 0
    }

    private func writeSilence(_ frames: AVAudioFramePosition, format: AVAudioFormat, to file: AVAudioFile) throws {
        var remaining = frames
        let chunk = AVAudioFrameCount(format.sampleRate)
        guard remaining > 0, let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return }
        while remaining > 0 {
            silence.frameLength = AVAudioFrameCount(min(remaining, AVAudioFramePosition(chunk)))
            for buffer in UnsafeMutableAudioBufferListPointer(silence.mutableAudioBufferList) {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            try file.write(from: silence)
            framesWritten += AVAudioFramePosition(silence.frameLength)
            remaining -= AVAudioFramePosition(silence.frameLength)
        }
    }

    /// RMS of the first channel mapped from -50…0 dBFS to 0…1, which tracks
    /// how loud speech feels better than a linear scale.
    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, buffer.stride, &rms, vDSP_Length(buffer.frameLength))
        let db = 20 * log10(max(rms, 1e-6))
        return min(max((db + 50) / 50, 0), 1)
    }
}
