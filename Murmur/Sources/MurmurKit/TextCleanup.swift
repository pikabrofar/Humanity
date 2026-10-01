import Foundation

/// Deterministic dictation cleanup. Used when Apple Intelligence is off or
/// unavailable, so it only does what is safe without understanding meaning.
public enum TextCleanup {
    /// Sounds that are never real words in dictation. "Like" and "so" are left
    /// alone on purpose: removing them without context changes meaning.
    static let fillers = "um+|uh+|uhm|erm|er|ah+|hmm+|mm+|mhm"

    public static func basic(_ input: String) -> String {
        var s = input
        // A filler together with the commas around it: "I think, um, we" → "I think we".
        s = replace(",?\\s*\\b(?:\(fillers))\\b,?", in: s, with: "")
        s = replace("\\b(?:you know|I mean),\\s*", in: s, with: "")
        // Stutters: "the the" → "the".
        s = replace("\\b(\\w+)(?:\\s+\\1\\b)+", in: s, with: "$1")
        s = replace("\\s+([,.!?;:])", in: s, with: "$1")
        s = replace("([,;:])(?:\\s*[,;:])+", in: s, with: "$1")
        s = replace("[ \\t]{2,}", in: s, with: " ")
        s = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        s = replace("(?<![\\w'])i(?=[\\s,.!?;:']|$)", in: s, with: "I", caseInsensitive: false)
        s = capitalizeSentences(s)
        if let last = s.last, last.isLetter || last.isNumber { s += "." }
        return s
    }

    /// Validates a language model's rewrite. Models sometimes add a preamble,
    /// wrap the answer in quotes, or reply to the text instead of editing it.
    /// Returns nil when the output doesn't look like an edit, so callers fall back.
    public static func acceptRewrite(_ output: String, of original: String) -> String? {
        var t = output.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = t.components(separatedBy: .newlines)
        if lines.count > 1, let first = lines.first, first.hasSuffix(":") {
            lines.removeFirst()
            t = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("\"", "\""), ("“", "”")] where t.count > 1 && t.hasPrefix(open) && t.hasSuffix(close)
            && !original.hasPrefix(open) {
            t = String(t.dropFirst().dropLast())
        }
        guard !t.isEmpty else { return nil }
        // Fillers can account for much of a short utterance, so the lower bound is loose.
        let n = Double(original.count)
        guard Double(t.count) >= n * 0.25, Double(t.count) <= n * 1.5 + 12 else { return nil }
        return t
    }

    static func capitalizeSentences(_ s: String) -> String {
        var out = ""
        var capitalizeNext = true
        for ch in s {
            if capitalizeNext, ch.isLetter {
                out += ch.uppercased()
                capitalizeNext = false
                continue
            }
            out.append(ch)
            if ".!?".contains(ch) {
                capitalizeNext = true
            } else if !ch.isWhitespace, !"\"'“(".contains(ch) {
                capitalizeNext = false // e.g. the "5" in "3.5"
            }
        }
        return out
    }

    static func replace(_ pattern: String, in s: String, with template: String, caseInsensitive: Bool = true) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
        return regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
