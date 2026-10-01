import Foundation

/// Merges the two transcribed tracks and the diarization into speaker turns.
public enum TranscriptAligner {
    /// Speaker ID of the microphone track. Its attribution is exact: it's a separate device.
    public static let localSpeakerID = "you"
    /// System-track words when diarization found no segments at all (e.g. a silent tap).
    public static let remoteSpeakerID = "remote"

    /// The diarization cluster a system-track word belongs to: the segment overlapping
    /// it the most, or, for words that fall in a gap (recognizer and segmenter disagree
    /// on boundaries by a few hundred ms), the nearest segment.
    static func speaker(for word: TimedWord, in segments: [SpeakerSegment]) -> String? {
        let mid = (word.start + word.end) / 2
        func overlap(_ s: SpeakerSegment) -> Double { min(s.end, word.end) - max(s.start, word.start) }
        func distance(_ s: SpeakerSegment) -> Double { mid < s.start ? s.start - mid : max(0, mid - s.end) }
        // Overlapping speech gives several candidates; the larger overlap wins, then the
        // segment that contains the word's midpoint.
        let best = segments.max { a, b in
            let (oa, ob) = (overlap(a), overlap(b))
            if oa != ob, max(oa, ob) > 0 { return oa < ob }
            return distance(a) > distance(b)
        }
        return best?.speaker
    }

    /// - Parameters:
    ///   - names: Display name per cluster ID; unknown clusters keep their ID.
    ///   - maxGap: A pause longer than this starts a new turn even for the same speaker.
    public static func align(micWords: [TimedWord],
                             systemWords: [TimedWord],
                             segments: [SpeakerSegment],
                             names: [String: String],
                             localName: String = "You",
                             maxGap: Double = 2) -> MeetingTranscript {
        let mic = dropEchoes(micWords, heardIn: systemWords)
            .map { (speaker: localSpeakerID, word: $0) }
        let remote = systemWords.map { (speaker: speaker(for: $0, in: segments) ?? remoteSpeakerID, word: $0) }

        // Build utterances per track before interleaving: if both sides talk at once,
        // that yields two whole turns ordered by start, not an alternating word salad.
        let utterances = (group(mic, maxGap: maxGap) + group(remote, maxGap: maxGap))
            .sorted { $0.start < $1.start }
        let turns = utterances.map { u in
            let name = u.speakerID == localSpeakerID ? localName
                : names[u.speakerID] ?? (u.speakerID == remoteSpeakerID ? "Remote" : u.speakerID)
            return TranscriptTurn(speakerID: u.speakerID, speakerName: name, start: u.start, end: u.end, text: u.text)
        }
        return MeetingTranscript(turns: turns)
    }

    private static func group(_ words: [(speaker: String, word: TimedWord)], maxGap: Double) -> [TranscriptTurn] {
        var turns: [TranscriptTurn] = []
        for (speaker, word) in words.sorted(by: { $0.word.start < $1.word.start }) {
            if var last = turns.last, last.speakerID == speaker, word.start - last.end <= maxGap {
                last.text += " " + word.text
                last.end = max(last.end, word.end)
                turns[turns.count - 1] = last
            } else {
                turns.append(TranscriptTurn(speakerID: speaker, speakerName: speaker,
                                            start: word.start, end: word.end, text: word.text))
            }
        }
        return turns
    }

    /// Without headphones the mic also hears the remote side through the speakers, so the
    /// same words show up on both tracks. A mic word matching a system word within half a
    /// second is that echo; the system track is the cleaner copy, so keep that one.
    static func dropEchoes(_ mic: [TimedWord], heardIn system: [TimedWord], window: Double = 0.5) -> [TimedWord] {
        func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        // Keyed by text so an hour-long meeting compares each word with a handful, not thousands.
        let heard = Dictionary(grouping: system, by: { norm($0.text) })
        return mic.filter { word in
            let text = norm(word.text)
            return text.isEmpty || !(heard[text] ?? []).contains { abs($0.start - word.start) <= window }
        }
    }
}
