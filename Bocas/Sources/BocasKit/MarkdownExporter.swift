import Foundation

public enum MarkdownExporter {
    public static func markdown(for r: Recording, timeZone: TimeZone = .current) -> String {
        var md = "# \(r.title)\n\n"
        md += "_\(dateString(r.createdAt, timeZone)) · \(Transcript.clock(r.duration)) · \(r.kind == .note ? "Note" : "Dictation")"
        if let app = r.targetApp { md += " · \(app)" }
        md += "_\n"
        if let summary = r.summary, !summary.isEmpty {
            md += "\n## Summary\n\n\(summary)\n"
        }
        if !r.actionItems.isEmpty {
            md += "\n## Action items\n\n" + r.actionItems.map { "- [ ] \($0)\n" }.joined()
        }
        md += "\n## Transcript\n\n\(r.text)\n"
        if let cleaned = r.cleaned, cleaned != r.transcript {
            md += "\n<details><summary>Raw transcript</summary>\n\n\(r.transcript)\n\n</details>\n"
        }
        return md
    }

    /// "2026-09-30 Buy milk and eggs.md", safe for any file system.
    public static func fileName(for r: Recording, timeZone: TimeZone = .current) -> String {
        let day = String(dateString(r.createdAt, timeZone).prefix(10))
        let title = r.title.replacingOccurrences(of: "…", with: "")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
        return "\(day) \(title.prefix(60)).md"
    }

    private static func dateString(_ date: Date, _ timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}
