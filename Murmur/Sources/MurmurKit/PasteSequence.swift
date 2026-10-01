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

public enum PasteSequence {
    /// Puts `text` on the pasteboard, triggers `paste`, then puts the user's
    /// previous clipboard back.
    ///
    /// The restore waits `restoreAfter` because the target app reads the
    /// pasteboard asynchronously after receiving ⌘V. It is skipped if anything
    /// else wrote to the pasteboard in the meantime, so a copy the user made
    /// during that window is never overwritten. Pass nil to leave the text there.
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
        guard let delay else { return false }
        await sleep(delay)
        guard board.changeCount == ours else { return false }
        board.restore(saved)
        return true
    }
}
