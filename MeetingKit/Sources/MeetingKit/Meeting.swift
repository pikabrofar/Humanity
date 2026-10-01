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

    /// "This cluster is Alice." Labels the transcript only, unless `rememberWithConsentAt` is
    /// set: the time the user attested that Alice agreed to have her voiceprint saved. Then
    /// the voice is saved so Alice is recognized next time: an existing profile with that
    /// name gets this meeting's embedding as another sample; otherwise a new profile is
    /// created. Without it, a same-named profile is linked but gets no new samples. An
    /// automatic match that the user overrides was never written to the old profile, so
    /// nothing needs undoing.
    @MainActor
    public mutating func name(speaker cluster: String, as name: String, rememberWithConsentAt consent: Date? = nil,
                              in store: VoiceProfileStore) throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, cluster != TranscriptAligner.localSpeakerID else { return }
        let samples = diarization.centroids[cluster].map { [$0] } ?? []
        var profile = store.profile(named: name)
        if let consent {
            if let existing = profile {
                try store.refine(existing.id, with: samples, consentAt: consent)
            } else if !samples.isEmpty {
                profile = try store.enroll(name: name, embeddings: samples, consentAt: consent)
            }
            diarization.centroids[cluster] = nil // now kept in the profile, under its retention
        }
        speakers[cluster] = Speaker(name: profile?.name ?? name, profileID: profile?.id)
    }

    /// Unremembered speakers' embeddings stay only so they can be remembered later, and are
    /// deleted 30 days after the meeting.
    public static let unrememberedVoiceprintLimit: TimeInterval = 30 * 86_400

    /// - Returns: true when embeddings were removed and the meeting should be saved.
    public mutating func dropExpiredVoiceprints(now: Date = Date()) -> Bool {
        guard !diarization.centroids.isEmpty,
              now.timeIntervalSince(recording.startedAt) > Self.unrememberedVoiceprintLimit else { return false }
        diarization.centroids = [:]
        return true
    }

    public var fileURL: URL { recording.folder.appendingPathComponent("meeting.json") }

    public func save() throws { try JSONFile.write(self, to: fileURL) }

    public static func load(from folder: URL) throws -> Meeting {
        try JSONFile.read(Meeting.self, from: folder.appendingPathComponent("meeting.json"))
    }
}

enum JSONFile {
    static func write(_ value: some Encodable, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: Data(contentsOf: url))
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
        var recording = recording
        let fm = FileManager.default
        // Sequential on purpose: the speech engine and Core ML both want the Neural Engine.
        var systemWords: [TimedWord] = []
        var diarization = Diarization(segments: [], centroids: [:])
        var systemFailure: Error?
        if fm.fileExists(atPath: recording.systemURL.path) {
            do {
                systemWords = try await transcriber.transcribe(recording.systemURL)
                // Nobody spoke on the call (or it was too short): nothing to diarize, and the
                // diarizer can reject clips that short. The transcript is then just "You".
                // Without diarization, call words still show, as "Remote".
                if !systemWords.isEmpty { diarization = try await diarizer.diarize(recording.systemURL) }
            } catch {
                // A failing call track mustn't cost you your own words; keep them and say why.
                systemFailure = error
                recording.callAudioError = "Call audio couldn't be processed: \(error.localizedDescription)"
            }
        }
        let micWords = fm.fileExists(atPath: recording.micURL.path) ? try await transcriber.transcribe(recording.micURL) : []
        // Nothing to show: fail, so the recording stays listed for another try.
        if let systemFailure, micWords.isEmpty, systemWords.isEmpty { throw systemFailure }

        // No recording consent (audio from elsewhere, e.g. a planted folder): transcribe it,
        // but never identify anyone in it by voice.
        let matches = recording.consentConfirmedAt == nil ? [:] : await profiles.assign(clusters: diarization.centroids)
        await profiles.markMatched(matches.values.map(\.profile.id))
        let meeting = Meeting(recording: recording, diarization: diarization, micWords: micWords, systemWords: systemWords,
                              speakers: Meeting.labels(for: diarization, matches: matches))
        try meeting.save()
        return meeting
    }
}
