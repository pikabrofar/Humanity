import AVFoundation
@testable import MeetingKit
import Testing

private func tempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingKitTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

struct ReliabilityTests {
    @Test func fileFormatIsAlways48kHz() {
        #expect(TrackWriter.fileFormat(channels: 1).sampleRate == 48_000)
        #expect(TrackWriter.fileFormat(channels: 1).channelCount == 1)
        #expect(TrackWriter.fileFormat(channels: 2).channelCount == 2)
    }

    /// AAC can't take 96 kHz or 4 channels directly; the writer must convert, not drop buffers.
    @Test func writes96kHzFourChannelInput() throws {
        let url = try tempFolder().appendingPathComponent("mic.m4a")
        let writer = TrackWriter(url: url, channels: 1)
        let layout = try #require(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 4))
        let format = AVAudioFormat(standardFormatWithSampleRate: 96_000, channelLayout: layout)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 9_600))
        buffer.frameLength = 9_600
        for c in 0..<4 { for i in 0..<9_600 { buffer.floatChannelData![c][i] = sinf(Float(i) * 0.05) * 0.5 } }
        for _ in 0..<10 { writer.write(buffer, at: nil) } // 1 s
        let status = writer.status
        writer.finish()
        #expect(status.error == nil)
        #expect(abs(Int(status.frames) - 48_000) < 1_000)
        #expect(status.lastSound != nil)
        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate == 48_000 && file.fileFormat.channelCount == 1)
    }

    @Test func warnsWhenCallGoesSilentWhileYouTalk() {
        let warning = MeetingRecorder.silenceWarning(callLastSound: 125, micLastSound: 590, duration: 600)
        #expect(warning?.contains("silent from 00:02:05") == true)
        // A call that never had sound while you talked.
        #expect(MeetingRecorder.silenceWarning(callLastSound: nil, micLastSound: 300, duration: 300) != nil)
        // Short trailing silence, or you were quiet too (the call just ended): no warning.
        #expect(MeetingRecorder.silenceWarning(callLastSound: 580, micLastSound: 599, duration: 600) == nil)
        #expect(MeetingRecorder.silenceWarning(callLastSound: 125, micLastSound: 130, duration: 600) == nil)
        #expect(MeetingRecorder.silenceWarning(callLastSound: 125, micLastSound: nil, duration: 600) == nil)
    }

    @Test func onlyNoSpeechCountsAsEmpty() {
        #expect(SpeechFileTranscriber.isNoSpeech(NSError(domain: "kAFAssistantErrorDomain", code: 1110)))
        #expect(!SpeechFileTranscriber.isNoSpeech(NSError(domain: "kAFAssistantErrorDomain", code: 1101)))
        #expect(!SpeechFileTranscriber.isNoSpeech(NSError(domain: NSCocoaErrorDomain, code: 1110)))
    }

    @Test func listsRecordingsThatWereNeverProcessed() throws {
        let root = try tempFolder()
        func recording(_ name: String, _ age: TimeInterval) throws -> MeetingRecording {
            let folder = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let r = MeetingRecording(id: UUID(), title: name, startedAt: Date(timeIntervalSinceNow: -age), duration: 5, folder: folder)
            try r.save()
            return r
        }
        let older = try recording("older", 100), newer = try recording("newer", 10), done = try recording("done", 50)
        try Meeting(recording: done, diarization: Diarization(segments: [], centroids: [:]),
                    micWords: [], systemWords: [], speakers: [:]).save()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("no metadata"), withIntermediateDirectories: true)
        #expect(MeetingRecording.unprocessed(in: root).map(\.id) == [newer.id, older.id]) // ISO dates drop sub-seconds
    }

    struct MicOnly: FileTranscribing {
        func transcribe(_ audioURL: URL) async throws -> [TimedWord] {
            guard audioURL.lastPathComponent == "mic.m4a" else { throw TranscriptionError("call track unreadable") }
            return [TimedWord(text: "hello", start: 1, end: 1.5)]
        }
    }
    struct NoDiarizer: SpeakerDiarizer {
        func diarize(_ audioURL: URL) async throws -> Diarization { Diarization(segments: [], centroids: [:]) }
    }
    struct Words: FileTranscribing {
        func transcribe(_ audioURL: URL) async throws -> [TimedWord] { [TimedWord(text: "hi", start: 0, end: 0.5)] }
    }
    struct OneVoice: SpeakerDiarizer {
        func diarize(_ audioURL: URL) async throws -> Diarization {
            Diarization(segments: [SpeakerSegment(start: 0, end: 1, speaker: "S1")], centroids: ["S1": [1, 0]])
        }
    }

    @MainActor @Test func noConsentMeansNoVoiceMatching() async throws {
        let folder = try tempFolder()
        let profiles = VoiceProfileStore(directory: folder)
        try profiles.enroll(name: "Alice", embeddings: [[1, 0]], consentAt: Date())
        var recording = MeetingRecording(id: UUID(), title: "Planted", startedAt: Date(), duration: 5, folder: folder)
        for url in [recording.micURL, recording.systemURL] { FileManager.default.createFile(atPath: url.path, contents: Data()) }
        let processor = MeetingProcessor(diarizer: OneVoice(), transcriber: Words())
        let planted = try await processor.process(recording, profiles: profiles)
        #expect(planted.speakers["S1"]?.name == "Speaker 1")
        #expect(!planted.systemWords.isEmpty) // still transcribed
        recording.consentConfirmedAt = Date()
        #expect(try await processor.process(recording, profiles: profiles).speakers["S1"]?.name == "Alice")
    }

    @Test func deletesOnlyMeetingFolders() throws {
        let root = try tempFolder(), outside = try tempFolder()
        let meeting = root.appendingPathComponent("2026-01-01 10.00.00")
        try FileManager.default.createDirectory(at: meeting, withIntermediateDirectories: true)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: (any Error).self) { try MeetingRecording.deleteFolder(outside, in: root) }
        #expect(throws: (any Error).self) { try MeetingRecording.deleteFolder(link, in: root) }
        #expect(throws: (any Error).self) { try MeetingRecording.deleteFolder(root.appendingPathComponent("x/../.."), in: root) }
        #expect(throws: (any Error).self) { try MeetingRecording.deleteFolder(root, in: root) }
        #expect(FileManager.default.fileExists(atPath: outside.path))
        try MeetingRecording.deleteFolder(meeting, in: root)
        #expect(!FileManager.default.fileExists(atPath: meeting.path))
    }

    @MainActor @Test func keepsMicWordsWhenCallTrackFails() async throws {
        let folder = try tempFolder()
        let recording = MeetingRecording(id: UUID(), title: "Call", startedAt: Date(), duration: 5, folder: folder)
        for url in [recording.micURL, recording.systemURL] { FileManager.default.createFile(atPath: url.path, contents: Data()) }
        let meeting = try await MeetingProcessor(diarizer: NoDiarizer(), transcriber: MicOnly())
            .process(recording, profiles: VoiceProfileStore(directory: folder))
        #expect(meeting.transcript.plainText == "You: hello")
        #expect(meeting.recording.callAudioError?.contains("call track unreadable") == true)
    }
}
