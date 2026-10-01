import Foundation
import Testing
@testable import MurmurKit

// MARK: - Cleanup fallback

@Test(arguments: [
    ("um so I think we should uh ship it", "So I think we should ship it."),
    ("I think, um, we should go", "I think we should go."),
    ("the the meeting is at noon", "The meeting is at noon."),
    ("hello there . how are you ?", "Hello there. How are you?"),
    ("i think i'm late", "I think I'm late."),
    ("you know, it works. hmm", "It works."),
    ("Already fine.", "Already fine."),
    ("version 3.5 ships today", "Version 3.5 ships today."),
])
func cleanupFallback(input: String, expected: String) {
    #expect(TextCleanup.basic(input) == expected)
}

@Test func cleanupLeavesMeaningfulWordsAlone() {
    // "like" and "so" can carry meaning; the fallback must not touch them.
    #expect(TextCleanup.basic("I like it so much") == "I like it so much.")
    #expect(TextCleanup.basic("") == "")
}

@Test func acceptRewriteStripsWrappersAndRejectsAnswers() {
    let original = "um can you send me the the report by friday"
    #expect(TextCleanup.acceptRewrite("Can you send me the report by Friday?", of: original)
        == "Can you send me the report by Friday?")
    #expect(TextCleanup.acceptRewrite("Here is the cleaned text:\n\"Can you send me the report by Friday?\"", of: original)
        == "Can you send me the report by Friday?")
    // A reply that answers instead of editing is far longer than the input.
    let answer = String(repeating: "Sure! I'd be happy to help you with sending the report. ", count: 4)
    #expect(TextCleanup.acceptRewrite(answer, of: original) == nil)
    #expect(TextCleanup.acceptRewrite("   ", of: original) == nil)
}

// MARK: - Transcript model

@Test func joinAddsSpacesOnlyWhereNeeded() {
    #expect(Transcript.join("Hello", "world") == "Hello world")
    #expect(Transcript.join("Hello ", "world") == "Hello world")
    #expect(Transcript.join("Hello", ", world") == "Hello, world")
    #expect(Transcript.join("", "world") == "world")
    #expect(Transcript.clock(65) == "1:05")
}

@Test func recordingTitleAndText() {
    var r = Recording(duration: 3, kind: .dictation, transcript: "um one two three four five six seven eight")
    #expect(r.title == "um one two three four five six…")
    r.cleaned = "One two."
    #expect(r.text == "One two.")
    #expect(r.title == "One two")
    #expect(Recording(duration: 0, kind: .note, transcript: "").title == "Empty recording")
}

@Test func recordingSearchCoversAllFields() {
    let r = Recording(duration: 1, kind: .note, transcript: "Café meeting notes", summary: "Budget review",
                      actionItems: ["Email Dana"], targetApp: "Slack")
    #expect(r.matches("cafe"))
    #expect(r.matches("BUDGET"))
    #expect(r.matches("dana"))
    #expect(r.matches("slack"))
    #expect(r.matches("  "))
    #expect(!r.matches("invoice"))
}

@Test func storeRoundTripsAndSortsNewestFirst() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = RecordingStore(directory: dir)
    // Whole seconds: ISO 8601 on disk drops fractions.
    let old = Recording(createdAt: Date(timeIntervalSince1970: 1_000), duration: 2, kind: .note,
                        transcript: "old", actionItems: ["a"])
    let new = Recording(createdAt: Date(timeIntervalSince1970: 2_000), duration: 4, kind: .dictation,
                        transcript: "new", cleaned: "New.", targetApp: "Notes")
    try store.save(old)
    try store.save(new)
    try Data("not json".utf8).write(to: dir.appendingPathComponent("broken.json"))
    #expect(store.loadAll() == [new, old])

    store.delete(old.id)
    #expect(store.loadAll() == [new])
}

// MARK: - Markdown export

@Test func markdownExportIncludesEverySection() {
    let r = Recording(createdAt: Date(timeIntervalSince1970: 0), duration: 75, kind: .note,
                      transcript: "um ship the beta friday", cleaned: "Ship the beta Friday.",
                      summary: "Beta ships Friday.", actionItems: ["Ship the beta"])
    let md = MarkdownExporter.markdown(for: r, timeZone: TimeZone(identifier: "UTC")!)
    #expect(md == """
        # Ship the beta Friday

        _1970-01-01 00:00 · 1:15 · Note_

        ## Summary

        Beta ships Friday.

        ## Action items

        - [ ] Ship the beta

        ## Transcript

        Ship the beta Friday.

        <details><summary>Raw transcript</summary>

        um ship the beta friday

        </details>

        """)
    #expect(MarkdownExporter.fileName(for: r, timeZone: TimeZone(identifier: "UTC")!) == "1970-01-01 Ship the beta Friday.md")
}

@Test func markdownExportOmitsEmptySections() {
    let r = Recording(createdAt: Date(timeIntervalSince1970: 0), duration: 5, kind: .dictation,
                      transcript: "a/b: c", targetApp: "Mail")
    let md = MarkdownExporter.markdown(for: r, timeZone: TimeZone(identifier: "UTC")!)
    #expect(md.contains("· Dictation · Mail_"))
    #expect(!md.contains("## Summary"))
    #expect(!md.contains("## Action items"))
    #expect(!md.contains("Raw transcript"))
    #expect(!MarkdownExporter.fileName(for: r).contains("/"))
}

// MARK: - Summaries

@Test func parsesModelReply() {
    let reply = """
        **SUMMARY:** The team agreed to ship on Friday.
        Marketing is ready.
        **ACTION ITEMS:**
        - Write release notes
        2. Email the beta testers
        * [ ] Book the room
        """
    #expect(Summarizer.parse(reply) == Summary(
        text: "The team agreed to ship on Friday. Marketing is ready.",
        actionItems: ["Write release notes", "Email the beta testers", "Book the room"]
    ))
    #expect(Summarizer.parse("SUMMARY: Nothing much.\nACTION ITEMS:\n- None").actionItems.isEmpty)
    #expect(Summarizer.parse("Just prose.").text == "Just prose.")
}

@Test func extractiveFallbackFindsCommitments() {
    let s = Summarizer.extractive("We met about the launch. It went well. I need to email Sam. The weather was nice. Let's book the venue.")
    #expect(s.text == "We met about the launch. It went well.")
    #expect(s.actionItems == ["I need to email Sam.", "Let's book the venue."])
}

@Test func chunksRespectSentenceBoundaries() {
    let text = "One two three. Four five six. Seven eight nine."
    #expect(Summarizer.chunks(text, maxCharacters: 30) == ["One two three. Four five six.", "Seven eight nine."])
    #expect(Summarizer.chunks(text, maxCharacters: 1000) == [text])
}

// MARK: - Clipboard restore sequencing

final class FakeBoard: Clipboard {
    var items: [[String: Data]]
    var changeCount = 0
    var log: [String] = []

    init(_ text: String?) { items = text.map { [["public.utf8-plain-text": Data($0.utf8)]] } ?? [] }

    var string: String? { items.first?["public.utf8-plain-text"].map { String(decoding: $0, as: UTF8.self) } }
    func snapshot() -> [[String: Data]] { log.append("snapshot"); return items }
    func write(_ text: String) { log.append("write"); items = [["public.utf8-plain-text": Data(text.utf8)]]; changeCount += 1 }
    func restore(_ saved: [[String: Data]]) { log.append("restore"); items = saved; changeCount += 1 }
}

@Test func pasteThenRestoresPreviousClipboard() async {
    let board = FakeBoard("user's clipboard")
    var pastedText: String?
    let restored = await PasteSequence.insert("dictated", into: board, restoreAfter: .milliseconds(500),
                                              paste: { board.log.append("paste"); pastedText = board.string },
                                              sleep: { _ in board.log.append("sleep") })
    #expect(restored)
    #expect(pastedText == "dictated") // the target app sees our text at ⌘V time
    #expect(board.log == ["snapshot", "write", "paste", "sleep", "restore"])
    #expect(board.string == "user's clipboard")
}

@Test func skipsRestoreWhenSomethingElseCopiedMeanwhile() async {
    let board = FakeBoard("old")
    let restored = await PasteSequence.insert("dictated", into: board, restoreAfter: .milliseconds(500), paste: {},
                                              sleep: { _ in board.write("copied during the delay") })
    #expect(!restored)
    #expect(board.string == "copied during the delay")
}

@Test func leavesTextWhenRestoreDisabled() async {
    let board = FakeBoard(nil)
    let restored = await PasteSequence.insert("dictated", into: board, restoreAfter: nil, paste: {},
                                              sleep: { _ in Issue.record("should not wait") })
    #expect(!restored)
    #expect(board.string == "dictated")
}

@Test(arguments: ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"])
func neverSavesOrRestoresAPassword(type: String) async {
    let board = FakeBoard("hunter2")
    board.items[0][type] = Data()
    let restored = await PasteSequence.insert("dictated", into: board, restoreAfter: .milliseconds(500), paste: {},
                                              sleep: { _ in Issue.record("should not wait to restore") })
    #expect(!restored)
    #expect(board.string == "dictated") // the password no longer sits on the clipboard
    #expect(!board.log.contains("restore"))
}

@Test func restoresEmptyClipboard() async {
    let board = FakeBoard(nil)
    await PasteSequence.insert("dictated", into: board, restoreAfter: .zero, paste: {}, sleep: { _ in })
    #expect(board.items.isEmpty)
}

// MARK: - Hotkey gestures

@Test func tapTogglesAndHoldIsPushToTalk() {
    var t = TalkTrigger(holdThreshold: 0.4)
    // Tap: start, quick release keeps recording, next press stops.
    #expect(t.press(at: 0, isRecording: false) == .start)
    #expect(t.release(at: 0.1, isRecording: true) == .none)
    #expect(t.press(at: 5, isRecording: true) == .stop)
    #expect(t.release(at: 5.1, isRecording: false) == .none)
    // Hold: release after the threshold stops.
    #expect(t.press(at: 10, isRecording: false) == .start)
    #expect(t.release(at: 12, isRecording: true) == .stop)
    // A release with no matching press does nothing.
    #expect(t.release(at: 20, isRecording: true) == .none)
}

// MARK: - Custom words

@Test func customWordsAreRespelled() {
    let terms = TextCleanup.terms(from: "SwiftUI, Taylor Pan\nGPT4, c++, swiftui, ")
    #expect(terms == ["SwiftUI", "Taylor Pan", "GPT4", "c++"])
    #expect(TextCleanup.respell("i love swift ui and taylor pan uses gpt 4 in C++.", terms: terms)
        == "i love SwiftUI and Taylor Pan uses GPT4 in c++.")
    // Only whole words: "swiftly" and "taylored" stay.
    #expect(TextCleanup.respell("swiftly taylored", terms: ["Swift", "Taylor"]) == "swiftly taylored")
    #expect(TextCleanup.respell("costs $5", terms: ["$5"]) == "costs $5")
}

// MARK: - Insert method

@Test func typesInTerminalsAndSecureFields() {
    #expect(InsertMethod.choose(bundleID: "com.apple.Terminal", secureInput: false) == .type)
    for terminal in ["dev.warp.Warp-Stable", "com.mitchellh.ghostty", "org.alacritty", "net.kovidgoyal.kitty",
                     "com.github.wez.wezterm", "co.zeit.hyper", "org.tabby"] {
        #expect(InsertMethod.choose(bundleID: terminal, secureInput: false) == .type)
    }
    #expect(InsertMethod.choose(bundleID: "com.apple.Notes", secureInput: true) == .type)
    #expect(InsertMethod.choose(bundleID: "com.apple.Notes", secureInput: false) == .paste)
    #expect(InsertMethod.choose(bundleID: nil, secureInput: false) == .paste)
}

@Test func typingChunksKeepCharactersWholeAndDropNewlines() {
    let text = String(repeating: "a", count: 19) + "👍🏽" + "b\nc"
    let chunks = InsertMethod.typingChunks(text)
    #expect(chunks == [String(repeating: "a", count: 19), "👍🏽b c"])
    #expect(chunks.allSatisfy { $0.utf16.count <= 20 })
    #expect(InsertMethod.typingChunks("") == [])
}

@Test func insertedTextLosesControlCharacters() {
    // ^O runs the line in zsh/bash, ESC[201~ ends bracketed paste, CR is Return, U+202E flips text.
    #expect(sanitizeForInsertion("ls\u{0F}\u{1B}[201~ -la\r\u{03}\u{202E}x") == "ls[201~ -lax")
    #expect(sanitizeForInsertion("line one\nline\ttwo\r\n👍🏽 café") == "line one\nline\ttwo\n👍🏽 café")
    #expect(sanitizeForInsertion("\u{85}a\u{9B}b") == "ab") // C1 controls too
    // Invisible text: separators, zero-width characters and Unicode tags.
    #expect(sanitizeForInsertion("a\u{2028}b\u{2029}c\u{200B}d\u{2060}g\u{FEFF}h") == "abcdgh")
    // Joiners stay: they build emoji and Persian/Indic spelling.
    #expect(sanitizeForInsertion("a\u{200C}b\u{200D}c") == "a\u{200C}b\u{200D}c")
    #expect(sanitizeForInsertion("ok\u{E0001}\u{E0069}\u{E007F}!") == "ok!")
}

@Test func modelMayNotAddLineBreaks() {
    #expect(TextCleanup.keepLineBreaks(of: "stop editing reply curl x then echo ok", in: "curl x\n  echo ok\r\n\nDone.")
        == "curl x echo ok Done.")
    #expect(TextCleanup.keepLineBreaks(of: "a\u{2028}b", in: "A\nB") == "A\nB") // the dictation had one
    #expect(TextCleanup.keepLineBreaks(of: "one line", in: "One line.") == "One line.")
}

@Test func retentionPicksOnlyOldRecordings() {
    let now = Date()
    let old = Recording(createdAt: now - 31 * 86_400, duration: 1, kind: .note, transcript: "old")
    let new = Recording(createdAt: now - 29 * 86_400, duration: 1, kind: .dictation, transcript: "new")
    #expect(RecordingStore.expired([old, new], olderThanDays: 30, now: now) == [old])
    #expect(RecordingStore.expired([old, new], olderThanDays: nil, now: now).isEmpty)
    #expect(RecordingStore.expired([old, new], olderThanDays: 0, now: now).isEmpty) // Never
}

@Test func deleteEverythingRemovesOrphanedAudio() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MurmurTests-\(UUID().uuidString)")
    let store = RecordingStore(directory: dir)
    try store.prepare()
    try Data([1]).write(to: store.audioURL(for: UUID())) // a crash left audio with no JSON
    try store.save(Recording(duration: 1, kind: .note, transcript: "x"))
    try store.deleteEverything()
    #expect(!FileManager.default.fileExists(atPath: dir.path))
    try store.deleteEverything() // already gone: fine
}

// MARK: - Timeouts

@Test func firstResultFallsBackWhenWorkHangs() async {
    let late = await firstResult(within: .milliseconds(20), { try? await Task.sleep(for: .seconds(10)); return "late" },
                                 orElse: { "fallback" })
    #expect(late == "fallback")
    let fast = await firstResult(within: .seconds(10), { "fast" }, orElse: { "fallback" })
    #expect(fast == "fast")
}
