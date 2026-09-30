# Accessibility API for target-aware pointing

## TL;DR

- Use `AXUIElementCopyElementAtPosition` for a single hit test, then walk up with `AXParent` until you reach an actionable ancestor. To pick among nearby targets under a 2–4° gaze cone, scan the focused window once and query a cached list of frames.
- Every AX call is a synchronous mach/XPC round trip into the target app. Batch reads with `AXUIElementCopyMultipleAttributeValues`, prune subtrees that lie outside the search rect, and set `AXUIElementSetMessagingTimeout` to a short value (about 50–100 ms) on the elements you scan.
- Chromium and Electron build their AX tree lazily. Set `AXManualAccessibility = true` on the app element. Avoid `AXEnhancedUserInterface` because it breaks window managers and animations.
- Vimac, Homerow and Shortcat all traverse the focused window's tree, filter by role and actions, and draw hints. None of them does anything magic, and Vimac's own bottleneck was IPC volume.
- Invalidate the cache with `AXObserver` notifications (focus, window moved, layout changed, element destroyed), plus a time-to-live of about 1–2 s as a backstop.

## Key findings

- **Hit test.** `AXUIElementCopyElementAtPosition(app or systemWide, x, y, &el)` takes top-left global coordinates. It often returns a leaf such as `AXStaticText` or `AXImage`, not the button that contains it, so you have to climb the parent chain.
- **Clickable heuristics.** A good heuristic is `AXActionNames` containing `AXPress`, or a role in {`AXButton`, `AXLink`, `AXCheckBox`, `AXRadioButton`, `AXPopUpButton`, `AXMenuItem`, `AXMenuButton`, `AXTextField`, `AXTab`, `AXCell`/`AXRow`, `AXDisclosureTriangle`}. Vimac's big improvement was cutting hints down to "just clickable" elements.
- **Geometry.** `AXFrame` is a private but widely used attribute that returns a CGRect in one call. The public route is `AXPosition` plus `AXSize` as `AXValue`. Both use top-left global coordinates. *(AXFrame availability across apps is unverified.)*
- **Cost.** Vimac's maintainers found that the public API "is too slow" in WebKit and Electron apps because of the number of mach IPC calls per tree. They confirmed that the multiple-attribute call is faster than repeated single reads. There are no published per-call timings. A rough rule is 0.05–1 ms per call natively and far more in large web trees *(estimate, unverified)*.
- **Timeouts.** The default messaging timeout is about 6 s. Calling `AXUIElementSetMessagingTimeout` on the system-wide element changes it for the whole process, which hurts other modules. Set it per element instead.
- **Browsers.** Vimac sets `AXManualAccessibility` on frontmost Electron apps. For Chrome, it tells users to turn accessibility on at `chrome://accessibility`. A cold Chromium tree first returns a bare `AXGroup`. Retry for about 150 ms after enabling it. Firefox and Chrome support is still an open "help wanted" issue in Vimac.

## How to program it

```swift
import ApplicationServices

struct AXTarget { let el: AXUIElement; let frame: CGRect; let role: String }
let clickableRoles: Set<String> = ["AXButton","AXLink","AXCheckBox","AXRadioButton",
  "AXPopUpButton","AXMenuItem","AXMenuButton","AXTextField","AXTab","AXCell","AXDisclosureTriangle"]

func targets(near p: CGPoint, radius r: CGFloat, pid: pid_t, budget: TimeInterval = 0.015) -> [AXTarget] {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.05)
    AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue) // Electron
    var win: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &win) == .success
    else { return [] }
    let search = CGRect(x: p.x - r, y: p.y - r, width: 2*r, height: 2*r)
    let deadline = Date().addingTimeInterval(budget)
    let attrs = [kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute, kAXChildrenAttribute] as CFArray
    var out: [AXTarget] = [], stack = [win as! AXUIElement]
    while let el = stack.popLast(), Date() < deadline {
        var vals: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(el, attrs, [], &vals) == .success,
              let v = vals as? [AnyObject], v.count == 4 else { continue }
        var pos = CGPoint.zero, size = CGSize.zero
        if CFGetTypeID(v[1]) == AXValueGetTypeID() { AXValueGetValue(v[1] as! AXValue, .cgPoint, &pos) }
        if CFGetTypeID(v[2]) == AXValueGetTypeID() { AXValueGetValue(v[2] as! AXValue, .cgSize, &size) }
        let frame = CGRect(origin: pos, size: size)
        if !frame.isEmpty && !frame.intersects(search) { continue }  // prune offscreen subtree
        let role = v[0] as? String ?? ""
        if clickableRoles.contains(role), !frame.isEmpty { out.append(.init(el: el, frame: frame, role: role)) }
        if let kids = v[3] as? [AXUIElement] { stack.append(contentsOf: kids) }
    }
    return out.sorted { dist($0.frame, p) < dist($1.frame, p) }
}
func dist(_ f: CGRect, _ p: CGPoint) -> CGFloat {
    hypot(max(f.minX - p.x, 0, p.x - f.maxX), max(f.minY - p.y, 0, p.y - f.maxY))
}
```

A failed attribute comes back as an `AXValue` of type `.axError` in the array, so the `CFGetTypeID` checks matter. Some containers report an empty frame, so the scan descends into them without pruning. To activate a target, call `AXUIElementPerformAction(el, kAXPressAction)`. Fall back to a `CGEvent` click at the frame's center when the press fails.

## Recommendations for oculOS

1. Run the scan on a background serial queue when focus changes or a fixation starts, not once per gaze frame. Keep a spatial list of `(frame, role)` and snap from that list at 30–60 Hz.
2. Size the snap radius from the gaze error (2–4° is about 70–150 px at 60 cm). Weight candidates by distance and target size, and add hysteresis so the snapped target doesn't flicker.
3. Subscribe an `AXObserver` to `kAXFocusedWindowChanged`, `kAXWindowMoved`/`Resized`, `kAXLayoutChanged`, `kAXUIElementDestroyed` and `kAXValueChanged`, and mark the cache stale when one fires. Rescan lazily.
4. When the scan returns nothing (games, canvas apps, cold Chrome), fall back to raw gaze plus hand refinement.
5. Commit with `AXPress` for plain buttons, because it doesn't move the user's cursor. Use `CGEvent` for everything else, since web links often ignore `AXPress` *(unverified)*.

## Pitfalls

- A process-wide timeout set on the system-wide element affects every AX call in the app.
- A hung target app blocks the calling thread until the timeout expires, so never scan on the main thread.
- `AXEnhancedUserInterface` makes window moves sluggish and conflicts with Magnet and Rectangle.
- Elements in scroll views that are clipped still report frames outside the visible area. Intersect them with the ancestor `AXScrollArea` frame.
- Multi-display setups and Retina scaling: AX uses points in global top-left coordinates, which is not the same space as camera or Vision normalized coordinates.
- An `AXUIElement` reference goes stale after a re-render (`kAXErrorInvalidUIElement`), so re-query instead of holding on to it.
- Sandboxed App Store builds can't use the AX API against other apps, so ship outside the store.

## Sources

- https://github.com/nchudleigh/vimac/issues/178
- https://github.com/nchudleigh/vimac/issues/78
- https://github.com/nchudleigh/vimac/blob/master/docs/manual.md
- https://news.ycombinator.com/item?id=24323378
- https://github.com/electron/electron/pull/7206
- https://www.electronjs.org/docs/latest/tutorial/accessibility
- https://github.com/asmagill/hammerspoon/wiki/hs.axuielement-Overview
- https://leopard-adc.pepas.com/documentation/Accessibility/Reference/AccessibilityLowlevel/AXUIElement_h/CompositePage.html
- https://www.homerow.app/
- https://news.ycombinator.com/item?id=33225726
