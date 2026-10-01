import AVFoundation
import ScreenCaptureKit

/// Fallback for macOS before 14.4, or when a process tap can't be created: records an
/// app's audio through ScreenCaptureKit. Needs Screen Recording permission. Filtering by
/// app also catches its helper processes, since ScreenCaptureKit groups them by app.
final class ScreenCaptureAudio: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream: SCStream?
    private var onBuffer: BufferHandler?
    private let queue = DispatchQueue(label: "MeetingKit.screenCaptureAudio", qos: .userInitiated)

    func start(_ source: AudioSource, onBuffer: @escaping BufferHandler) async throws {
        self.onBuffer = onBuffer
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else { throw CaptureError("No display to attach audio capture to.") }
        let filter: SCContentFilter
        if let bundleID = source.bundleID {
            let apps = content.applications.filter { $0.bundleIdentifier == bundleID }
            guard !apps.isEmpty else { throw CaptureError("\(source.displayName) isn't running.") }
            filter = SCContentFilter(display: display, including: apps, exceptingWindows: [])
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        // Video can't be turned off, so ask for the smallest, slowest stream possible.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        // A screen output is added only so ScreenCaptureKit doesn't log dropped frames.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let buffer = Self.pcmBuffer(sampleBuffer) else { return }
        // ScreenCaptureKit stamps samples on the host clock, the same one the mic uses.
        onBuffer?(buffer, sampleBuffer.presentationTimeStamp.seconds)
    }

    private static func pcmBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(frames),
                                                                  into: buffer.mutableAudioBufferList)
        return status == noErr ? buffer : nil
    }
}
