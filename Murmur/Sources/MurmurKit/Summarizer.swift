import Foundation
import NaturalLanguage

public struct Summary: Equatable, Sendable {
    public var text: String
    public var actionItems: [String]

    public init(text: String, actionItems: [String]) {
        self.text = text
        self.actionItems = actionItems
    }
}

/// The model-independent half of summarizing: the reply format, its parser,
/// chunking for small context windows, and an extractive fallback.
public enum Summarizer {
    /// Plain-text format instead of guided generation: `@Generable` needs a
    /// macro plugin that the Command Line Tools don't ship.
    public static let format = """
        Reply in exactly this format:
        SUMMARY: <two or three sentences>
        ACTION ITEMS:
        - <one task per line, or "- None">
        """

    public static func parse(_ reply: String) -> Summary {
        var summary: [String] = []
        var items: [String] = []
        var inItems = false
        for raw in reply.components(separatedBy: .newlines) {
            let line = raw.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            let upper = line.uppercased()
            if upper.hasPrefix("SUMMARY") {
                inItems = false
                summary.append(afterColon(line))
            } else if upper.hasPrefix("ACTION ITEMS") {
                inItems = true
                items.append(afterColon(line))
            } else if inItems {
                items.append(TextCleanup.replace("^(?:[-*•]|\\d+[.)])?\\s*(?:\\[[ xX]?\\]\\s*)?", in: line, with: ""))
            } else {
                summary.append(line)
            }
        }
        let none: Set = ["none", "none.", "n/a"]
        return Summary(
            text: summary.filter { !$0.isEmpty }.joined(separator: " "),
            actionItems: items.filter { !$0.isEmpty && !none.contains($0.lowercased()) }
        )
    }

    /// Used without Apple Intelligence: the opening sentences, plus every
    /// sentence that sounds like a commitment.
    public static func extractive(_ text: String) -> Summary {
        let all = sentences(text)
        let cue = try! NSRegularExpression(
            pattern: "\\b(need(s)? to|have to|has to|got to|gotta|remember to|don't forget|make sure|follow up|to-?do|action item|let's|I'll|we'll)\\b",
            options: [.caseInsensitive]
        )
        let items = all.filter { cue.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
        return Summary(text: all.prefix(2).joined(separator: " "), actionItems: Array(items.prefix(10)))
    }

    /// Splits long text at sentence boundaries into pieces of at most
    /// `maxCharacters` (a single longer sentence stays whole).
    public static func chunks(_ text: String, maxCharacters: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for sentence in sentences(text) {
            if !current.isEmpty, current.count + sentence.count + 1 > maxCharacters {
                chunks.append(current)
                current = ""
            }
            current = current.isEmpty ? sentence : current + " " + sentence
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    public static func sentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func afterColon(_ line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }
}
