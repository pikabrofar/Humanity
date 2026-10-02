import ApplicationServices
import CoreGraphics
import Foundation

/// Commits a click where the user looks: snaps to the nearest clickable
/// Accessibility element and posts a synthetic click. Both need Accessibility
/// permission; without it snapping returns nil and macOS drops the click.
public enum GazeClick {
    /// Marks our synthetic events (`eventSourceUserData`) so click learning can skip them.
    public static let tag: Int64 = 0x6A2E

    static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXMenuItem", "AXMenuBarItem", "AXMenuButton", "AXPopUpButton",
        "AXCheckBox", "AXRadioButton", "AXDisclosureTriangle", "AXTextField", "AXComboBox", "AXDockItem",
    ]

    /// Snap radii in degrees. Passive dwell gets a tight one so it can't reach a
    /// neighboring control; an explicit trigger (hot key, pinch) can reach further.
    public static let dwellSnapDegrees = 1.5
    public static let clickSnapDegrees = 4.0

    /// Controls and windows a passive dwell never clicks: closing windows, sheets
    /// and alerts (Don't Save, Delete…), and system prompts. ⌃⌥⌘G still works there.
    public static func dwellAvoids(role: String?, subrole: String?) -> Bool {
        role == "AXSheet" || ["AXCloseButton", "AXDialog", "AXSystemDialog"].contains(subrole ?? "")
    }

    /// Whether the element under `p` (or its window) is one `dwellAvoids` covers.
    public static func dwellBlocked(at p: CGPoint) -> Bool {
        guard AXIsProcessTrusted(), let e = element(at: p) else { return false }
        return avoided(e) || attribute(e, kAXWindowAttribute).map { avoided($0 as! AXUIElement) } == true
    }

    private static func avoided(_ e: AXUIElement) -> Bool {
        var element: AXUIElement? = e
        for _ in 0..<4 {
            guard let e = element else { break }
            if dwellAvoids(role: attribute(e, kAXRoleAttribute) as? String,
                           subrole: attribute(e, kAXSubroleAttribute) as? String) { return true }
            element = attribute(e, kAXParentAttribute).map { $0 as! AXUIElement }
        }
        return false
    }

    private static func element(at p: CGPoint) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var hit: AXUIElement?
        return AXUIElementCopyElementAtPosition(system, Float(p.x), Float(p.y), &hit) == .success ? hit : nil
    }

    /// Visual angle to screen points: `widthPoints` across `widthMM` viewed from `distanceMM`.
    public static func pointsPerDegree(widthPoints: Double, widthMM: Double, distanceMM: Double) -> Double {
        widthPoints / widthMM * distanceMM * tan(.pi / 180)
    }

    /// Hit-test points: the center plus rings at r/2 and r, at most 19 per commit.
    static func probes(around p: CGPoint, radius r: Double) -> [CGPoint] {
        [p] + [(r / 2, 6), (r, 12)].flatMap { ring, n in
            (0..<n).map { i in
                let a = Double(i) * 2 * .pi / Double(n)
                return CGPoint(x: p.x + ring * cos(a), y: p.y + ring * sin(a))
            }
        }
    }

    /// Center of the frame closest to `p` (0 when inside it), if within `radius`.
    static func nearest(to p: CGPoint, in frames: [CGRect], radius: Double) -> CGPoint? {
        func gap(_ r: CGRect) -> Double {
            hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
        }
        return frames.filter { gap($0) <= radius }.min { gap($0) < gap($1) }.map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// Center of the nearest clickable element within `radius` of `p`. Points are
    /// global display coordinates with a top-left origin, as CGEvent uses.
    /// With `forDwell`, controls `dwellAvoids` covers are never snap targets.
    public static func snap(_ p: CGPoint, radius: Double, forDwell: Bool = false) -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05) // global: a hung app can't stall us long
        var found: [AXUIElement] = []
        for q in probes(around: p, radius: radius) {
            var hit: AXUIElement?
            let error = AXUIElementCopyElementAtPosition(system, Float(q.x), Float(q.y), &hit)
            if error == .cannotComplete { break }
            // Climb from e.g. a label to the button holding it.
            var element = hit
            for _ in 0..<4 {
                guard let e = element else { break }
                if clickableRoles.contains(attribute(e, kAXRoleAttribute) as? String ?? "") {
                    if forDwell, dwellAvoids(role: nil, subrole: attribute(e, kAXSubroleAttribute) as? String) { break }
                    if !found.contains(where: { CFEqual($0, e) }) { found.append(e) }
                    break
                }
                element = attribute(e, kAXParentAttribute).map { $0 as! AXUIElement }
            }
        }
        return nearest(to: p, in: found.compactMap(frame), radius: radius)
    }

    /// Moves the pointer to `p` and left-clicks there.
    public static func click(at p: CGPoint) {
        for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
            event?.flags = []
            event?.setIntegerValueField(.eventSourceUserData, value: tag)
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func attribute(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success ? value : nil
    }

    private static func frame(_ e: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero, size = CGSize.zero
        guard let p = attribute(e, kAXPositionAttribute), let s = attribute(e, kAXSizeAttribute),
              AXValueGetValue(p as! AXValue, .cgPoint, &origin), AXValueGetValue(s as! AXValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
