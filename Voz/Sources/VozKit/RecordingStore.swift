import Foundation

/// Plain files in one folder: `<id>.json` plus `<id>.m4a`. Easy to inspect,
/// back up, or delete by hand, and no database to migrate.
public struct RecordingStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// ~/Library/Application Support/Voz/Recordings
    public static var standard: RecordingStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // The app was called Murmur; keep existing recordings.
        let current = base.appendingPathComponent("Voz", isDirectory: true)
        let legacy = base.appendingPathComponent("Murmur", isDirectory: true)
        if !FileManager.default.fileExists(atPath: current.path), FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: current)
        }
        return RecordingStore(directory: current.appendingPathComponent("Recordings", isDirectory: true))
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

    public func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: jsonURL(for: id))
        try? FileManager.default.removeItem(at: audioURL(for: id))
    }
}
