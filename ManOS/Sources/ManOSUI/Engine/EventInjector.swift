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
            scroll(dx: dx, dy: dy, phase: phase)
        case .paused:
            break
        }
    }

    /// Lifts a held button. Call on disable, pause, quit, and tracking loss.
    func releaseAll() {
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
