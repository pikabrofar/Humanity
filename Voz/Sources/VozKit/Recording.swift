import Foundation

/// One dictation or voice note. Stored as JSON next to its audio file.
public struct Recording: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Spoken into another app with the hotkey; the text was pasted there.
        case dictation
        /// Recorded inside Voz to keep, summarize, and export.
        case note
    }

    public var id: UUID
    public var createdAt: Date
    public var duration: TimeInterval
    public var kind: Kind
    /// Exactly what the recognizer produced.
    public var transcript: String
    /// After filler removal and punctuation fixes; nil when cleanup was off.
    public var cleaned: String?
    public var summary: String?
    public var actionItems: [String]
    /// The app that received the dictation, e.g. "Notes".
    public var targetApp: String?

    public init(id: UUID = UUID(), createdAt: Date = Date(), duration: TimeInterval, kind: Kind,
                transcript: String, cleaned: String? = nil, summary: String? = nil,
                actionItems: [String] = [], targetApp: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.kind = kind
        self.transcript = transcript
        self.cleaned = cleaned
        self.summary = summary
        self.actionItems = actionItems
        self.targetApp = targetApp
    }

    /// The best version of the text: cleaned when available.
    public var text: String { cleaned ?? transcript }

    /// The first few words, so lists don't need a separate title field.
    public var title: String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return "Empty recording" }
        let head = words.prefix(7).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        return words.count > 7 ? head + "…" : head
    }

    /// Case- and diacritic-insensitive search across every text field.
    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let fields = [transcript, cleaned, summary, targetApp].compactMap { $0 } + actionItems
        return fields.contains { $0.localizedStandardContains(query) }
    }
}

public enum Transcript {
    /// Joins recognizer segments, adding a space only where neither side
    /// already has one and the next segment doesn't start with punctuation.
    public static func join(_ a: String, _ b: String) -> String {
        guard let last = a.last, let first = b.first else { return a + b }
        if last.isWhitespace || first.isWhitespace || ",.!?;:".contains(first) { return a + b }
        return a + " " + b
    }

    /// "1:05" for 65 seconds.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
