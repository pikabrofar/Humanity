import AVFoundation
@testable import MeetingKit
import Testing

private func w(_ text: String, _ start: Double, _ end: Double) -> TimedWord {
    TimedWord(text: text, start: start, end: end)
}

struct AlignmentTests {
    let segments = [
        SpeakerSegment(start: 0, end: 5, speaker: "S1"),
        SpeakerSegment(start: 4.5, end: 10, speaker: "S2"), // overlaps S1 by half a second
    ]

    @Test func wordGoesToLargestOverlap() {
        #expect(TranscriptAligner.speaker(for: w("a", 1, 1.5), in: segments) == "S1")
        #expect(TranscriptAligner.speaker(for: w("b", 4.4, 4.7), in: segments) == "S1") // 0.3 s in S1 vs 0.2 s in S2
        #expect(TranscriptAligner.speaker(for: w("c", 4.6, 5.4), in: segments) == "S2") // 0.4 s in S1 vs 0.8 s in S2
    }

    @Test func wordInAGapGoesToNearestSegment() {
        let gapped = [SpeakerSegment(start: 0, end: 2, speaker: "S1"), SpeakerSegment(start: 6, end: 8, speaker: "S2")]
        #expect(TranscriptAligner.speaker(for: w("x", 2.3, 2.6), in: gapped) == "S1")
        #expect(TranscriptAligner.speaker(for: w("y", 5.2, 5.5), in: gapped) == "S2")
        #expect(TranscriptAligner.speaker(for: w("z", 1, 2), in: []) == nil)
    }

    @Test func buildsOrderedTurns() {
        let transcript = TranscriptAligner.align(
            micWords: [w("Hi", 0.2, 0.4), w("all.", 0.5, 0.8)],
            systemWords: [w("Hello", 1.2, 1.5), w("there.", 1.6, 1.9), w("Morning.", 6, 6.5)],
            segments: segments, names: ["S1": "Alice", "S2": "Bob"])
        #expect(transcript.turns.map(\.speakerName) == ["You", "Alice", "Bob"])
        #expect(transcript.turns.map(\.text) == ["Hi all.", "Hello there.", "Morning."])
        #expect(transcript.turns[1].start == 1.2 && transcript.turns[1].end == 1.9)
    }

    @Test func overlappingSpeechStaysInWholeTurns() {
        // You and Alice talk over each other; words interleave in time.
        let transcript = TranscriptAligner.align(
            micWords: [w("wait", 1.0, 1.3), w("one", 1.5, 1.7), w("second", 1.9, 2.2)],
            systemWords: [w("so", 1.1, 1.2), w("the", 1.4, 1.5), w("plan", 1.6, 1.9)],
            segments: segments, names: ["S1": "Alice"])
        #expect(transcript.turns.map(\.speakerName) == ["You", "Alice"])
        #expect(transcript.turns.map(\.text) == ["wait one second", "so the plan"])
    }

    @Test func longPauseSplitsTurns() {
        let transcript = TranscriptAligner.align(
            micWords: [w("one", 0, 0.5), w("two", 10, 10.5)], systemWords: [], segments: [], names: [:])
        #expect(transcript.turns.count == 2)
    }

    @Test func micEchoOfRemoteSpeechIsDropped() {
        let transcript = TranscriptAligner.align(
            micWords: [w("Budget", 1.25, 1.6), w("okay", 3, 3.2)],
            systemWords: [w("budget,", 1.0, 1.4)],
            segments: segments, names: ["S1": "Alice"])
        #expect(transcript.turns.map(\.text) == ["budget,", "okay"])
        #expect(transcript.turns.map(\.speakerName) == ["Alice", "You"])
    }

    @Test func noDiarizationFallsBackToRemote() {
        let transcript = TranscriptAligner.align(micWords: [], systemWords: [w("hey", 0, 1)], segments: [], names: [:])
        #expect(transcript.turns.first?.speakerName == "Remote")
    }
}

struct ExportTests {
    let transcript = MeetingTranscript(turns: [
        TranscriptTurn(speakerID: "S1", speakerName: "Alice", start: 83.4, end: 85, text: "Let's begin."),
        TranscriptTurn(speakerID: "you", speakerName: "You", start: 3725, end: 3726, text: "Sounds good."),
    ])

    @Test func markdown() {
        #expect(transcript.markdown(title: "Standup") == """
        # Standup

        **Alice** [00:01:23]: Let's begin.

        **You** [01:02:05]: Sounds good.

        """)
    }

    @Test func plainText() {
        #expect(transcript.plainText == "Alice: Let's begin.\nYou: Sounds good.")
    }

    @Test func timestamps() {
        #expect(MeetingTranscript.timestamp(0) == "00:00:00")
        #expect(MeetingTranscript.timestamp(59.9) == "00:00:59")
        #expect(MeetingTranscript.timestamp(-3) == "00:00:00")
    }
}

struct TrackAlignmentTests {
    @Test func padsOnlyRealGaps() {
        // First buffer arrives 0.5 s after the meeting origin: pad 24 000 frames at 48 kHz.
        #expect(TrackWriter.paddingFrames(at: 100.5, meetingStart: 100, sampleRate: 48_000, framesWritten: 0) == 24_000)
        // 10 ms of jitter is ignored.
        #expect(TrackWriter.paddingFrames(at: 101.01, meetingStart: 100, sampleRate: 48_000, framesWritten: 48_000) == 0)
        // A buffer that arrives early never truncates.
        #expect(TrackWriter.paddingFrames(at: 100.9, meetingStart: 100, sampleRate: 48_000, framesWritten: 48_000) == 0)
    }

    @Test func quietestCutPoint() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100))
        buffer.frameLength = 100
        for i in 0..<100 { buffer.floatChannelData![0][i] = (60..<70).contains(i) ? 0 : 0.5 }
        #expect(SpeechFileTranscriber.quietestFrame(in: buffer, after: 40, block: 10) == 65)
    }
}

struct MeetingPersistenceTests {
    @Test func meetingRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let meeting = Meeting(
            recording: MeetingRecording(id: UUID(), title: "Sync", startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                        duration: 60, folder: folder),
            diarization: Diarization(segments: [SpeakerSegment(start: 0, end: 2, speaker: "S1")], centroids: ["S1": [1, 0]]),
            micWords: [w("hi", 3, 3.2)], systemWords: [w("hello", 0.5, 1)],
            speakers: ["S1": .init(name: "Alice", profileID: nil)])
        try meeting.save()
        let loaded = try Meeting.load(from: folder)
        #expect(loaded == meeting)
        #expect(loaded.transcript.plainText == "Alice: hello\nYou: hi")
    }
}

struct SilentCallTests {
    struct Words: FileTranscribing {
        func transcribe(_ audioURL: URL) async throws -> [TimedWord] {
            audioURL.lastPathComponent == "mic.m4a" ? [w("Hmm,", 3.4, 5.5), w("hello?", 5.5, 6)] : []
        }
    }
    struct Unreachable: SpeakerDiarizer {
        func diarize(_ audioURL: URL) async throws -> Diarization { throw TranscriptionError("too short to diarize") }
    }

    @MainActor @Test func emptyCallTrackGivesJustYou() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let recording = MeetingRecording(id: UUID(), title: "Short", startedAt: Date(), duration: 11, folder: folder)
        for url in [recording.micURL, recording.systemURL] { FileManager.default.createFile(atPath: url.path, contents: Data()) }
        let meeting = try await MeetingProcessor(diarizer: Unreachable(), transcriber: Words())
            .process(recording, profiles: VoiceProfileStore(directory: folder))
        #expect(meeting.speakers.isEmpty)
        #expect(meeting.transcript.turns.map(\.speakerName) == ["You"])
    }

    @Test func badTimestampsDoNotTrap() {
        #expect(TrackWriter.paddingFrames(at: .nan, meetingStart: 100, sampleRate: 48_000, framesWritten: 0) == 0)
        #expect(MeetingTranscript.timestamp(.nan) == "00:00:00")
        #expect(MeetingTranscript.timestamp(.infinity) == "00:00:00")
    }

    @Test func meetingsSavedBeforeCallAudioErrorStillLoad() throws {
        let json = #"{"localName":"You","recording":{"id":"4151920D-F62F-47B0-ACAB-0A45F7C9FB9E","title":"Call","duration":11.5,"startedAt":"2026-10-01T02:56:51Z","folder":"file:\/\/\/tmp\/"},"diarization":{"segments":[],"centroids":{}},"systemWords":[],"speakers":{},"micWords":[]}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meeting = try decoder.decode(Meeting.self, from: Data(json.utf8))
        #expect(meeting.recording.callAudioError == nil)
    }
}
