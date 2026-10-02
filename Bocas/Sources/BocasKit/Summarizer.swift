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

    /// Reads `format`, and the variations models drift into: Markdown headings
    /// ("## Summary"), "Action item:", "Next steps:", numbered or checkbox items.
    public static func parse(_ reply: String) -> Summary {
        var summary: [String] = []
        var items: [String] = []
        var inItems = false
        for raw in reply.components(separatedBy: .newlines) {
            let line = raw.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            if let (isItems, rest) = heading(line) {
                inItems = isItems
                if isItems { items.append(item(rest)) } else { summary.append(rest) }
            } else if inItems {
                items.append(item(line))
            } else {
                summary.append(line)
            }
        }
        return Summary(
            text: summary.filter { !$0.isEmpty }.joined(separator: " "),
            actionItems: items.filter { !$0.isEmpty && !isNone($0) }
        )
    }

    /// A section label, and the text after its colon: (true, …) for action items.
    private static func heading(_ line: String) -> (Bool, String)? {
        let s = TextCleanup.replace("^#{1,6}\\s*", in: line, with: "")
        guard let label = s.range(of: "^(?:summary|action items?|next steps|to-?dos?|tasks)\\s*(?::|$)",
                                  options: [.regularExpression, .caseInsensitive]) else { return nil }
        let rest = s[label.upperBound...].trimmingCharacters(in: .whitespaces)
        return (!s[label].lowercased().hasPrefix("summary"), rest)
    }

    private static func item(_ line: String) -> String {
        TextCleanup.replace("^(?:[-*•]|\\d+[.)])?\\s*(?:\\[[ xX]?\\]\\s*)?", in: line, with: "")
    }

    /// "None", "N/A", "No action items were mentioned." and the like.
    static func isNone(_ item: String) -> Bool {
        let none = "^(?:none(?: (?:mentioned|identified|noted|found|discussed))?|n/?a|nothing(?: to do)?"
            + "|(?:there (?:are|were|is) )?no (?:clear |specific |explicit )?(?:action items?|tasks?|next steps|to-?dos?)\\b.*)[.!]?$"
        return item.range(of: none, options: [.regularExpression, .caseInsensitive]) != nil
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
}
