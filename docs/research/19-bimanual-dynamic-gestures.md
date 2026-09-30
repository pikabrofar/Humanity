# 19 — Two-hand and dynamic gestures

Covers bimanual zoom/rotate, swipes for Spaces/Mission Control, temporal
recognizers, segmentation, and mapping to macOS actions. Basic pinch/point/
scroll is in [07](07-gesture-recognition.md); event posting is in
[08](08-macos-input-integration.md).

## TL;DR

- **Bimanual zoom/rotate is pure geometry.** Scale = current distance between
  the two pinch points divided by the distance when the second pinch began.
  Rotation = change in the angle of the line between them. No ML needed.
- **Swipes: use a velocity-gated state machine, not a classifier.** Arm when
  the hand is open and in the clutch-engaged state, fire when displacement over
  about 250 ms passes a hand-size-normalized threshold, then enforce a refractory period.
- **Use ML only for a later custom-gesture feature.** $1/$Q and DTW-kNN learn from 1–3 templates
  per user. Create ML's Hand Action Classifier (fixed window, for example 60
  frames at 30 fps) is the Apple-native option but adds about 1–2 s of latency.
- **Map to keyboard shortcuts first** (Ctrl+←/→ for Spaces, Ctrl+↑ for Mission
  Control, Cmd +/- for zoom). Synthetic magnify gestures work but rely on
  undocumented `CGEvent` fields *(fragile)*.

## Key findings

- **Vision returns up to N hands per request** (`maximumHandCount`). Chirality
  (`.left`/`.right`) is available on macOS 12+. Use it to keep hand identity
  across frames. Fall back to x-order if chirality flips *(it does flip under
  occlusion — unverified rate)*.
- **Create ML Hand Action Classifier** takes `keypointsMultiArray()` per
  frame and stacks them into a fixed prediction window (Apple's sample uses
  60 frames ≈ 2 s). The camera frame rate must match the training frame rate.
  Apple advises running prediction at intervals, not on every frame. That
  makes it unsuitable for low-latency swipes, but fine for "wave to
  pause"-type commands.
- **$-family recognizers:** $1 reaches about 97% with 1 template and 99% with
  3 or more on unistrokes. $Q is about 142× faster than $P and slightly more
  accurate. They work on a 2D trajectory, such as the index-tip path during a
  clutched stroke, and ignore timing.
- **DTW-kNN** handles variable gesture speed on multi-dimensional landmark
  sequences and is a common baseline for RGB-D gestures.
- **Small GRU/TCN** on landmark sequences (for example a 21×2 × T input) give
  the best accuracy/latency trade-off in the literature (GRU with attention).
  The literature names **start/end segmentation** as the hard part, not
  classification.
- **Magnify synthesis:** WebKit's test harness and TouchSynthesis-derived code
  create a gesture `CGEvent` with type 29 (`NSEventTypeGesture`), field 110 = 8
  (`kIOHIDEventTypeZoom`), field 132 = phase and field 113 = magnification.
  These fields are undocumented and apps vary in whether they honor them
  *(unverified on macOS 14/15)*.

## How to program it

```swift
import Vision
import CoreGraphics

struct PinchPoint { var p: CGPoint; var pinched: Bool }  // from report 07's detector

final class BimanualZoom {
    private var d0: CGFloat?, a0: CGFloat?
    /// Returns (scale, rotationRadians) while both hands pinch.
    func update(left: PinchPoint?, right: PinchPoint?) -> (CGFloat, CGFloat)? {
        guard let l = left, let r = right, l.pinched, r.pinched else { d0 = nil; a0 = nil; return nil }
        let dx = r.p.x - l.p.x, dy = r.p.y - l.p.y
        let d = hypot(dx, dy), a = atan2(dy, dx)
        if d0 == nil { d0 = max(d, 0.02); a0 = a }                  // gesture begins
        var da = a - a0!; if da > .pi { da -= 2 * .pi } else if da < -.pi { da += 2 * .pi }
        return (d / d0!, da)
    }
}

final class SwipeDetector {
    enum Dir { case left, right, up }
    private var hist: [(t: TimeInterval, p: CGPoint)] = []
    private var cooldownUntil: TimeInterval = 0
    let window = 0.25, refractory = 0.8

    /// p = wrist or palm centre (normalized); handSize = wrist→middle-MCP distance.
    func feed(t: TimeInterval, p: CGPoint, handSize: CGFloat, handOpen: Bool) -> Dir? {
        hist.append((t, p)); hist.removeAll { t - $0.t > window }
        guard handOpen, t > cooldownUntil, let first = hist.first, t - first.t > 0.12 else { return nil }
        let dx = (p.x - first.p.x) / handSize, dy = (p.y - first.p.y) / handSize
        let thresh: CGFloat = 1.5                                  // ≈1.5 hand-lengths in 250 ms
        var dir: Dir?
        if abs(dx) > thresh, abs(dx) > 2 * abs(dy) { dir = dx > 0 ? .right : .left }
        else if dy > thresh, dy > 2 * abs(dx) { dir = .up }         // Vision y is up
        if dir != nil { cooldownUntil = t + refractory; hist.removeAll() }
        return dir
    }
}

func postKey(_ key: CGKeyCode, flags: CGEventFlags) {             // 123 ←, 124 →, 126 ↑
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
        e?.flags = flags; e?.post(tap: .cghidEventTap)
    }
}
// .left → postKey(124, .maskControl) (natural: hand moves left, next Space); .up → postKey(126, .maskControl)
```

To zoom, quantize the scale into steps (for example every 10% change sends
Cmd+= or Cmd+-, resetting the baseline each step). Alternatively, feed
`log(scale)` deltas into the undocumented magnify event behind a feature flag.

## Recommendations for oculOS

1. Ship three gestures in v1: **swipe left/right** (Spaces), **swipe up**
   (Mission Control), and **two-hand pinch-spread** (zoom). Use rules, not ML.
2. Only recognize a swipe while the clutch from report 07 is engaged, or
   require an open palm facing the camera. That stops ordinary reaching from
   firing it.
3. Treat bimanual mode as a separate state. When the second hand appears,
   freeze the pointer and suspend single-hand click/scroll.
4. Later, add **user-recorded custom gestures** with $Q on the clutched
   index-tip trajectory (1–3 templates each). Keep a GRU/TCN or Create ML as a
   research track and train it on the replay logs from report 10.
5. Let users remap actions, and default to keyboard shortcuts that users can
   change in System Settings → Keyboard Shortcuts.

## Pitfalls

- **The return stroke:** the hand coming back after a swipe looks like the
  opposite swipe. The refractory period plus clearing the history handles it.
  Also consider requiring the return to be slower.
- **Mirroring:** front-camera frames may be mirrored. Decide left/right after
  un-mirroring, and check that chirality agrees.
- **Frame drops** distort velocity. Use timestamps, not frame counts.
- **Two hands are often out of frame** on a laptop webcam, and the hands
  occlude each other when crossed. Require both hands to be seen with
  confidence above 0.5 for several frames before entering bimanual mode.
- **Magnify events** may be ignored or behave differently per app. Some apps
  need matching begin/end phases, or the zoom gets stuck.
- **Spaces shortcuts** can be turned off, or they only work if more than one
  Space exists *(verify)*.

## Sources

- https://developer.apple.com/videos/play/wwdc2021/10039/ (Hand pose/action classification, Create ML)
- https://developer.apple.com/videos/play/wwdc2020/10043/ (Action classifier windowing)
- https://developer.apple.com/videos/play/wwdc2020/10653/ (Vision hand pose)
- https://developer.apple.com/forums/thread/685473
- https://faculty.washington.edu/wobbrock/pubs/uist-07.01.pdf ($1 recognizer)
- https://depts.washington.edu/acelab/proj/dollar/qdollar.html ($Q)
- https://www.maia.ub.es/~sergio/linked/icprdepthdtwgmm.pdf (DTW gestures)
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9823561/ (lightweight GRU/landmark models)
- https://arxiv.org/pdf/2010.13197 (Gestop: dynamic gestures, segmentation)
- https://trac.webkit.org/changeset/277772/webkit (synthetic magnify CGEvent)
- https://github.com/noah-nuebling/mac-mouse-fix/discussions/366 (gesture event synthesis)
