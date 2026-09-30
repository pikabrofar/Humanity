# 06 · Camera-based hand tracking for desktop control

## TL;DR

- **Start with Apple Vision `VNDetectHumanHandPoseRequest`** (macOS 11+, chirality macOS 12+). It gives 21 2D joints with per-joint confidence, needs no model files, and matches GazeKit's Vision-only approach. The Swift-native `DetectHumanHandPoseRequest` needs macOS 15, so it only fits if we raise the macOS 14 floor.
- **Vision gives 2D only.** It has no z. MediaPipe Hand Landmarker gives 21 landmarks with relative depth plus metric "world" landmarks, but Google ships Tasks for iOS through CocoaPods, not as a supported native macOS Swift package. The workable route is converting the TFLite models to Core ML (already done by third parties; see below).
- **Heavy 3D mesh models are now possible on Apple Silicon but not needed.** FastHaMeR claims about 30 FPS for two hands on an M4 MacBook Air (ANE, 6-bit weights), but MANO weights are licensed for non-commercial use only. That is a bad fit for an MIT app.
- **Robustness is decided by the interaction design more than by the model.** Recognise gestures from ratios normalised by palm size, add hysteresis (N-frame evidence), smooth with a 1€ filter, and map a small "interaction box" in the camera frame to the whole screen so the user never has to reach the frame edges.
- **Laptop webcams are badly placed for hand control.** The camera sits at lid height and points at the face, so the hand has to be raised ("gorilla arm"), and a palm facing the camera is a documented weak pose. An external or Continuity Camera placed lower helps a lot.

## Key findings

**Apple Vision (VN API).**
- `VNDetectHumanHandPoseRequest` returns `VNHumanHandPoseObservation`. Its 21 joints are wrist, then thumb CMC/MP/IP/TIP, then MCP/PIP/DIP/TIP for the index, middle, ring and little fingers.
- Joint group names: `.thumb`, `.indexFinger`, `.middleFinger`, `.ringFinger`, `.littleFinger`, `.all`.
- Each point is a `VNRecognizedPoint` with a normalized `location` (origin at **lower-left**) and a `confidence`.
- `maximumHandCount` defaults to 2. Vision orders detected hands by size, computes keypoints only for the largest ones, and latency grows with each extra hand. Set it to 1 for a pointer.
- `chirality` (`.left` / `.right` / `.unknown`) was added in macOS 12.
- Limitations named by Apple (WWDC20): hands near the frame edges or partly occluded, hands held parallel to the camera (palm facing the lens), gloves, and feet mistaken for hands.
- Apple's own demo drops points with confidence ≤ 0.3 and uses a 3-frame evidence counter before switching pinch state.
- Apple suggests `VNTrackObjectRequest` for keeping track of a hand's location and identity across frames.
- Latency: one community project (AirMac) claims under 10 ms per frame on Apple Silicon. **This is unverified, and Apple publishes no numbers.**

**Apple Vision (Swift API, WWDC24).**
- `DetectHumanHandPoseRequest` is a value type called with `try await request.perform(on:)`. It returns `[HumanHandPoseObservation]` with `JointName` cases such as `.indexTip` and `.thumbTip`, plus `chirality` and `keypoints`.
- It requires **macOS 15**.

**MediaPipe Hands / Hand Landmarker.**
- It is a two-stage pipeline. A palm detector (BlazePalm, 95.7% average precision) scans the full frame, then a landmark model runs on the crop and outputs 21 landmarks. In those landmarks x and y are normalized, and z is depth relative to the wrist (smaller means nearer the camera, roughly on the same scale as x).
- It also outputs world landmarks in metres, centred on the hand, and handedness.
- Crops for the next frame come from the previous frame's landmarks, so the detector only runs again when tracking is lost. That is the key saving.
- Handedness assumes a **mirrored** selfie image.
- Latency of the full landmark model (1.98M parameters): about 5.3 ms on iPhone 11 and 16 ms on Pixel 3.
- The model card reports a fairness evaluation across 6 skin-tone types. The quoted figure is the lite model's error, 5.67% ± 7.25% (MNAE, normalised by palm size) across types. I could not parse the PDF myself, so **treat the exact numbers as unverified**.
- For macOS use: the MediaPipeTasksVision pods target iOS, and GitHub issues show repeated macOS packaging problems. The pragmatic path is a Core ML port. The "fasthands" project (MediaPipe Hands on Core ML) claims about 1 ms per frame. **Unverified.**

**Other models.**
- RTMPose / RTMW (OpenMMLab) run fast on desktop GPUs and CPUs, for example RTMPose-m at 90+ FPS on an i7 through ONNX Runtime. They are whole-body or top-down models and would need their own detector plus a Core ML conversion. They offer little over Vision for a single hand.
- HaMeR (ViT-H, MANO mesh) is about 16 FPS on an A800 in stock Python. The FastHaMeR Core ML port is about 30 FPS on an M4. Both are overkill and have licensing problems.

**Depth from monocular 2D.**
- Apparent palm length (wrist to middle MCP, in pixels) is roughly inversely proportional to distance.
- An adult palm is about 9–11 cm long (anthropometric, approximate), which gives a rough z after a one-time calibration.
- The same ratio is the right normaliser for pinch thresholds. It is more robust than raw pixel distance, which changes as the hand moves toward or away from the camera.

## How to program it

This fits the existing `CameraCapture.onFrame` (420f buffers on a serial queue). On macOS the frames are already `.up`.

```swift
import Vision
import CoreGraphics

public struct HandFrame: Sendable {
    public var joints: [VNHumanHandPoseObservation.JointName: CGPoint] // normalized, top-left origin, mirrored
    public var confidence: [VNHumanHandPoseObservation.JointName: Float]
    public var chirality: VNChirality
    public var palmSize: CGFloat          // |wrist - middleMCP|, normalized units
    public var timestamp: TimeInterval
}

public final class HandPoseDetector: @unchecked Sendable {
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1            // one pointer hand = lowest latency
        return r
    }()
    private let minConfidence: Float = 0.3
    public var mirror = true              // selfie view; set false if connection.isVideoMirrored

    public func process(_ buffer: CVPixelBuffer, time: TimeInterval) -> HandFrame? {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        guard let obs = request.results?.first,
              let pts = try? obs.recognizedPoints(.all) else { return nil }

        var joints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
        var conf: [VNHumanHandPoseObservation.JointName: Float] = [:]
        for (name, p) in pts where p.confidence >= minConfidence {
            // Vision: normalized, origin lower-left. Convert to top-left and mirror x.
            let x = mirror ? 1 - p.location.x : p.location.x
            joints[name] = CGPoint(x: x, y: 1 - p.location.y)
            conf[name] = p.confidence
        }
        guard let w = joints[.wrist], let m = joints[.middleMCP] else { return nil }
        let palm = hypot(w.x - m.x, w.y - m.y)
        return HandFrame(joints: joints, confidence: conf, chirality: obs.chirality,
                         palmSize: palm, timestamp: time)
    }
}

/// Map a sub-rectangle of the camera frame ("interaction box") to a display,
/// so the user never has to reach the frame edges (where Vision degrades).
public func screenPoint(_ p: CGPoint, box: CGRect = CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.55),
                        display: CGDirectDisplayID = CGMainDisplayID()) -> CGPoint {
    let b = CGDisplayBounds(display)                // global, top-left origin (CGEvent space)
    let u = min(max((p.x - box.minX) / box.width, 0), 1)
    let v = min(max((p.y - box.minY) / box.height, 0), 1)
    return CGPoint(x: b.minX + u * b.width, y: b.minY + v * b.height)
}

/// Pinch = thumbTip–indexTip distance relative to palm size, with hysteresis.
public struct PinchDetector {
    var isPinched = false, count = 0
    let on: CGFloat = 0.25, off: CGFloat = 0.40, frames = 3
    public mutating func update(_ f: HandFrame) -> Bool {
        guard let t = f.joints[.thumbTip], let i = f.joints[.indexTip], f.palmSize > 0 else { return isPinched }
        let r = hypot(t.x - i.x, t.y - i.y) / f.palmSize
        let want = isPinched ? r < off : r < on
        count = (want != isPinched) ? count + 1 : 0
        if count >= frames { isPinched = want; count = 0 }
        return isPinched
    }
}
```

Notes on the snippet:
- The pointer should use a stable joint, such as `indexMCP` or the centre of the palm, run through a 1€ filter. Do not use `indexTip`, which moves when you pinch.
- The on/off pinch thresholds (0.25 and 0.40) are starting guesses and need tuning.
- The macOS 15 Swift API equivalent (unverified signatures) is `let obs = try await DetectHumanHandPoseRequest().perform(on: buffer)` followed by `obs.first?.joint(for: .indexTip)`.

## Recommendations for the planned oculOS hand app

- **Create a `HandKit` library that mirrors GazeKit.** Reuse or share `CameraCapture`, but choose a 720p preset. Hands are large in the frame, and 1080p only adds latency. The pipeline would be `HandPoseDetector`, then `HandFilter` (1€ filter per joint), then `GestureRecognizer` (point, pinch, drag, two-finger scroll, all state machines with hysteresis), then `PointerDriver` (CGEvent move, click and scroll, which needs Accessibility permission).
- **Keep the detector behind a protocol,** for example `HandPoseProvider`. The Vision backend is the default, and a Core ML MediaPipe backend can be added later if we need z for push-to-click or better palm-facing poses.
- **ROI tracking:** set `request.regionOfInterest` to the previous hand's bounding box expanded by about 1.5x, and fall back to the full frame after any miss. **Uncertain:** whether this saves time inside Vision needs profiling. It does cut false positives from faces and feet.
- **Use relative mode** (hand motion = cursor velocity, like a trackpad) alongside the absolute interaction box. Add a clutch gesture (open palm to pause) and an auto-disengage when the hand leaves the frame. Offer gaze plus pinch (gaze from VisionGaze, pinch to click) as a combined mode.
- **Run at the camera rate** (30 FPS) on the capture queue. Drop frames rather than queueing them, which `alwaysDiscardsLateVideoFrames` already does.

## Pitfalls

- **Coordinate flips.** Vision puts the origin at the lower-left, while CGEvent and AppKit screen coordinates differ from each other (top-left global versus bottom-left). If `isVideoMirrored` is set on the connection, do not mirror again. **Unverified:** whether Vision's chirality refers to the physical hand in an unmirrored frame. Verify empirically.
- **Palm facing the camera, edges and self-occlusion** (thumb behind the palm during a pinch) cause joints to drop out or jump. Gate on per-joint confidence, and hold the last state rather than emitting clicks.
- **Gorilla arm.** Sessions with a raised hand tire the user within minutes. Keep gestures small, allow an elbow-on-desk posture, and make the interaction box configurable.
- **Clicks cause cursor jitter.** Freeze or damp the cursor for about 100–150 ms around the moment a pinch starts.
- **Lighting, background clutter, skin tone.** Low light raises confidence dropouts. Faces and arms nearby can be picked up as hands. Test across skin tones, since only MediaPipe publishes a fairness evaluation and Apple publishes none.
- **Licensing.** MANO/HaMeR weights are non-commercial only. MediaPipe models are Apache-2.0.

## Sources

- https://developer.apple.com/videos/play/wwdc2020/10653/
- https://developer.apple.com/videos/play/wwdc2024/10163/
- https://developer.apple.com/documentation/vision/vnhumanhandposeobservation (JSON: availability, chirality macOS 12)
- https://developer.apple.com/documentation/vision/detecthumanhandposerequest (macOS 15)
- https://developer.apple.com/documentation/vision/humanhandposeobservation/jointname
- https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest/maximumhandcount
- https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/hands.md
- https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Hand%20Tracking%20(Lite_Full)%20with%20Fairness%20Oct%202021.pdf (via search summary)
- https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/ios (via search summary)
- https://github.com/google-ai-edge/mediapipe/issues/5264, /issues/5143 (macOS packaging problems)
- https://github.com/VimalMollyn/fasterhamer
- https://github.com/NeeliSaiHakesh/AirMac
- https://github.com/open-mmlab/mmpose/tree/main/projects/rtmpose ; https://arxiv.org/pdf/2405.20330 (OmniHands FPS, via search)
