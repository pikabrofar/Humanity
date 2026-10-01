import FluidAudio
import Foundation

extension FileManager {
    /// Creates `url` (and missing parents) readable only by this user, and tightens it to
    /// 0700 if it already existed: meetings and voiceprints are other people's data too.
    public func createPrivateDirectory(at url: URL) throws {
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}

public enum MeetingStorage {
    /// ~/Library/Application Support/Sentidos. The suite was called Humanity: move the old
    /// folder over once (meetings, voice profiles, leftovers) so nothing is lost. `tidy`
    /// then keeps it 0700 and the voiceprints out of backups, as before.
    public static let supportFolder: URL = {
        let base = URL.applicationSupportDirectory
        let url = base.appendingPathComponent("Sentidos", isDirectory: true)
        let legacy = base.appendingPathComponent("Humanity", isDirectory: true)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacy.path) {
            try? fm.moveItem(at: legacy, to: url)
        }
        return url
    }()

    /// Once at launch: tightens existing folders, keeps voiceprints (biometric data) out of
    /// backups, removes FluidAudio's leftover temp audio, and keeps its debug lines out of logs.
    /// Meetings stay backed up: they are user data people expect to keep.
    public static func tidy(meetings: URL = MeetingRecording.defaultDirectory,
                            profiles: URL = VoiceProfileStore.defaultDirectory,
                            temporary: URL = FileManager.default.temporaryDirectory, now: Date = Date()) {
        let fm = FileManager.default
        for dir in [meetings, profiles] where fm.fileExists(atPath: dir.path) { try? fm.createPrivateDirectory(at: dir) }
        if fm.fileExists(atPath: profiles.path) { try? excludeFromBackup(profiles) }
        let files = (try? fm.contentsOfDirectory(at: temporary, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.lastPathComponent.hasPrefix("fluidaudio-streaming-") && file.pathExtension == "raw" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if now.timeIntervalSince(modified) > 3600 { try? fm.removeItem(at: file) }
        }
        AppLogger.minimumLevel = .warning
    }

    static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
