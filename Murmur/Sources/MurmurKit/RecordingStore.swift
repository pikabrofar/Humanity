import Foundation

/// Plain files in one folder: `<id>.json` plus `<id>.m4a`. Easy to inspect,
/// back up, or delete by hand, and no database to migrate.
public struct RecordingStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// ~/Library/Application Support/Murmur/Recordings
    public static var standard: RecordingStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return RecordingStore(directory: base.appendingPathComponent("Murmur/Recordings", isDirectory: true))
    }

    public func audioURL(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).m4a") }
    private func jsonURL(for id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    public func hasAudio(_ id: UUID) -> Bool { FileManager.default.fileExists(atPath: audioURL(for: id).path) }

    public func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ recording: Recording) throws {
        try prepare()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(recording).write(to: jsonURL(for: recording.id), options: .atomic)
    }

    /// Newest first. Unreadable files are skipped rather than failing the whole list.
    public func loadAll() -> [Recording] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Recording.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Recordings older than `days` (nil means keep forever), for the history retention setting.
    public static func expired(_ recordings: [Recording], olderThanDays days: Int?, now: Date = Date()) -> [Recording] {
        guard let days, days > 0 else { return [] }
        return recordings.filter { now.timeIntervalSince($0.createdAt) > TimeInterval(days) * 86_400 }
    }

    /// Removes the whole folder, including audio a crash left without a transcript.
    public func deleteEverything() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    public func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: jsonURL(for: id))
        try? FileManager.default.removeItem(at: audioURL(for: id))
    }
}
