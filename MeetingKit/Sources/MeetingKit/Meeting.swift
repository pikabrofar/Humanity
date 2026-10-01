import Foundation

/// A processed meeting: the raw ingredients (words, diarization) plus who each
/// cluster is. The transcript is derived, so renaming a speaker just recomputes it.
public struct Meeting: Codable, Hashable, Sendable, Identifiable {
    public struct Speaker: Codable, Hashable, Sendable {
        public var name: String
        /// Set when the name came from (or was saved to) a voice profile.
        public var profileID: UUID?
    }

    public var recording: MeetingRecording
    public var diarization: Diarization
    public var micWords: [TimedWord]
    public var systemWords: [TimedWord]
    /// Keyed by diarization cluster ID.
    public var speakers: [String: Speaker]
    public var localName = "You"

    public var id: UUID { recording.id }

    public var transcript: MeetingTranscript {
        TranscriptAligner.align(micWords: micWords, systemWords: systemWords, segments: diarization.segments,
                                names: speakers.mapValues(\.name), localName: localName)
    }

    /// Profile names for recognized clusters; "Speaker 1", "Speaker 2"… for the rest,
    /// numbered by who spoke first so the labels read naturally top to bottom.
    public static func labels(for diarization: Diarization, matches: [String: SpeakerMatch]) -> [String: Speaker] {
        var order: [String] = []
        for segment in diarization.segments.sorted(by: { $0.start < $1.start }) where !order.contains(segment.speaker) {
            order.append(segment.speaker)
        }
        order += diarization.centroids.keys.filter { !order.contains($0) }.sorted()
        var speakers: [String: Speaker] = [:]
        var unknown = 0
        for cluster in order {
            if let match = matches[cluster] {
                speakers[cluster] = Speaker(name: match.profile.name, profileID: match.profile.id)
            } else {
                unknown += 1
                speakers[cluster] = Speaker(name: "Speaker \(unknown)", profileID: nil)
            }
        }
        return speakers
    }

    /// "This cluster is Alice." Saves the voice so Alice is recognized next time:
    /// an existing profile with that name gets this meeting's embedding as another
    /// sample; otherwise a new profile is created. An automatic match that the user
    /// overrides was never written to the old profile, so nothing needs undoing.
    @MainActor
    public mutating func name(speaker cluster: String, as name: String, in store: VoiceProfileStore) throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, cluster != TranscriptAligner.localSpeakerID else { return }
        let samples = diarization.centroids[cluster].map { [$0] } ?? []
        let profile: VoiceProfile?
        if let existing = store.profile(named: name) {
            try store.refine(existing.id, with: samples)
            profile = existing
        } else if !samples.isEmpty {
            profile = try store.enroll(name: name, embeddings: samples)
        } else {
            profile = nil
        }
        speakers[cluster] = Speaker(name: profile?.name ?? name, profileID: profile?.id)
    }

    public var fileURL: URL { recording.folder.appendingPathComponent("meeting.json") }

    public func save() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: fileURL, options: .atomic)
    }

    public static func load(from folder: URL) throws -> Meeting {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Meeting.self, from: Data(contentsOf: folder.appendingPathComponent("meeting.json")))
    }
}

/// Turns a finished recording into a `Meeting`. Runs after the call, not live:
/// offline diarization is far more accurate, and nothing competes with the call for CPU.
public struct MeetingProcessor: Sendable {
    public var diarizer: any SpeakerDiarizer
    public var transcriber: any FileTranscribing

    public init(diarizer: any SpeakerDiarizer = FluidDiarizer(),
                transcriber: any FileTranscribing = SpeechFileTranscriber()) {
        self.diarizer = diarizer
        self.transcriber = transcriber
    }

    public func process(_ recording: MeetingRecording, profiles: VoiceProfileStore) async throws -> Meeting {
        let fm = FileManager.default
        let hasSystem = fm.fileExists(atPath: recording.systemURL.path)
        // Sequential on purpose: the speech engine and Core ML both want the Neural Engine.
        let systemWords = hasSystem ? try await transcriber.transcribe(recording.systemURL) : []
        // Nobody spoke on the call (or it was too short): nothing to diarize, and the
        // diarizer can reject clips that short. The transcript is then just "You".
        let diarization = systemWords.isEmpty ? Diarization(segments: [], centroids: [:])
                                              : try await diarizer.diarize(recording.systemURL)
        let micWords = fm.fileExists(atPath: recording.micURL.path) ? try await transcriber.transcribe(recording.micURL) : []

        let matches = await profiles.assign(clusters: diarization.centroids)
        let meeting = Meeting(recording: recording, diarization: diarization, micWords: micWords, systemWords: systemWords,
                              speakers: Meeting.labels(for: diarization, matches: matches))
        try meeting.save()
        return meeting
    }
}
