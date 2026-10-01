import Combine
import Foundation

/// A named person and a few voice embeddings of them. Embeddings are 256 floats
/// summarizing timbre. No audio is kept with them, but treat them as biometric data.
public struct VoiceProfile: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// L2-normalized, oldest first. Several are kept because one voice sounds different
    /// through a headset, a laptop mic or a phone bridge.
    public var embeddings: [[Float]]
    public var updatedAt: Date
    /// When the user attested that this person agreed to have their voiceprint saved.
    /// Nil only for profiles saved before attestation existed.
    public var consentAt: Date?
    /// Last time a meeting was labeled with this profile.
    public var lastMatchedAt: Date?

    public init(id: UUID = UUID(), name: String, embeddings: [[Float]], updatedAt: Date = Date(),
                consentAt: Date? = nil, lastMatchedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.embeddings = embeddings.map(VoiceMath.normalized)
        self.updatedAt = updatedAt
        self.consentAt = consentAt
        self.lastMatchedAt = lastMatchedAt
    }

    /// Retention: a profile not matched or updated for 12 months is deleted, and so is any
    /// profile 3 years after its consent (BIPA's outer bound), however often it is used.
    public static let unusedLimit: TimeInterval = 365 * 86_400
    public static let ageLimit: TimeInterval = 3 * 365 * 86_400

    public func isExpired(now: Date = Date()) -> Bool {
        let lastUsed = max(updatedAt, lastMatchedAt ?? updatedAt)
        return now.timeIntervalSince(lastUsed) > Self.unusedLimit
            || now.timeIntervalSince(consentAt ?? updatedAt) > Self.ageLimit
    }
}

public struct SpeakerMatch: Hashable, Sendable {
    public var profile: VoiceProfile
    /// Cosine similarity in -1…1.
    public var similarity: Float
}

/// Saved voice profiles, persisted as one JSON file. Main-actor bound because SwiftUI
/// lists observe it and every mutation writes the file.
@MainActor
public final class VoiceProfileStore: ObservableObject {
    @Published public private(set) var profiles: [VoiceProfile] = []

    /// Minimum cosine similarity between a meeting cluster's centroid and a profile for
    /// the cluster to get that profile's name. FluidAudio's streaming SpeakerManager calls
    /// two embeddings the same speaker at similarity ≥ 0.35 (distance 0.65); 0.5 is
    /// stricter on purpose, because a wrong name is worse than "Speaker 2". Raise it if
    /// people with similar voices get mixed up; lower it if known people stay unnamed.
    public var matchThreshold: Float = 0.5
    /// Caps file size and lets old recording conditions age out as refinements arrive.
    public var maxEmbeddingsPerProfile = 20

    public let fileURL: URL

    public nonisolated static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Humanity/VoiceProfiles", isDirectory: true)
    }

    public init(directory: URL = VoiceProfileStore.defaultDirectory) {
        fileURL = directory.appendingPathComponent("profiles.json")
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            profiles = (try? decoder.decode([VoiceProfile].self, from: data)) ?? []
        }
        // Enforce retention on every load; a failed write retries on the next one.
        let kept = profiles.filter { !$0.isExpired() }
        if kept.count != profiles.count {
            profiles = kept
            try? save()
        }
    }

    /// Removes every saved voiceprint on disk, e.g. from a host's "delete all data".
    /// A live store must also call `removeAll()`, or its next save writes them back.
    public nonisolated static func deleteAll(in directory: URL = VoiceProfileStore.defaultDirectory) throws {
        let file = directory.appendingPathComponent("profiles.json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    public func removeAll() throws {
        profiles = []
        try Self.deleteAll(in: fileURL.deletingLastPathComponent())
    }

    /// Records that these profiles labeled a meeting, which keeps them from expiring.
    public func markMatched(_ ids: some Sequence<UUID>, at date: Date = Date()) {
        let ids = Set(ids)
        guard !ids.isEmpty else { return }
        for i in profiles.indices where ids.contains(profiles[i].id) { profiles[i].lastMatchedAt = date }
        try? save()
    }

    public func profile(id: UUID) -> VoiceProfile? { profiles.first { $0.id == id } }

    public func profile(named name: String) -> VoiceProfile? {
        let key = name.trimmingCharacters(in: .whitespaces)
        return profiles.first { $0.name.compare(key, options: .caseInsensitive) == .orderedSame }
    }

    /// The closest profile at or above `matchThreshold`. A profile scores its best single
    /// embedding, so one good sample from similar conditions is enough.
    public func bestMatch(for embedding: [Float]) -> SpeakerMatch? {
        rankedMatches(for: embedding).first
    }

    private func rankedMatches(for embedding: [Float]) -> [SpeakerMatch] {
        profiles.compactMap { profile in
            let score = profile.embeddings.map { VoiceMath.cosine($0, embedding) }.max() ?? -1
            return score >= matchThreshold ? SpeakerMatch(profile: profile, similarity: score) : nil
        }
        .sorted { $0.similarity > $1.similarity }
    }

    /// Names meeting clusters one-to-one: two clusters in one meeting are by construction
    /// different voices, so the most confident pairs claim profiles first and a profile
    /// is never given to two clusters.
    public func assign(clusters centroids: [String: [Float]]) -> [String: SpeakerMatch] {
        let candidates = centroids.flatMap { cluster, centroid in
            rankedMatches(for: centroid).map { (cluster, $0) }
        }
        .sorted { $0.1.similarity > $1.1.similarity }
        var result: [String: SpeakerMatch] = [:]
        var taken = Set<UUID>()
        for (cluster, match) in candidates where result[cluster] == nil && !taken.contains(match.profile.id) {
            result[cluster] = match
            taken.insert(match.profile.id)
        }
        return result
    }

    /// Saves a new voiceprint. `consentAt` is when the user attested that the person agreed;
    /// there is deliberately no way to enroll without it.
    @discardableResult
    public func enroll(name: String, embeddings: [[Float]], consentAt: Date) throws -> VoiceProfile {
        let profile = VoiceProfile(name: name.trimmingCharacters(in: .whitespaces),
                                   embeddings: Array(embeddings.suffix(maxEmbeddingsPerProfile)), consentAt: consentAt)
        profiles.append(profile)
        try save()
        return profile
    }

    public func rename(_ id: UUID, to name: String) throws {
        try update(id) { $0.name = name.trimmingCharacters(in: .whitespaces) }
    }

    /// Adds embeddings after the user confirms who a cluster was and attests consent again.
    /// The first consent date is kept, so the 3-year limit can't be extended by refining.
    public func refine(_ id: UUID, with embeddings: [[Float]], consentAt: Date) throws {
        let cap = maxEmbeddingsPerProfile
        try update(id) {
            $0.embeddings = Array(($0.embeddings + embeddings.map(VoiceMath.normalized)).suffix(cap))
            $0.consentAt = $0.consentAt ?? consentAt
        }
    }

    /// Folds duplicate profiles of one person into `target`, keeping all their samples.
    public func merge(_ ids: [UUID], into target: UUID) throws {
        let sources = profiles.filter { ids.contains($0.id) && $0.id != target }
        let cap = maxEmbeddingsPerProfile
        try update(target) { $0.embeddings = Array(($0.embeddings + sources.flatMap(\.embeddings)).suffix(cap)) }
        profiles.removeAll { p in sources.contains { $0.id == p.id } }
        try save()
    }

    public func delete(_ id: UUID) throws {
        profiles.removeAll { $0.id == id }
        try save()
    }

    private func update(_ id: UUID, _ change: (inout VoiceProfile) -> Void) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        change(&profiles[index])
        profiles[index].updatedAt = Date()
        try save()
    }

    private func save() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createPrivateDirectory(at: directory)
        try? MeetingStorage.excludeFromBackup(directory) // biometric data stays off backups
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(profiles).write(to: fileURL, options: .atomic)
    }
}

public enum VoiceMath {
    public static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denominator = (na * nb).squareRoot()
        return denominator > 0 ? dot / denominator : -1
    }

    public static func normalized(_ v: [Float]) -> [Float] {
        let norm = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
        return norm > 0 ? v.map { $0 / norm } : v
    }
}
