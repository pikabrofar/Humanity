import AVFoundation
import Combine

/// The two audio files of one meeting. Both start at the moment recording began.
public struct MeetingRecording: Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var startedAt: Date
    public var duration: TimeInterval
    /// Folder holding mic.m4a, system.m4a and, once processed, meeting.json.
    public var folder: URL
    /// "Call audio wasn't captured: …" when system.m4a stayed empty; nil when it recorded.
    public var callAudioError: String?

    public var micURL: URL { folder.appendingPathComponent("mic.m4a") }
    public var systemURL: URL { folder.appendingPathComponent("system.m4a") }

    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Humanity/Meetings", isDirectory: true)
    }
}

/// Records the microphone ("You") and one app's audio ("everyone else") as two
/// separate, time-aligned tracks. Keeping them apart makes "You" exact and gives
/// diarization a track with only the remote voices.
@MainActor
public final class MeetingRecorder: ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var startedAt: Date?
    /// 0…1, for meters.
    @Published public private(set) var micLevel: Float = 0
    @Published public private(set) var systemLevel: Float = 0
    /// "Process tap" or "ScreenCaptureKit": which path is recording the app.
    @Published public private(set) var captureMethod: String?
    /// Why the last recording has no call audio, so it never goes missing silently.
    @Published public private(set) var callAudioError: String?

    private let directory: URL
    private let mic = MicrophoneCapture()
    private var tap: AnyObject? // ProcessTapCapture, which is 14.4+ only
    private var screen: ScreenCaptureAudio?
    private var writers: (mic: TrackWriter, system: TrackWriter)?
    private var current: MeetingRecording?
    private var starting = false // isRecording flips only after several awaits

    public init(directory: URL = MeetingRecording.defaultDirectory) {
        self.directory = directory
    }

    public static func availableApps() -> [AudioApp] { AudioApp.running() }

    public func start(_ source: AudioSource, title: String? = nil) async throws {
        guard !isRecording, !starting else { return }
        starting = true
        defer { starting = false }
        callAudioError = nil
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw CaptureError("Allow Microphone access in System Settings › Privacy & Security.")
        }
        let now = Date()
        let recording = MeetingRecording(
            id: UUID(), title: title ?? "\(source.displayName) call", startedAt: now, duration: 0,
            folder: directory.appendingPathComponent(Self.folderName(now), isDirectory: true))
        try FileManager.default.createDirectory(at: recording.folder, withIntermediateDirectories: true)

        // One host-clock origin for both tracks; each writer pads to it.
        let origin = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        let writers = (mic: TrackWriter(url: recording.micURL, meetingStart: origin),
                       system: TrackWriter(url: recording.systemURL, meetingStart: origin))
        let micSink = sink(writers.mic, level: \.micLevel)
        let systemSink = sink(writers.system, level: \.systemLevel)

        try mic.start(onBuffer: micSink)
        do {
            captureMethod = try await startSystemAudio(source, onBuffer: systemSink)
        } catch {
            mic.stop()
            writers.mic.finish()
            writers.system.finish()
            throw error
        }
        self.writers = writers
        current = recording
        startedAt = now
        isRecording = true
    }

    /// Stops both tracks and returns the finished recording, ready for `MeetingProcessor`.
    @discardableResult
    public func stop() async -> MeetingRecording? {
        guard isRecording, var recording = current else { return nil }
        mic.stop()
        if #available(macOS 14.4, *) { (tap as? ProcessTapCapture)?.stop() }
        await screen?.stop()
        writers?.mic.finish()
        writers?.system.finish()
        if let system = writers?.system.status, system.frames == 0 {
            let reason = system.error?.localizedDescription ?? "no sound arrived through \(captureMethod ?? "the capture")."
            callAudioError = Self.notCaptured(reason)
            recording.callAudioError = callAudioError
        }
        recording.duration = Date().timeIntervalSince(recording.startedAt)
        tap = nil
        screen = nil
        writers = nil
        current = nil
        isRecording = false
        startedAt = nil
        micLevel = 0
        systemLevel = 0
        return recording
    }

    /// Process tap first (no Screen Recording permission, macOS 14.4+), else ScreenCaptureKit.
    private func startSystemAudio(_ source: AudioSource, onBuffer: @escaping BufferHandler) async throws -> String {
        var tapFailure: Error?
        if #available(macOS 14.4, *) {
            let tap = ProcessTapCapture()
            do {
                try await tap.start(source, onBuffer: onBuffer)
                self.tap = tap
                return "Process tap"
            } catch {
                // Fall through: ScreenCaptureKit may still work, e.g. for a helper we didn't map.
                tapFailure = error
            }
        }
        let screen = ScreenCaptureAudio()
        do {
            try await screen.start(source, onBuffer: onBuffer)
        } catch {
            let reasons = [tapFailure, error].compactMap { $0?.localizedDescription }
            throw CaptureError(Self.notCaptured(reasons.joined(separator: " ScreenCaptureKit: ")))
        }
        self.screen = screen
        return "ScreenCaptureKit"
    }

    private static func notCaptured(_ reason: String) -> String { "Call audio wasn't captured: \(reason)" }

    /// Writes on the capture thread and publishes the level on the main actor.
    private func sink(_ writer: TrackWriter, level: ReferenceWritableKeyPath<MeetingRecorder, Float>) -> BufferHandler {
        { [weak self] buffer, host in
            writer.write(buffer, at: host)
            let value = TrackWriter.level(of: buffer)
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self[keyPath: level] = value
            }
        }
    }

    private static func folderName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: date)
    }
}
