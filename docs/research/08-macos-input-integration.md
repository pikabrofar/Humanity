# 08 — macOS system integration for camera-driven input

Scope: how an oculOS app (for example the planned hand-gesture app) moves the real pointer, clicks, drags and scrolls on macOS 14+, which permissions that takes, and how to keep those permissions working across rebuilds.

## TL;DR

- **Inject input with `CGEvent` + `post(tap:)`.** Move the pointer by posting `.mouseMoved` events, or `.leftMouseDragged` while a button is held. Use `CGWarpMouseCursorPosition` only for teleports: it generates no event, so hover and tracking areas don't update.
- **The permission is Post Event, not Accessibility.** Check it with `CGPreflightPostEventAccess()` and ask for it with `CGRequestPostEventAccess()`. Both grants show up in the same System Settings > Privacy & Security > Accessibility list. You need `AXIsProcessTrustedWithOptions` only if you also use `AXUIElement` (for example, to snap to targets). Input Monitoring is only for *listening* to events, and VisionGaze's Carbon hot key doesn't need it.
- **Ad-hoc signing (`codesign --sign -`) will break permissions on every rebuild.** TCC stores the code requirement, and for ad-hoc apps that is the cdhash, which changes with each build. Sign with a stable self-signed or Apple Development identity, and add a `tccutil reset` target to the Makefile.
- **Coordinates:** CGEvent and AX use a *global top-left* origin (the primary display's top-left, y increasing downward, in points). AppKit/`NSScreen` uses a bottom-left origin. The conversion is `yCG = primaryScreen.frame.maxY − yNS`, and it holds on every display. All values are in points, so Retina needs no special handling.
- **Scroll:** use `CGEvent(scrollWheelEvent2Source:units:.pixel,…)` with `scrollWheelEventIsContinuous = 1` and **no phase fields**. Setting scroll or momentum phases makes AppKit/WebKit treat the stream as a trackpad gesture, which causes rubber-banding and breaks JS wheel handlers.

## Key findings

**Event injection.** Post each event with `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)`, a CG global point and `.post(tap:)`.
- Apple DTS's own example uses `.cgSessionEventTap` with a `nil` source.
- `.cghidEventTap` injects at the HID level, as if the event came from hardware, so every session-level tap (other utilities, the Dock) sees it. It is the common choice for pointer tools.
- *Uncertain:* both work for pointing. Pick `.cghidEventTap` and keep the choice configurable.

**Clicks and drags.**
- A click is a down event followed by an up event at the same point.
- A double-click is two such pairs within `NSEvent.doubleClickInterval`, with `mouseEventClickState` set to 1 on the first pair and 2 on the second. Without the click state, apps see two single clicks.
- A drag is down, then a stream of `.leftMouseDragged` events, then up. Set `mouseEventDeltaX/Y` on move and drag events, because some apps (games, canvas editors) read deltas instead of absolute positions.

**Warping.** `CGWarpMouseCursorPosition` separates the physical mouse from the cursor for about 0.25 s. Call `CGAssociateMouseAndMouseCursorPosition(1)` right after the warp to cancel that.

**Scroll phases.**
- `kCGScrollWheelEventScrollPhase` is field 99 and the momentum phase is field 123. They exist, but OpenLogi removed them after they caused rubber-band overscroll in Brave and Mail and blocked JS-driven scrolling (Fastmail in Safari).
- Phaseless continuous pixel events match how native smooth-scroll utilities behave. Build any "momentum" yourself: post decaying deltas at 60–120 Hz.

**Permissions and TCC.**
- Post Event (`kTCCServicePostEvent`) is the privilege you need, and Apple says it is compatible with App Sandbox.
- `AXUIElement` control of other apps needs the Accessibility privilege. That is effectively incompatible with the sandbox for this use case (*uncertain wording, but standard practice*). oculOS isn't going to the Mac App Store, so ship **unsandboxed**.
- On Tahoe (macOS 26), a process that was denied or has a stale grant has its events silently dropped. WindowServer logs "Sender is prohibited from synthesizing events" while `post` still appears to succeed.
- The camera permission needs `NSCameraUsageDescription`, which is already in the plist. If you enable the hardened runtime (required for notarization), it also needs the `com.apple.security.device.camera` entitlement.

**Accessibility API (target-aware input).**
- `AXUIElementCopyElementAtPosition(systemWide, x, y, &el)` takes CG top-left coordinates. Read `kAXRoleAttribute` and `"AXFrame"` from the result, then call `AXUIElementPerformAction(el, kAXPressAction)`.
- This lets gaze or gesture input snap to the nearest button and press it without pixel precision, which matters given VisionGaze's 2–4° error.
- The calls are cross-process IPC and can block. Run them off the main thread and call `AXUIElementSetMessagingTimeout` (for example 0.05 s).

**Overlays.** The existing `OverlayWindow` is the right pattern: `.screenSaver` level, `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, `ignoresMouseEvents = true`. An overlay that accepts mouse events would receive the app's own synthesized clicks, so the hand app's cursor overlay must *never* be interactive.

**Menu bar apps.** Use SwiftUI `MenuBarExtra` (macOS 13+, `.menuBarExtraStyle(.window)` for rich UI). Set `LSUIElement = true` in Info.plist, or call `NSApp.setActivationPolicy(.accessory)`, so the app has no Dock icon and never steals focus.

**Prior art.**
- **Apple Head Pointer** (Accessibility > Pointer Control > Alternate Control Methods) moves the pointer from head movement. Its "Alternate pointer actions" map facial expressions to actions, for example raised eyebrows for left click, open mouth for drag and drop, and puckered lips for right click. It sets the UX bar: a gesture-size threshold, camera selection, and a quick way to pause.
- **Google Project Gameface** uses a webcam and MediaPipe's 468 face landmarks, with a per-gesture "gesture size" threshold. It runs on Windows only. The idea to borrow is per-user trigger thresholds.
- **Talon** combines eye tracking for large jumps, head tracking for fine correction, and "zoom mouse" (magnify, then pick). Clicks and drags come from pop and hiss noises. This hybrid of coarse gaze and fine second modality is the proven design for low-accuracy gaze.

## How to program it

```swift
import AppKit
import ApplicationServices

enum Permissions {
    static var canPostEvents: Bool { CGPreflightPostEventAccess() }
    @discardableResult static func requestPostEvents() -> Bool { CGRequestPostEventAccess() }

    /// Needed only for AXUIElement (snapping / press actions).
    static func isAXTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

enum ScreenGeometry {
    /// AppKit (bottom-left of primary) -> CG global (top-left of primary). Points.
    static func cgPoint(fromAppKit p: NSPoint) -> CGPoint {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: p.x, y: primaryMaxY - p.y)
    }
    static func appKitPoint(fromCG p: CGPoint) -> NSPoint {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return NSPoint(x: p.x, y: primaryMaxY - p.y)
    }
    /// Normalized (0..1, top-left) point on a given screen -> CG global.
    static func cgPoint(normalized n: CGPoint, on screen: NSScreen) -> CGPoint {
        let f = screen.frame
        return cgPoint(fromAppKit: NSPoint(x: f.minX + n.x * f.width, y: f.maxY - n.y * f.height))
    }
    /// Clamp to the nearest active display so the pointer never lands in a gap.
    static func clamp(_ p: CGPoint) -> CGPoint {
        var count: UInt32 = 0
        if CGGetDisplaysWithPoint(p, 0, nil, &count) == .success, count > 0 { return p }
        let rects = NSScreen.screens.map { s -> CGRect in
            let o = cgPoint(fromAppKit: NSPoint(x: s.frame.minX, y: s.frame.maxY))
            return CGRect(origin: o, size: s.frame.size)
        }
        guard let r = rects.min(by: { dist($0, p) < dist($1, p) }) else { return p }
        return CGPoint(x: min(max(p.x, r.minX), r.maxX - 1), y: min(max(p.y, r.minY), r.maxY - 1))
    }
    private static func dist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }
}

final class MouseInjector {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let tap: CGEventTapLocation = .cghidEventTap
    private(set) var position: CGPoint = CGEvent(source: nil)?.location ?? .zero
    private(set) var leftDown = false

    init() { source?.localEventsSuppressionInterval = 0 }

    func move(to target: CGPoint) {
        let p = ScreenGeometry.clamp(target)
        let type: CGEventType = leftDown ? .leftMouseDragged : .mouseMoved
        guard let e = CGEvent(mouseEventSource: source, mouseType: type,
                              mouseCursorPosition: p, mouseButton: .left) else { return }
        e.setIntegerValueField(.mouseEventDeltaX, value: Int64((p.x - position.x).rounded()))
        e.setIntegerValueField(.mouseEventDeltaY, value: Int64((p.y - position.y).rounded()))
        e.post(tap: tap)
        position = p
    }

    func press(_ button: CGMouseButton = .left, clickState: Int64 = 1) {
        post(button == .left ? .leftMouseDown : button == .right ? .rightMouseDown : .otherMouseDown,
             button, clickState)
        if button == .left { leftDown = true }
    }
    func release(_ button: CGMouseButton = .left, clickState: Int64 = 1) {
        post(button == .left ? .leftMouseUp : button == .right ? .rightMouseUp : .otherMouseUp,
             button, clickState)
        if button == .left { leftDown = false }
    }

    func click(_ button: CGMouseButton = .left) { press(button); release(button) }

    func doubleClick() {
        press(clickState: 1); release(clickState: 1)
        press(clickState: 2); release(clickState: 2)   // must be within NSEvent.doubleClickInterval
    }

    /// Drag = press, then move(to:) repeatedly (emits .leftMouseDragged), then release.
    func drag(from a: CGPoint, to b: CGPoint, steps: Int = 20) {
        move(to: a); press()
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            move(to: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            usleep(8_000) // some apps need intermediate events; do this off the main thread
        }
        release()
    }

    /// Pixel, phaseless, continuous scroll. Positive dy scrolls content up (like wheel-up).
    func scroll(dx: Int32 = 0, dy: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel,
                              wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.location = position
        e.post(tap: tap)
    }

    /// Safety: never leave a button stuck down on pause/quit/crash-handler.
    func releaseAll() { if leftDown { release() } }

    func warp(to p: CGPoint) {        // teleport without events (no hover update)
        CGWarpMouseCursorPosition(p)
        CGAssociateMouseAndMouseCursorPosition(1)
        position = p
    }

    private func post(_ type: CGEventType, _ button: CGMouseButton, _ clickState: Int64) {
        guard let e = CGEvent(mouseEventSource: source, mouseType: type,
                              mouseCursorPosition: position, mouseButton: button) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: clickState)
        e.post(tap: tap)
    }
}

// Target-aware press via Accessibility (requires AX trust).
func pressElement(at p: CGPoint) -> Bool {
    let sys = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(sys, 0.05)
    var el: AXUIElement?
    guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(p.y), &el) == .success,
          let el else { return false }
    return AXUIElementPerformAction(el, kAXPressAction as CFString) == .success
}
```

## Recommendations for oculOS

1. **Create a shared local Swift package** (for example `oculOS/Shared/OculusInput`, name TBD) holding `MouseInjector`, `ScreenGeometry`, `Permissions`, `OverlayWindow` and `HotKey`, moved out of VisionGaze. Both apps depend on it with `.package(path:)`. Then gaze-plus-gesture fusion later means only a new app, not duplicated code.
2. **Use stable signing.** Change `build-app.sh` to `codesign --force --sign "${OCULOS_SIGN_ID:--}"` and document how to create a self-signed "oculOS Dev" code-signing certificate in Keychain Access, or how to use an Apple Development identity. Add `make reset-perms`, which runs `tccutil reset Accessibility <bundle-id>` and `tccutil reset Camera <bundle-id>`. *Uncertain:* the service names `PostEvent` and `ListenEvent` are believed to be accepted too.
3. **Give each app its own bundle ID** (for example `io.github.pikabrofar.oculos.HandPointer`), so each has its own TCC entries and the prompts are clear.
4. **Build onboarding for permissions.** Show a checklist window with camera, Post Event and optional Accessibility (for snapping). Poll `CGPreflightPostEventAccess()` about every second after the user opens Settings, because there is no callback. Tell users to relaunch if the grant doesn't take effect (*uncertain* whether a relaunch is always required).
5. **Add a kill switch.** Reuse the Carbon `HotKey` (for example ⌃⌥⌘P) to pause injection and call `releaseAll()`. Also pause automatically when the hand leaves the frame or tracking confidence drops.
6. **Design the interaction:** relative (joystick-style) or absolute mapping with One-Euro smoothing, dwell or pinch to click, snap-to-AX-target as an option, and Talon-style gaze jump plus hand fine-tune as a later feature.
7. **Stay unsandboxed and add a menu bar UI** (`MenuBarExtra`, `LSUIElement`). The cursor overlay stays `ignoresMouseEvents = true`.

## Pitfalls

- An interactive overlay under the pointer eats your own synthetic clicks.
- A stale TCC grant after a rebuild looks like "enabled" in Settings but silently fails. Remove the entry and re-add it, or run `tccutil reset`.
- Mixing coordinate spaces: `NSEvent.mouseLocation` is AppKit bottom-left, while `CGEvent.location` is CG top-left. Displays left of or above the primary have negative CG coordinates.
- Forgetting `mouseEventClickState` breaks double-clicks, and forgetting the drag event type (`.leftMouseDragged`) breaks drags.
- Scroll with phases causes rubber-banding and swipe-back navigation. A zero-delta continuous event is a no-op, so skip it.
- AX calls can hang for seconds on busy apps, so never make them on the main or camera thread.
- Leaving a button pressed on pause or crash (stuck drag). Call `releaseAll()` in `applicationWillTerminate` and when pausing.

## Sources

- https://developer.apple.com/forums/thread/730441 (DTS: Post Event privilege, sandbox-compatible, `.cgSessionEventTap`)
- https://developer.apple.com/forums/thread/744440 (DTS: Accessibility only needed for AX APIs; Listen/Post preflight APIs)
- https://github.com/AprilNEA/OpenLogi/pull/1157 (phaseless continuous scroll rationale)
- https://docs.rs/cgevents/latest/cgevents/ (scroll field numbers 88/99/123)
- https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html
- https://github.com/Hammerspoon/hammerspoon/issues/2005 (warp suppression delay)
- https://github.com/pathorsAI/parley/issues/75 and https://github.com/shlgd/SuperDictate/issues/19 (ad-hoc signing breaks TCC, `tccutil reset`)
- https://github.com/waydabber/BetterDisplay/issues/5444 (Tahoe PostEvent denial drops clicks)
- https://support.apple.com/guide/mac-help/use-head-pointer-mchlb2d4782b/mac, https://www.howtogeek.com/788217/how-to-use-your-head-and-face-to-control-your-mac/
- https://blog.google/innovation-and-ai/products/google-project-gameface/
- https://talonvoice.com/
