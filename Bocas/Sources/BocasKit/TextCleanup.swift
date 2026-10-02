import Foundation

/// Deterministic dictation cleanup. Used when Apple Intelligence is off or
/// unavailable, so it only does what is safe without understanding meaning.
public enum TextCleanup {
    /// Sounds that are never real words in dictation. "Like" and "so" are left
    /// alone on purpose: removing them without context changes meaning.
    static let fillers = "um+|uh+|uhm|erm|er|ah+|hmm+|mm+|mhm"

    public static func basic(_ input: String, language: String? = "en") -> String {
        var s = input
        let english = language.map { $0.hasPrefix("en") } ?? true
        if english {
            // Not inside "mm-hmm"/"uh-huh", not an acronym ("ER", "UM"), not a unit ("5 mm").
            let filler = "(?<![\\w-])(?!(?-i:[A-Z]{2}))(?<!\\d\\s)(?:\(fillers))(?![\\w-])"
            // A filler that is a whole sentence goes with its punctuation: "Okay. Um. Go." → "Okay. Go."
            s = replace("(?:^|(?<=[.!?]))\\s*\(filler)[.!?,]*(?=\\s|$)", in: s, with: "")
            s = replace(",?\\s*\(filler),?", in: s, with: "")
            // Only as a discourse marker: "If you know, tell me" keeps its words.
            s = replace("(?:,|^|(?<=[.!?]))\\s*\\b(?:you know|I mean),\\s*", in: s, with: " ")
            // Stutters: "the the" → "the". Letters only: "7 7 3 9" is a number. English only:
            // French "nous nous" and German "die die" are grammatical.
            s = replace("\\b(?!(?:had|that)\\b)([^\\W\\d_]+)(?:\\s+\\1\\b)+", in: s, with: "$1")
        }
        s = replace("\\s+([,.!?;:])", in: s, with: "$1")
        s = replace("([,;:])(?:\\s*[,;:])+", in: s, with: "$1")
        s = replace("[ \\t]{2,}", in: s, with: " ")
        s = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        if english { s = replace("(?<![\\w'’])i(?=[\\s,!?;:'’]|\\.(?!\\w)|$)", in: s, with: "I", caseInsensitive: false) }
        s = capitalizeSentences(s)
        // No period after an address ("sam@gmail.com", "apple.com"); "。" after Chinese or
        // Japanese; none in Thai, Lao, Khmer or Burmese, which don't end sentences with one.
        let lastWord = s.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        if let last = s.last, last.isLetter || last.isNumber, !isSpacelessSEA(last),
           lastWord.range(of: "[.@]\\p{L}", options: .regularExpression) == nil { s += isCJK(last) ? "。" : "." }
        return s
    }

    /// Validates a language model's rewrite. Models sometimes add a preamble,
    /// wrap the answer in quotes, or reply to the text instead of editing it.
    /// Returns nil when the output doesn't look like an edit, so callers fall back.
    public static func acceptRewrite(_ output: String, of original: String) -> String? {
        var t = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```"), t.hasSuffix("```"), t.count > 6 { // a code fence, maybe with a language tag
            var body = t.dropFirst(3).dropLast(3)
            if let nl = body.firstIndex(where: \.isNewline), !body[..<nl].contains(" ") { body = body[nl...] }
            t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var lines = t.components(separatedBy: .newlines)
        if lines.count > 1, let first = lines.first, first.hasSuffix(":") {
            lines.removeFirst()
            t = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for (open, close) in [("\"", "\""), ("“", "”")] where t.count > 1 && t.hasPrefix(open) && t.hasSuffix(close)
            && !original.hasPrefix(open) {
            t = String(t.dropFirst().dropLast())
        }
        // "Sure, here's the edited text: …" on the same line, unless the speaker began that way.
        if let r = t.range(of: "^(?:(?:sure|okay|ok|certainly)[,!.]?\\s*)?here(?:['’]s| is) (?:the|your) [^:\\n]{0,40}:\\s*",
                           options: [.regularExpression, .caseInsensitive]),
           !words(original).starts(with: words(String(t[r]))) {
            t.removeSubrange(r)
        }
        guard !t.isEmpty else { return nil }
        // Fillers can account for much of a short utterance, so the lower bound is loose.
        let n = Double(original.count)
        guard Double(t.count) >= n * 0.25, Double(t.count) <= n * 1.5 + 12 else { return nil }
        // An edit reuses the speaker's words. Answers ("Four."), translations, refusals and
        // preambles bring new ones. Allow about one new word in five ("three" → "3").
        let spoken = Set(words(original)), edited = words(t)
        guard !edited.isEmpty, edited.filter({ !spoken.contains($0) }).count <= (edited.count + 2) / 5 else { return nil }
        // A question stays a question; a missing "?" usually means the model answered it.
        func asks(_ s: String) -> Bool { s.contains { $0 == "?" || $0 == "？" } }
        if asks(original), !asks(t) { return nil }
        return t
    }

    /// Lowercased words without apostrophes, so "I'm" and "im" match. Scripts written
    /// without spaces (Chinese, Japanese, Thai…) count each character as a word.
    static func words(_ s: String) -> [String] {
        var out: [String] = [], word = ""
        for ch in s.lowercased() where ch != "'" && ch != "’" {
            if isCJK(ch) || isSpacelessSEA(ch) {
                if !word.isEmpty { out.append(word); word = "" }
                out.append(String(ch))
            } else if ch.isLetter || ch.isNumber {
                word.append(ch)
            } else if !word.isEmpty {
                out.append(word)
                word = ""
            }
        }
        if !word.isEmpty { out.append(word) }
        return out
    }

    /// Han ideographs and kana.
    static func isCJK(_ ch: Character) -> Bool {
        ch.unicodeScalars.contains { u in
            [0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F].contains { $0.contains(u.value) }
        }
    }

    /// Thai, Lao, Myanmar and Khmer, which also have no spaces between words.
    static func isSpacelessSEA(_ ch: Character) -> Bool {
        ch.unicodeScalars.contains { u in [0x0E00...0x0EFF, 0x1000...0x109F, 0x1780...0x17FF].contains { $0.contains(u.value) } }
    }

    /// A model must not add line breaks: pasted into a terminal, a newline can run the
    /// first line. When the dictation had none, every run of them becomes one space.
    public static func keepLineBreaks(of original: String, in rewrite: String) -> String {
        guard !original.contains(where: \.isNewline), rewrite.contains(where: \.isNewline) else { return rewrite }
        return rewrite.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The user's custom words, one per comma or line, without duplicates.
    public static func terms(from list: String) -> [String] {
        var seen = Set<String>()
        return list.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    /// Spells custom words the way the user wrote them, ignoring case and the
    /// spaces recognizers put inside compounds: "swift ui" → "SwiftUI", "gpt 4" → "GPT4".
    public static func respell(_ text: String, terms: [String]) -> String {
        terms.reduce(text) { text, term in
            var pattern = ""
            var previous: Character?
            for ch in term {
                if ch.isWhitespace || ch == "-" {
                    pattern += "[\\s-]?"
                    previous = nil
                    continue
                }
                if let p = previous, (p.isLowercase && ch.isUppercase) || (p.isLetter && ch.isNumber) || (p.isNumber && ch.isLetter) {
                    pattern += "[\\s-]?"
                }
                pattern += NSRegularExpression.escapedPattern(for: String(ch))
                previous = ch
            }
            guard let regex = try? NSRegularExpression(pattern: "(?<!\\w)\(pattern)(?!\\w)", options: .caseInsensitive) else { return text }
            return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text),
                                                  withTemplate: NSRegularExpression.escapedTemplate(for: term))
        }
    }

    static let abbreviations: Set = ["e.g", "i.e", "etc", "vs", "approx", "a.m", "p.m", "cf", "incl"]

    /// Capitalizes after ".!?" only when whitespace follows, so "apple.com", "i.e." and "a.m." stay.
    static func capitalizeSentences(_ s: String) -> String {
        var out = "", word = ""
        var capitalizeNext = true
        for ch in s {
            if ch.isWhitespace {
                let core = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’)"))
                if let end = core.last, ".!?".contains(end), !abbreviations.contains(core.dropLast().lowercased()) {
                    capitalizeNext = true
                }
                word = ""
                out.append(ch)
                continue
            }
            word.append(ch)
            if capitalizeNext, ch.isLetter {
                out += ch.uppercased()
                capitalizeNext = false
                continue
            }
            if !"\"'“(".contains(ch) { capitalizeNext = false } // e.g. the "3" in "3 people"
            out.append(ch)
        }
        return out
    }

    static func replace(_ pattern: String, in s: String, with template: String, caseInsensitive: Bool = true) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
        return regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
