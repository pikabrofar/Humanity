import Foundation
import Testing
@testable import VozKit

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
