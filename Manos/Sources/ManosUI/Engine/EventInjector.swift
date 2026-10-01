import ApplicationServices
import CoreGraphics
import HandKit

/// Posts synthetic mouse events. The only file that touches CGEvent posting.
/// Requires Accessibility permission; without it macOS silently drops events.
final class EventInjector {
    /// Marks our events so they can be told apart from the physical mouse.
    static let tag: Int64 = 0x0C01

    private let source = CGEventSource(stateID: .hidSystemState)
    private var leftDown = false
    /// A phased scroll is open (began, not yet ended).
    private var scrolling = false
    private var scrollRemainder = (x: 0.0, y: 0.0)
    /// Last position we moved the cursor to.
    private(set) var lastPosted: CGPoint?

    init() {
        // Otherwise the real mouse and keyboard freeze for 0.25 s after each event.
        source?.localEventsSuppressionInterval = 0
    }

    func post(_ event: GestureEvent) {
        switch event {
        case .move(let p):
            mouse(.mouseMoved, at: p)
        case .drag(let p):
            mouse(.leftMouseDragged, at: p)
        case .down(let p, let clicks):
            leftDown = true
            mouse(.leftMouseDown, at: p, clicks: clicks)
        case .up(let p, let clicks):
            leftDown = false
            mouse(.leftMouseUp, at: p, clicks: clicks)
        case .rightClick(let p):
            mouse(.rightMouseDown, at: p, button: .right)
            mouse(.rightMouseUp, at: p, button: .right)
        case .scroll(let dx, let dy, let phase):
            scrolling = phase != .ended
            scroll(dx: dx, dy: dy, phase: phase)
        case .flick:
            break // needs the profile; see `flick(_:profile:)`
        case .paused:
            break
        }
    }

    /// "Next" / "previous" item at `point` (the cursor): a scroll or an arrow
    /// key. Flick up is always "next", like swiping up on a phone.
    func flick(_ direction: FlickDirection, at point: CGPoint, profile: HandProfile) {
        let next = direction == .up
        if profile.flickAction == .arrowKeys {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: next ? 0x7D : 0x7E, keyDown: down) // ↓ next, ↑ previous
                event?.setIntegerValueField(.eventSourceUserData, value: Self.tag)
                event?.post(tap: .cghidEventTap)
            }
            return
        }
        // Scroll events go to the window under `point`. Pixel units: the value is
        // the content shift in points (NSEvent.scrollingDeltaY); negative moves
        // content up, i.e. "next". Synthetic events aren't flipped by the natural-
        // scrolling setting. Plain, unphased wheel events: feeds like Shorts,
        // TikTok and Reels react to wheel input, and snap to the nearest item.
        let screen = profile.flickAction == .auto ? Self.windowHeight(at: point).map { $0 * 0.8 } : nil
        let total = (screen ?? profile.flickScrollAmount) * (next ? -1 : 1)
        let steps = 4
        for _ in 0..<steps {
            let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1,
                                wheel1: Int32(total / Double(steps)), wheel2: 0, wheel3: 0)
            event?.location = point
            event?.setIntegerValueField(.eventSourceUserData, value: Self.tag)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Height of the frontmost normal window under `point` (global, top-left
    /// origin, like CGEvent). Window bounds need no screen-recording permission.
    private static func windowHeight(at point: CGPoint) -> Double? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.lazy
            .filter { $0[kCGWindowLayer as String] as? Int == 0 } // skips menus, overlays, our HUD
            .compactMap { ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } }
            .first { $0.contains(point) }
            .map { Double($0.height) }
    }

    func resetPosition(to point: CGPoint) { lastPosted = point }

    /// Lifts a held button and ends an open scroll. Call on disable, pause, quit, and tracking loss.
    func releaseAll() {
        if scrolling {
            scrolling = false
            scroll(dx: 0, dy: 0, phase: .ended)
        }
        guard leftDown else { return }
        mouse(.leftMouseUp, at: CGEvent(source: nil)?.location ?? lastPosted ?? .zero)
        leftDown = false
    }

    private func mouse(_ type: CGEventType, at p: CGPoint, clicks: Int = 1, button: CGMouseButton = .left) {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: button)
        else { return }
        // clickState on both down and up is what makes double/triple clicks work.
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clicks))
        event.setIntegerValueField(.eventSourceUserData, value: Self.tag)
        event.post(tap: .cghidEventTap)
        lastPosted = p
    }

    private func scroll(dx: Double, dy: Double, phase: ScrollPhase) {
        // Pixel deltas are integers; carry the fractions so slow scrolls still move.
        // Grab-the-page: hand up (dy > 0) moves content up, i.e. a negative wheel delta.
        let x = dx + scrollRemainder.x, y = -dy + scrollRemainder.y
        let ix = x.rounded(.towardZero), iy = y.rounded(.towardZero)
        scrollRemainder = (x - ix, y - iy)
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                  wheel1: Int32(iy), wheel2: Int32(ix), wheel3: 0)
        else { return }
        // Phases make apps like Safari treat it as a trackpad-style gesture.
        let phaseValue: Int64 = switch phase {
        case .began: 1
        case .changed: 2
        case .ended: 4
        }
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phaseValue)
        event.setIntegerValueField(.eventSourceUserData, value: Self.tag)
        event.post(tap: .cghidEventTap)
        if phase == .ended { scrollRemainder = (0, 0) }
    }
}

enum Permissions {
    /// Whether we may post mouse events (Accessibility).
    static var canControl: Bool { AXIsProcessTrusted() }

    /// Adds the app to System Settings → Accessibility and shows the system
    /// prompt (once; afterwards the user toggles it in Settings).
    static func requestControl() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
