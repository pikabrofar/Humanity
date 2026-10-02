import Foundation

/// The parts of NSPasteboard the insert sequence needs. The app adapts
/// NSPasteboard to this; tests use a fake.
public protocol Clipboard {
    /// Increments on every write by anyone, like `NSPasteboard.changeCount`.
    var changeCount: Int { get }
    /// Every item, as type identifier → data.
    func snapshot() -> [[String: Data]]
    func write(_ text: String)
    func restore(_ items: [[String: Data]])
}

/// How dictated text reaches the target app.
public enum InsertMethod: Equatable, Sendable {
    /// ⌘V with the clipboard restored afterwards. Fast for any length.
    case paste
    /// Synthesized Unicode keystrokes. Leaves the clipboard alone; used where
    /// pasting is unreliable: terminals (paste warnings, no clipboard churn in
    /// shells) and secure fields, which may refuse paste.
    case type

    /// Typed into, so no pasted newline can run a command. VS Code's (and other editors')
    /// integrated terminals can't be told apart from the editor, so they aren't listed.
    static let terminals: Set = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "dev.warp.Warp-Preview",
        "com.mitchellh.ghostty", "org.alacritty", "io.alacritty", "net.kovidgoyal.kitty",
        "com.github.wez.wezterm", "co.zeit.hyper", "org.tabby",
    ]

    public static func choose(bundleID: String?, secureInput: Bool) -> InsertMethod {
        secureInput || bundleID.map(terminals.contains) == true ? .type : .paste
    }

    /// Splits text for `CGEventKeyboardSetUnicodeString`, which takes at most
    /// 20 UTF-16 units per event, without breaking a character apart. Newlines
    /// become spaces so a terminal never runs a half-dictated command.
    public static func typingChunks(_ text: String, maxUnits: Int = 20) -> [String] {
        var chunks: [String] = []
        var current = ""
        for ch in text {
            let ch: Character = ch.isNewline ? " " : ch
            if !current.isEmpty, current.utf16.count + ch.utf16.count > maxUnits {
                chunks.append(current)
                current = ""
            }
            current.append(ch)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

/// Removes characters a terminal or editor may act on rather than display: C0/C1 controls
/// (ESC, ^C, ^D, ^O, a bare CR…), bidi overrides, line/paragraph separators, zero-width
/// characters and Unicode tags (invisible text). Newline and tab stay.
public func sanitizeForInsertion(_ text: String) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.filter { u in
        if u == "\n" || u == "\t" { return true }
        if (0x202A...0x202E).contains(u.value) || (0x2066...0x2069).contains(u.value) { return false }
        if [0x2028, 0x2029, 0x200B, 0x2060, 0xFEFF].contains(u.value) || (0xE0000...0xE007F).contains(u.value) {
            return false
        }
        return u.properties.generalCategory != .control
    }))
}

public enum PasteSequence {
    /// Clipboard contents a password manager (or another app) marked as not to be kept:
    /// they're never saved and put back, so they don't outlive the manager's auto-clear.
    public static let sensitiveTypes: Set = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]

    public static func isSensitive(_ items: [[String: Data]]) -> Bool {
        items.contains { !sensitiveTypes.isDisjoint(with: $0.keys) }
    }

    /// Puts `text` on the pasteboard, triggers `paste`, then puts the user's
    /// previous clipboard back.
    ///
    /// The restore waits `restoreAfter` because the target app reads the
    /// pasteboard asynchronously after receiving ⌘V. It is skipped if anything
    /// else wrote to the pasteboard in the meantime, so a copy the user made
    /// during that window is never overwritten. Pass nil to leave the text there.
    /// A concealed or transient previous item (a copied password) is never saved or
    /// restored; the dictated text simply replaces it.
    ///
    /// - Returns: whether the previous clipboard was restored.
    @discardableResult
    public static func insert(
        _ text: String,
        into board: some Clipboard,
        restoreAfter delay: Duration?,
        paste: () -> Void,
        sleep: (Duration) async -> Void = { try? await Task.sleep(for: $0) }
    ) async -> Bool {
        let saved = board.snapshot()
        board.write(text)
        let ours = board.changeCount
        paste()
        guard let delay, !isSensitive(saved) else { return false }
        await sleep(delay)
        guard board.changeCount == ours else { return false }
        board.restore(saved)
        return true
    }
}

/// `PasteSequence.insert` for an app that pastes more than once: one instance per app.
/// A dictation that lands while the previous one's restore is pending puts back the
/// user's clipboard, not the previous dictation (which is marked transient, so a fresh
/// snapshot of it would never be restored, and the user's clipboard would be lost).
@MainActor
public final class PasteRestorer {
    private var pending: (saved: [[String: Data]], ours: Int)?
    private var generation = 0

    public init() {}

    /// Same contract as `PasteSequence.insert`.
    @discardableResult
    public func insert(_ text: String, into board: some Clipboard, restoreAfter delay: Duration?,
                       paste: () -> Void,
                       sleep: (Duration) async -> Void = { try? await Task.sleep(for: $0) }) async -> Bool {
        // Our previous paste is still on the board: keep what the user had before it.
        let saved = pending.flatMap { $0.ours == board.changeCount ? $0.saved : nil } ?? board.snapshot()
        board.write(text)
        let ours = board.changeCount
        paste()
        generation += 1
        let mine = generation
        guard let delay, !PasteSequence.isSensitive(saved) else {
            pending = nil
            return false
        }
        pending = (saved, ours)
        await sleep(delay)
        guard mine == generation else { return false } // a newer paste owns the restore now
        pending = nil
        guard board.changeCount == ours else { return false }
        board.restore(saved)
        return true
    }
}
