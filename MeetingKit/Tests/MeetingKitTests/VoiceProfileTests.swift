import Foundation
@testable import MeetingKit
import Testing

/// Unit vector along `axis`, nudged toward `toward` so similarities are controllable.
private func voice(_ axis: Int, toward other: Int? = nil, by amount: Float = 0, dims: Int = 8) -> [Float] {
    var v = [Float](repeating: 0, count: dims)
    v[axis] = 1
    if let other { v[other] = amount }
    return VoiceMath.normalized(v)
}

@MainActor private func tempStore() -> VoiceProfileStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
    return VoiceProfileStore(directory: dir)
}

@MainActor
struct VoiceProfileTests {
    @Test func cosineBasics() {
        #expect(abs(VoiceMath.cosine([1, 0], [2, 0]) - 1) < 1e-6)
        #expect(abs(VoiceMath.cosine([1, 0], [0, 3])) < 1e-6)
        #expect(VoiceMath.cosine([1, 0], [1, 0, 0]) == -1) // mismatched dimensions never match
    }

    @Test func matchRespectsThreshold() throws {
        let store = tempStore()
        try store.enroll(name: "Alice", embeddings: [voice(0)], consentAt: Date())
        // cos(voice(0), voice(0 toward 1 by 1)) = 1/√2 ≈ 0.707
        let near = voice(0, toward: 1, by: 1)
        #expect(store.bestMatch(for: near)?.profile.name == "Alice")
        store.matchThreshold = 0.8
        #expect(store.bestMatch(for: near) == nil)
        #expect(store.bestMatch(for: voice(3)) == nil)
    }

    @Test func bestOfSeveralEmbeddingsCounts() throws {
        let store = tempStore()
        let alice = try store.enroll(name: "Alice", embeddings: [voice(0)], consentAt: Date())
        try store.refine(alice.id, with: [voice(2)], consentAt: Date()) // e.g. Alice on a phone bridge
        #expect(store.bestMatch(for: voice(2))?.profile.id == alice.id)
    }

    @Test func assignmentIsOneToOne() throws {
        let store = tempStore()
        try store.enroll(name: "Alice", embeddings: [voice(0)], consentAt: Date())
        try store.enroll(name: "Bob", embeddings: [voice(1)], consentAt: Date())
        let clusters = [
            "S1": voice(0, toward: 2, by: 0.2), // very close to Alice
            "S2": voice(0, toward: 2, by: 0.9), // also Alice-like, but less
            "S3": voice(1),                     // Bob
            "S4": voice(5),                     // stranger
        ]
        let names = store.assign(clusters: clusters).mapValues(\.profile.name)
        #expect(names == ["S1": "Alice", "S3": "Bob"])
    }

    @Test func unknownClustersAreNumberedBySpeakingOrder() throws {
        let store = tempStore()
        let bob = try store.enroll(name: "Bob", embeddings: [voice(1)], consentAt: Date())
        let diarization = Diarization(
            segments: [SpeakerSegment(start: 0, end: 1, speaker: "S3"),
                       SpeakerSegment(start: 1, end: 2, speaker: "S1"),
                       SpeakerSegment(start: 2, end: 3, speaker: "S2")],
            centroids: ["S1": voice(1), "S2": voice(4), "S3": voice(5)])
        let speakers = Meeting.labels(for: diarization, matches: store.assign(clusters: diarization.centroids))
        #expect(speakers["S1"] == Meeting.Speaker(name: "Bob", profileID: bob.id))
        #expect(speakers["S3"]?.name == "Speaker 1")
        #expect(speakers["S2"]?.name == "Speaker 2")
    }

    @Test func persistenceRoundTrip() throws {
        let store = tempStore()
        let alice = try store.enroll(name: " Alice ", embeddings: [voice(0), voice(1)], consentAt: Date())
        try store.rename(alice.id, to: "Alicia")
        let reloaded = VoiceProfileStore(directory: store.fileURL.deletingLastPathComponent())
        #expect(reloaded.profiles.count == 1)
        #expect(reloaded.profiles[0].name == "Alicia")
        #expect(reloaded.profiles[0].embeddings == [voice(0), voice(1)])
        #expect(reloaded.profiles[0].id == alice.id)
    }

    @Test func mergeDeleteAndCap() throws {
        let store = tempStore()
        store.maxEmbeddingsPerProfile = 3
        let a = try store.enroll(name: "Alice", embeddings: [voice(0), voice(1)], consentAt: Date())
        let b = try store.enroll(name: "alice (laptop)", embeddings: [voice(2), voice(3)], consentAt: Date())
        try store.merge([a.id, b.id], into: a.id)
        #expect(store.profiles.map(\.name) == ["Alice"])
        #expect(store.profiles[0].embeddings == [voice(1), voice(2), voice(3)]) // oldest dropped
        try store.delete(a.id)
        #expect(store.profiles.isEmpty)
        #expect(VoiceProfileStore(directory: store.fileURL.deletingLastPathComponent()).profiles.isEmpty)
    }

    @Test func namingASpeakerEnrollsThenRefines() throws {
        let store = tempStore()
        let recording = MeetingRecording(id: UUID(), title: "t", startedAt: Date(), duration: 1,
                                         folder: FileManager.default.temporaryDirectory)
        var meeting = Meeting(recording: recording,
                              diarization: Diarization(segments: [], centroids: ["S1": voice(0), "S2": voice(0, toward: 1, by: 0.3)]),
                              micWords: [], systemWords: [], speakers: [:])
        let consent = Date(timeIntervalSince1970: 1_000_000)
        try meeting.name(speaker: "S1", as: "Alice", rememberWithConsentAt: consent, in: store)
        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].consentAt == consent)
        #expect(meeting.diarization.centroids["S1"] == nil) // moved into the profile
        try meeting.name(speaker: "S2", as: "alice", rememberWithConsentAt: Date(), in: store) // same person, matched by name
        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].embeddings.count == 2)
        #expect(store.profiles[0].consentAt == consent) // the first consent is kept
        #expect(meeting.speakers["S2"]?.name == "Alice")
    }

    @Test func namingWithoutRememberingSavesNoVoice() throws {
        let store = tempStore()
        let recording = MeetingRecording(id: UUID(), title: "t", startedAt: Date(), duration: 1,
                                         folder: FileManager.default.temporaryDirectory)
        var meeting = Meeting(recording: recording,
                              diarization: Diarization(segments: [], centroids: ["S1": voice(0), "S2": voice(1)]),
                              micWords: [], systemWords: [], speakers: [:])
        try meeting.name(speaker: "S1", as: "Carol", in: store)
        #expect(store.profiles.isEmpty)
        #expect(meeting.speakers["S1"] == Meeting.Speaker(name: "Carol", profileID: nil))
        #expect(meeting.diarization.centroids["S1"] != nil) // still rememberable later
        // A same-named profile is linked, but gets no new samples.
        let bob = try store.enroll(name: "Bob", embeddings: [voice(3)], consentAt: Date())
        try meeting.name(speaker: "S2", as: "bob", in: store)
        #expect(meeting.speakers["S2"]?.profileID == bob.id)
        #expect(store.profiles[0].embeddings.count == 1)
    }

    @Test func retentionExpiresUnusedAndOldProfiles() throws {
        let now = Date()
        let day: TimeInterval = 86_400
        let fresh = VoiceProfile(name: "a", embeddings: [voice(0)], updatedAt: now, consentAt: now)
        let unused = VoiceProfile(name: "b", embeddings: [voice(0)], updatedAt: now - 400 * day, consentAt: now - 400 * day)
        let matched = VoiceProfile(name: "c", embeddings: [voice(0)], updatedAt: now - 400 * day,
                                   consentAt: now - 400 * day, lastMatchedAt: now - 10 * day)
        let ancient = VoiceProfile(name: "d", embeddings: [voice(0)], updatedAt: now, consentAt: now - 1100 * day,
                                   lastMatchedAt: now)
        #expect(!fresh.isExpired(now: now))
        #expect(unused.isExpired(now: now))
        #expect(!matched.isExpired(now: now))
        #expect(ancient.isExpired(now: now)) // the 3-year cap holds however often it's used

        // Enforced on load, and the file is rewritten without them.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([fresh, unused, matched, ancient]).write(to: dir.appendingPathComponent("profiles.json"))
        #expect(VoiceProfileStore(directory: dir).profiles.map(\.name) == ["a", "c"])
        let raw = try String(contentsOf: dir.appendingPathComponent("profiles.json"), encoding: .utf8)
        #expect(!raw.contains("\"b\"") && !raw.contains("\"d\""))
    }

    @Test func oldProfilesWithoutConsentStillDecode() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
        let json = #"[{"id":"\#(UUID().uuidString)","name":"Old","embeddings":[[1,0]],"updatedAt":"\#(stamp)"}]"#
        try Data(json.utf8).write(to: dir.appendingPathComponent("profiles.json"))
        let store = VoiceProfileStore(directory: dir)
        #expect(store.profiles.map(\.name) == ["Old"])
        #expect(store.profiles[0].consentAt == nil)
    }

    @Test func matchingKeepsProfilesAndDeleteAllWipes() throws {
        let store = tempStore()
        let alice = try store.enroll(name: "Alice", embeddings: [voice(0)], consentAt: Date())
        let when = Date(timeIntervalSince1970: 2_000_000_000)
        store.markMatched([alice.id], at: when)
        let dir = store.fileURL.deletingLastPathComponent()
        #expect(VoiceProfileStore(directory: dir).profiles.first?.lastMatchedAt == when)
        try store.removeAll()
        #expect(store.profiles.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL.path))
        try VoiceProfileStore.deleteAll(in: dir) // no file: still fine
    }

    @Test func unrememberedVoiceprintsExpireWithTheMeeting() {
        let old = MeetingRecording(id: UUID(), title: "t", startedAt: Date() - 31 * 86_400, duration: 1,
                                   folder: FileManager.default.temporaryDirectory)
        var meeting = Meeting(recording: old, diarization: Diarization(segments: [], centroids: ["S1": voice(0)]),
                              micWords: [], systemWords: [], speakers: [:])
        let first = meeting.dropExpiredVoiceprints(), second = meeting.dropExpiredVoiceprints()
        #expect(first && !second)
        #expect(meeting.diarization.centroids.isEmpty)
        var recent = meeting
        recent.recording.startedAt = Date() - 29 * 86_400 // still time to tick "Remember"
        recent.diarization.centroids = ["S1": voice(0)]
        let dropped = recent.dropExpiredVoiceprints()
        #expect(!dropped)
    }

    @Test func recordingConsentDecodesBackwardCompatibly() throws {
        let old = #"{"id":"\#(UUID().uuidString)","title":"t","startedAt":"2026-01-01T00:00:00Z","duration":1,"folder":"file:///tmp/x/"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(MeetingRecording.self, from: Data(old.utf8)).consentConfirmedAt == nil)
        var recording = try decoder.decode(MeetingRecording.self, from: Data(old.utf8))
        #expect(recording.announcementCopiedAt == nil)
        recording.consentConfirmedAt = Date(timeIntervalSince1970: 1_800_000_000)
        recording.announcementCopiedAt = Date(timeIntervalSince1970: 1_799_999_990)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let again = try decoder.decode(MeetingRecording.self, from: encoder.encode(recording))
        #expect(again.consentConfirmedAt == recording.consentConfirmedAt)
        #expect(again.announcementCopiedAt == recording.announcementCopiedAt)
    }
}
