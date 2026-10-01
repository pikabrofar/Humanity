import Foundation

/// One recognized word with its position in the track, in seconds from meeting start.
public struct TimedWord: Codable, Hashable, Sendable {
    public var text: String
    public var start: Double
    public var end: Double

    public init(text: String, start: Double, end: Double) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// A stretch of the system-audio track that diarization attributed to one cluster.
public struct SpeakerSegment: Codable, Hashable, Sendable {
    public var start: Double
    public var end: Double
    /// Cluster ID from diarization, e.g. "S1". Only meaningful within one meeting.
    public var speaker: String

    public init(start: Double, end: Double, speaker: String) {
        self.start = start
        self.end = end
        self.speaker = speaker
    }
}

/// Who spoke when on the system track, plus one voice embedding per cluster.
public struct Diarization: Codable, Hashable, Sendable {
    public var segments: [SpeakerSegment]
    /// Mean speaker embedding per cluster ID. FluidAudio's offline pipeline gives every
    /// segment its cluster's centroid, so storing it once per cluster loses nothing.
    public var centroids: [String: [Float]]

    public init(segments: [SpeakerSegment], centroids: [String: [Float]]) {
        self.segments = segments
        self.centroids = centroids
    }
}

/// One uninterrupted stretch of speech by one person.
public struct TranscriptTurn: Codable, Hashable, Sendable, Identifiable {
    /// Cluster ID ("S1"…) or `TranscriptAligner.localSpeakerID` for the microphone.
    public var speakerID: String
    public var speakerName: String
    public var start: Double
    public var end: Double
    public var text: String

    public var id: String { "\(speakerID)@\(start)" }

    public init(speakerID: String, speakerName: String, start: Double, end: Double, text: String) {
        self.speakerID = speakerID
        self.speakerName = speakerName
        self.start = start
        self.end = end
        self.text = text
    }
}

public struct MeetingTranscript: Codable, Hashable, Sendable {
    public var turns: [TranscriptTurn]

    public init(turns: [TranscriptTurn]) {
        self.turns = turns
    }

    /// `**Alice** [00:01:23]: …`, one paragraph per turn.
    public func markdown(title: String? = nil) -> String {
        var lines = title.map { ["# \($0)", ""] } ?? []
        for turn in turns {
            lines.append("**\(turn.speakerName)** [\(Self.timestamp(turn.start))]: \(turn.text)")
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// `Speaker: text` lines, the compact form AIKit summarizes.
    public var plainText: String {
        turns.map { "\($0.speakerName): \($0.text)" }.joined(separator: "\n")
    }

    /// Always HH:MM:SS so columns line up and long meetings don't change the format midway.
    public static func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }
}
