# 07 - Gesture recognition from hand landmarks and mid-air interaction design

Scope: turning 21 2D hand joints (Vision `VNDetectHumanHandPoseRequest`, or MediaPipe Hands) into pointer, click, drag, scroll and right-click events for the planned oculOS hand app.

## TL;DR

- **Use rules for the core gestures, not ML.** Pinch, point and scroll can each be detected with one normalized distance plus hysteresis and a few frames of debounce. Apple's own WWDC20 sample works this way: a 40 pt threshold and 3 frames of evidence. Keep learned classifiers (Create ML Hand Pose/Action, MediaPipe) for extra poses such as an "engage" palm.
- **Normalize every distance by hand size**, for example wrist to middle-MCP, measured in pixel space rather than Vision's 0..1 space. Use two thresholds: enter the pinch below ~0.25 and leave it above ~0.40. These starting values are my own estimate and need tuning.
- **The "Heisenberg effect" is the main source of missed clicks.** The act of pinching moves the point the cursor follows. To fix it: drive the cursor from a stable anchor (index MCP or palm centroid, not the fingertip), freeze the cursor when a pinch starts, and roll the cursor back ~100 ms to where it was before the pinch began.
- **You need a clutch (engagement) state.** Without one, every hand movement moves the cursor (Midas touch). Use an explicit engage/disengage pose, and treat "hand leaves frame" as disengage.
- **Keep the hand low and the arm bent** (Consumed Endurance). Use gain or acceleration so small hand movements cover the whole screen.

## Key findings

**Vision hand pose (WWDC20 "Detect Body and Hand Pose with Vision")**
- Returns 21 joints, each with a confidence value. The sample ignores joints below 0.3 confidence.
- Pinch detection: thumbTip–indexTip distance below `pinchMaxDistance = 40` (AVFoundation points). The state only changes after `evidenceCounterStateTrigger = 3` frames in a row. States are `possiblePinch → pinched` and `possibleApart → apart`. That is debouncing without hysteresis. The threshold is in absolute points, so it breaks when the hand moves nearer or farther from the camera. We should normalize instead.
- `maximumHandCount` limits the work per frame. Set it to 1 for single-hand control.
- Known failure cases: hands near the frame edge, hands edge-on to the camera (a "karate chop"), gloves, and occasionally feet detected as hands.
- `chirality` (.left, .right, .unknown) tells you which hand it is.

**Create ML (WWDC21 "Classify hand poses and actions")**
- Hand Pose Classifier: trained on folders of labeled images, ~500 per class in the demo. It needs a `Background` class that holds random and transitional poses. It runs on `observation.keypointsMultiArray()`. The demo only accepts a prediction above 0.9 confidence and does not predict on every frame.
- Hand Action Classifier: trained on fixed-length videos, ~100 per class. Input shape is `[predictionWindow, 3, 21]` (x, y, confidence). Example window: 30 fps × 1.5 s = 45 frames. **The frame rate at inference must match the training frame rate.** Augmentations: time interpolation and frame drop.
- Tested range: under ~3.5 m, and avoid extreme lighting.
- A 1.5 s window adds far too much delay for clicking, so use it only for occasional commands such as swipes.

**MediaPipe Gesture Recognizer**
- 8 built-in ("canned") classes: None, Closed_Fist, Open_Palm, Pointing_Up, Thumb_Down, Thumb_Up, Victory, ILoveYou.
- The classifier head is small. It takes a 1×63 landmark tensor plus handedness and was trained on ~30K real images. It can be customized with Model Maker.
- This confirms that a small MLP on normalized landmarks is enough for static poses. A kNN on the same normalized landmark vector (translate to the wrist, scale by hand size, optionally rotate) is a zero-training alternative.

**Dynamic gestures and trajectories**
- The $1 recognizer is ~100 lines of code. It reaches ~97% accuracy with 1 template and 99% with 3 or more. $P treats a gesture as an unordered point cloud and reaches >99% with 5 or more samples.
- Either can classify fingertip trajectories (swipes, circles) captured between a start event and an end event, for example while pinched.

**Heisenberg effect (mid-air pointing)**
- The confirming action (a pinch) disturbs the pointing position, so the selection lands off target. Recent work gives this as a reason hand tracking is less accurate than controllers.
- Mitigations in the literature:
  - Point with one hand and pinch with the other.
  - Adaptive exponential smoothing that increases filtering when a pinch starts (RingGesture, 2024).
- Fitts-style studies still find pinch is a good way to select: ~2% error in MacKenzie et al., ISS 2022. I only read the search snippet, not the paper.

**Mapping and clutching**
- Pointing can map hand to cursor by position (absolute), by rate, or by a hybrid of the two.
- Pointer acceleration covers long distances at speed and gives precision when moving slowly.
- Relative mapping needs a clutch, the way you lift a mouse to reposition it. "Remove hand from frame" is the common clutch.
- "Summon and Select" (ISS 2017) handles Midas touch, gesture ambiguity and fatigue with an explicit summon step before selecting.

**Fatigue**
- Consumed Endurance (CE, Hincapié-Ramos et al., CHI 2014) = interaction time / endurance time. Endurance time comes from shoulder torque as a fraction of maximum strength.
- CE correlates strongly with Borg CR10 exertion ratings.
- It favours a bent elbow and a low interaction plane. I remember this from the paper and did not re-check it.
- NICER (2024) extends CE to model recovery.

## How to program it (Swift sketch)

```swift
import Vision
import CoreGraphics

struct HandFrame {
    let j: [VNHumanHandPoseObservation.JointName: CGPoint]   // pixel coords, not 0..1
    let t: TimeInterval
    func d(_ a: VNHumanHandPoseObservation.JointName, _ b: VNHumanHandPoseObservation.JointName) -> CGFloat {
        guard let p = j[a], let q = j[b] else { return .infinity }
        return hypot(p.x - q.x, p.y - q.y)
    }
    var handSize: CGFloat { d(.wrist, .middleMCP) }                // scale-invariant unit
    var indexPinch: CGFloat { d(.thumbTip, .indexTip) / handSize }
    var middlePinch: CGFloat { d(.thumbTip, .middleTip) / handSize }
    /// Stable anchor: barely moves when the thumb/index close.
    var anchor: CGPoint? {
        guard let a = j[.indexMCP], let b = j[.middleMCP], let w = j[.wrist] else { return nil }
        return CGPoint(x: (a.x + b.x + w.x) / 3, y: (a.y + b.y + w.y) / 3)
    }
}

struct Hysteresis {            // enter < on, exit > off, N frames of evidence
    let on: CGFloat, off: CGFloat, frames: Int
    private(set) var active = false; private var n = 0
    mutating func update(_ v: CGFloat) -> Bool {
        let wants = active ? !(v > off) : (v < on)
        n = (wants != active) ? n + 1 : 0
        if n >= frames { active.toggle(); n = 0 }
        return active
    }
}

enum GestureState {
    case disengaged                                    // no cursor output (clutch open)
    case hover                                          // cursor follows anchor
    case pinchPending(start: TimeInterval, frozenAt: CGPoint)
    case dragging(offset: CGVector)
    case rightPending(start: TimeInterval, frozenAt: CGPoint)
    case scrolling(last: CGPoint)
}

enum OutputEvent { case move(CGPoint), leftDown(CGPoint), leftUp(CGPoint), rightClick(CGPoint), scroll(dx: CGFloat, dy: CGFloat) }

final class GestureMachine {
    var state: GestureState = .disengaged
    var idx = Hysteresis(on: 0.25, off: 0.40, frames: 2)
    var mid = Hysteresis(on: 0.25, off: 0.40, frames: 2)
    var history: [(TimeInterval, CGPoint)] = []        // filtered cursor, ~300 ms
    let rollback: TimeInterval = 0.10, tapMax: TimeInterval = 0.30
    let dragSlop: CGFloat = 12                         // screen points

    func cursorAt(_ t: TimeInterval) -> CGPoint {       // pre-pinch position (delay compensation)
        history.last(where: { $0.0 <= t })?.1 ?? history.last?.1 ?? .zero
    }

    func step(_ f: HandFrame, cursor: CGPoint, engaged: Bool) -> [OutputEvent] {
        history.append((f.t, cursor)); history.removeAll { f.t - $0.0 > 0.3 }
        let iP = idx.update(f.indexPinch), mP = mid.update(f.middlePinch)
        switch state {
        case .disengaged:
            if engaged { state = .hover }; return []
        case .hover:
            if !engaged { state = .disengaged; return [] }
            if iP { let p = cursorAt(f.t - rollback); state = .pinchPending(start: f.t, frozenAt: p); return [.leftDown(p)] }
            if mP { state = .rightPending(start: f.t, frozenAt: cursorAt(f.t - rollback)); return [] }
            return [.move(cursor)]
        case .pinchPending(_, let p):                    // cursor frozen
            if !iP { state = .hover; return [.leftUp(p)] }   // click
            if hypot(cursor.x - p.x, cursor.y - p.y) > dragSlop {
                state = .dragging(offset: CGVector(dx: p.x - cursor.x, dy: p.y - cursor.y))
            }
            return []
        case .dragging(let o):
            let q = CGPoint(x: cursor.x + o.dx, y: cursor.y + o.dy)
            if !iP { state = .hover; return [.leftUp(q)] }
            return [.move(q)]
        case .rightPending(let s, let p):
            if !mP { state = .hover; return f.t - s < tapMax ? [.rightClick(p)] : [] }
            if hypot(cursor.x - p.x, cursor.y - p.y) > dragSlop { state = .scrolling(last: cursor) }
            return []
        case .scrolling(let last):
            if !mP { state = .hover; return [] }
            state = .scrolling(last: cursor)
            return [.scroll(dx: cursor.x - last.x, dy: cursor.y - last.y)]
        }
    }
}
```

Notes on the sketch:

- **Convert to pixels first.** Vision points are normalized 0..1 with the origin at bottom-left. Multiply by image width and height before measuring distances, or the non-square frame skews the ratios.
- **Pass `cursor` through a smoothing filter** (a 1€ filter or an adaptive EMA) after the anchor-to-screen mapping.
- **Post events** with `CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)`. During a drag use `.leftMouseDragged`. For scrolling use `CGEvent(scrollWheelEvent2Source:units:.pixel,...)`.

## Recommendations for the oculOS hand app

**Gesture set**

| Action | Gesture | Default |
|---|---|---|
| Engage (clutch on) | Open palm facing the camera, held briefly | 300 ms |
| Disengage (clutch off) | Fist, or hand out of frame | 200 ms |
| Move the cursor | Hover while engaged; cursor follows the anchor (index MCP, middle MCP and wrist centroid) | — |
| Left click | Thumb–index pinch, then release | enter < 0.25, exit > 0.40 hand-size, 2 frames at 30 fps |
| Drag | Keep the index pinch held and move past the slop distance | 12 pt |
| Right click | Thumb–middle pinch released within the tap limit | < 300 ms |
| Scroll | Thumb–middle pinch held and moved (both axes) | gain ~2–4× |
| Delay compensation | Roll the cursor back when a pinch starts | 100 ms |

**Pointer mapping**
- Default to absolute mapping of a central active box (~50–60% of the camera frame) to the screen, with a 1€ filter.
- Offer a "precision" relative mode with an acceleration curve like the trackpad's. There, the fist acts as the lift-and-reposition clutch.

**Validation and learned models**
- Reject frames where the joints in use have confidence < 0.3, or where the hand is edge-on. A foreshortened MCP spread relative to hand size is the sign of an edge-on hand.
- Add a Create ML pose classifier later, only for engage/disengage robustness, with a strong Background class.

**Ergonomics**
- Tell users to rest the elbow on the desk with the hand at chest height.

## Pitfalls

- **Unnormalized thresholds**, like the 40 pt in Apple's sample, stop working when the hand moves closer or farther from the camera.
- **Anchoring the cursor to the index tip** makes it jump at every pinch. Even the index MCP moves a little, so keep the freeze and rollback.
- **One threshold only** (no hysteresis) makes the pinch state flicker near the boundary and causes double clicks.
- **Right click and scroll can clash**, since both use the middle pinch. The tap-time limit and the slop distance must be strictly ordered.
- **Thumb self-occlusion:** when the thumb is behind the palm, a monocular 2D view can make it look like the fingers touch when they don't. Needs verification.
- **Lag:** the camera runs at 30 fps and Vision adds ~20–40 ms (unmeasured estimate). On top of that, each debounce frame adds ~33 ms, so keep the frame count at 2 or fewer.
- **Action classifier timing:** the frame rate must match training, and the fixed window makes it unusable for clicking.
- **No clutch means Midas touch:** a cursor that is always live ends up moving whenever the user gestures while talking.

## Sources (consulted)

- Apple WWDC20 "Detect Body and Hand Pose with Vision" (transcript): https://developer.apple.com/videos/play/wwdc2020/10653/
- Apple WWDC21 "Classify hand poses and actions with Create ML": https://developer.apple.com/videos/play/wwdc2021/10039
- MediaPipe Gesture Recognizer guide (search-result snippets only; the page was blocked): https://ai.google.dev/edge/mediapipe/solutions/vision/gesture_recognizer
- RingGesture, Heisenberg effect and adaptive exponential smoothing (search snippet): https://arxiv.org/pdf/2410.18100
- Direct vs. Score-based Selection: Understanding the Heisenberg effect (search snippet): https://cislab.hkust-gz.edu.cn/media/documents/Direct_vs__Score_based_crc.pdf
- MacKenzie et al., Push, Tap, Dwell, and Pinch (ISS 2022, search snippet): http://www.yorku.ca/mack/iss2022.html
- Consumed Endurance (CHI 2014): https://hci.cs.umanitoba.ca/assets/publication_files/Consumed_Endurance_-_CHI_2014.pdf ; NICER: https://arxiv.org/html/2406.08875
- $1 recognizer: https://faculty.washington.edu/wobbrock/pubs/uist-07.01.pdf ; $P: https://depts.washington.edu/acelab/proj/dollar/pdollar.html
- Midair object pointing mappings (positional, rate, hybrid): https://dl.acm.org/doi/pdf/10.1145/3488535
- Summon and Select (ISS 2017): https://www.cs.toronto.edu/~aakar/Publications/Summon-ISS17.pdf
- Vogel & Balakrishnan, Distant Freehand Pointing and Clicking (UIST 2005; blocked, cited from memory for AirTap and ThumbTrigger): https://www.dgp.toronto.edu/~ravin/papers/uist2005_distantpointing.pdf

Access note: the proxy blocked arxiv.org, ai.google.dev, yorku.ca and dgp.toronto.edu. Claims from those sources come from search snippets and are not fully verified.
