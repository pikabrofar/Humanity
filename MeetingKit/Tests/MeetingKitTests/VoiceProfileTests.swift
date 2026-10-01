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
        try store.enroll(name: "Alice", embeddings: [voice(0)])
        // cos(voice(0), voice(0 toward 1 by 1)) = 1/√2 ≈ 0.707
        let near = voice(0, toward: 1, by: 1)
        #expect(store.bestMatch(for: near)?.profile.name == "Alice")
        store.matchThreshold = 0.8
        #expect(store.bestMatch(for: near) == nil)
        #expect(store.bestMatch(for: voice(3)) == nil)
    }

    @Test func bestOfSeveralEmbeddingsCounts() throws {
        let store = tempStore()
        let alice = try store.enroll(name: "Alice", embeddings: [voice(0)])
        try store.refine(alice.id, with: [voice(2)]) // e.g. Alice on a phone bridge
        #expect(store.bestMatch(for: voice(2))?.profile.id == alice.id)
    }

    @Test func assignmentIsOneToOne() throws {
        let store = tempStore()
        try store.enroll(name: "Alice", embeddings: [voice(0)])
        try store.enroll(name: "Bob", embeddings: [voice(1)])
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
        let bob = try store.enroll(name: "Bob", embeddings: [voice(1)])
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
        let alice = try store.enroll(name: " Alice ", embeddings: [voice(0), voice(1)])
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
        let a = try store.enroll(name: "Alice", embeddings: [voice(0), voice(1)])
        let b = try store.enroll(name: "alice (laptop)", embeddings: [voice(2), voice(3)])
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
        try meeting.name(speaker: "S1", as: "Alice", in: store)
        #expect(store.profiles.count == 1)
        try meeting.name(speaker: "S2", as: "alice", in: store) // same person, matched by name
        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].embeddings.count == 2)
        #expect(meeting.speakers["S2"]?.name == "Alice")
    }
}
