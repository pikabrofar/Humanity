import Accelerate
import AVFoundation

/// Writes one track as AAC, padding silence so that frame N of every track is
/// N / 48 000 seconds after the meeting started. Both files then share one
/// timeline, which is what lets mic and system words interleave correctly.
public final class TrackWriter: @unchecked Sendable {
    private let url: URL
    private let meetingStart: Double // host-clock seconds
    private let channels: AVAudioChannelCount
    private let lock = NSLock() // capture callbacks and stop() run on different threads
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var framesWritten: AVAudioFramePosition = 0
    private var lastSound: Double?
    private var failure: Error?
    private var finished = false

    /// - Parameters:
    ///   - meetingStart: host-clock origin that timestamped buffers are padded to.
    ///   - channels: 1 for a microphone, 2 for call audio.
    public init(url: URL, meetingStart: Double = 0, channels: AVAudioChannelCount) {
        self.url = url
        self.meetingStart = meetingStart
        self.channels = channels
    }

    /// What goes on disk. The AAC encoder rejects some device formats (96 kHz, more
    /// than two channels) and a device change can switch formats mid-recording, so
    /// every buffer is converted to this one fixed format.
    static func fileFormat(channels: AVAudioChannelCount) -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channels)!
    }

    /// - Parameter hostSeconds: host-clock time of the buffer's first frame, when known.
    public func write(_ buffer: AVAudioPCMBuffer, at hostSeconds: Double?) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, buffer.frameLength > 0 else { return }
        do {
            // Created on the first buffer, so a recording that never got sound leaves no file.
            if file == nil {
                let format = Self.fileFormat(channels: channels)
                file = try AVAudioFile(forWriting: url, settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: format.channelCount,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ], commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            }
            guard let file else { return }
            let format = file.processingFormat
            let converted = try convert(buffer, to: format)
            if let hostSeconds {
                let missing = Self.paddingFrames(at: hostSeconds, meetingStart: meetingStart,
                                                 sampleRate: format.sampleRate, framesWritten: framesWritten)
                try writeSilence(missing, format: format, to: file)
            }
            guard converted.frameLength > 0 else { return } // the resampler's first call can hold everything back
            try file.write(from: converted)
            framesWritten += AVAudioFramePosition(converted.frameLength)
            if Self.level(of: buffer) > 0 { lastSound = Double(framesWritten) / format.sampleRate }
        } catch {
            // A failed write loses a buffer, not the meeting; keep going, but remember why.
            if failure == nil { failure = error }
        }
    }

    /// Frames on disk (0 means the file was never created), the first write error, and
    /// when, in seconds on the meeting timeline, the last buffer with sound ended.
    public var status: (frames: AVAudioFramePosition, error: Error?, lastSound: Double?) {
        lock.lock()
        defer { lock.unlock() }
        return (framesWritten, failure, lastSound)
    }

    public func finish() {
        lock.lock()
        defer { lock.unlock() }
        finished = true
        // Closing finalizes the m4a; before macOS 15 that happens on deallocation.
        if #available(macOS 15, *) { file?.close() }
        file = nil
    }

    /// One converter per input format: it keeps resampler state across buffers, and a
    /// device change (new format) simply gets a new one.
    private func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        if buffer.format == format { return buffer }
        if converter?.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: format) }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate) + 64
        guard let converter, let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw CaptureError("Can't convert \(buffer.format) audio to \(format).")
        }
        var fed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            inputStatus.pointee = fed ? .noDataNow : .haveData
            defer { fed = true }
            return fed ? nil : buffer
        }
        if status == .error { throw error ?? CaptureError("Couldn't convert the audio.") }
        return output
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
