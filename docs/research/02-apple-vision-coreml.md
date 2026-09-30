# 02 — Apple on-device vision stack (Vision, Core ML, AVFoundation) for oculOS

*Research note, 2026-09-30. Scope: face/eye/hand tracking on macOS with a single webcam, and performance.*

## TL;DR

- **Vision covers everything oculOS needs natively**: 76-pt face landmarks with pupils (rev 3), head pose (face rectangles rev 3), 21-joint hand pose with chirality, and body pose that can include hands. No ARKit face tracking on macOS, so there is no `lookAtPoint` or blendshapes. Gaze has to be built the way VisionGaze already does it.
- **One frame, one handler, many requests.** Run face rects, landmarks, hand pose, and an optional `VNCoreMLRequest` on the same `VNImageRequestHandler` (or the Swift `ImageRequestHandler`) so they share the image preparation work. GazeKit already does this for the CNN.
- **The Swift-concurrency Vision API** (macOS 15+, WWDC24: `DetectFaceLandmarksRequest`, `DetectHumanHandPoseRequest`, `handler.perform(a, b)`) is cleaner, and Apple says new features ship only there. oculOS targets macOS 14, so keep the `VN*` path and add the new one behind `if #available(macOS 15, *)`.
- **Core ML**: convert to `mlprogram` with coremltools, try `.cpuAndNeuralEngine`, quantize weights to 8 bits or palettize them, and check where each op runs with `MLComputePlan` (macOS 14.4+) or the Xcode Performance Report.
- **The camera is the biggest latency and robustness risk**: turn Reactions gestures off (thumbs-up and similar poses trigger system effects, which is a direct conflict for a hand-gesture app), keep Center Stage off, drop late frames, and prefer 720p at a fixed frame rate over 1080p.

## Key findings

**Face / eyes.**
- `VNDetectFaceLandmarksRequestRevision3` gives the 76-point constellation (`.constellation76Points`) including `leftPupil` and `rightPupil`. Each point comes with a precision estimate (`precisionEstimatesPerPoint`).
- Landmark observations do not carry pose. Rev 3 `VNDetectFaceRectanglesRequest` gives `yaw`, `pitch`, and `roll`. GazeKit already combines the two.
- Pupil landmarks are regressed from face appearance. In practice they are biased toward the eye center and jitter by a few pixels. That is why `PupilRefiner` exists. No official accuracy figures are published (*uncertain; none found*).
- `VNDetectFaceCaptureQualityRequest` scores frames from 0 to 1. It is cheap and useful for skipping blurred frames during calibration.

**ARKit.**
- `ARFaceTrackingConfiguration` (`ARFaceAnchor.lookAtPoint`, `leftEyeTransform`, 52 blendshapes) runs only on iOS/iPadOS, on TrueDepth or A12+ devices. It is not available on macOS.
- Continuity Camera (iPhone as webcam) shows up on the Mac as a plain `AVCaptureDevice`. Depth and ARKit data are *not* passed through (*to my knowledge; not verified this session*).

**Hands.**
- `VNDetectHumanHandPoseRequest` returns 21 joints: wrist, plus 4 each for the thumb (CMC/MP/IP/TIP) and every finger (MCP/PIP/DIP/TIP). Each joint has a confidence value, and each hand has `chirality` (macOS 12+).
- `maximumHandCount` defaults to 2. Latency grows with every hand, so set it to 1 for cursor control.
- Apple lists these known failure cases: hands at frame edges, hands edge-on to the camera ("karate chop"), gloves, and feet mistaken for hands.
- Apple's pinch sample uses a thumb-tip to index-tip distance under 40 px, requires 3 consecutive frames before committing, and ignores joints with confidence ≤ 0.3.
- On Apple Silicon, hand pose runs in about 10 ms or less per frame (*third-party claim, not benchmarked*).

**Body.**
- In the new API, `DetectHumanBodyPoseRequest.detectsHands = true` returns body pose with `leftHandObservation` / `rightHandObservation` attached. This is the "holistic" pose added at WWDC24, and it links each hand to a person and a side.

**New Swift API (macOS 15+).**
- The new API drops the `VN` prefix, is async, and returns `Sendable` observations.
- `perform(r1, r2)` waits for all requests. `performAll(...)` streams results as each request finishes.
- `toImageCoordinates(imageSize:origin:)` converts normalized points to pixels.
- `supportedComputeDevices()` lists the devices a request can run on.
- Apple advises limiting how many Vision requests run at once, because of memory use.
- WWDC26 ("What's new in image understanding") added nothing for face, hand, or pose. It covered tap-to-segment, Foundation Models image input, and watchOS.

**Core ML.**
- `VNCoreMLRequest` handles scaling, cropping, `regionOfInterest`, and orientation for you.
- Calling `MLModel.prediction` directly avoids Vision overhead and gives full control of the input, which suits models that take multiple inputs, such as an eye patch plus head pose.
- Compute-unit selection (`computeUnits`) is a hint, not a guarantee. Ops the Neural Engine (ANE) cannot run fall back to GPU or CPU, and each switch between devices costs time.

## How to program it

**Combined face + hand pipeline on one frame (macOS 14-compatible):**

```swift
final class FramePipeline {
    private let faceRects = VNDetectFaceRectanglesRequest()
    private let landmarks = VNDetectFaceLandmarksRequest()
    private let hands = VNDetectHumanHandPoseRequest()
    private let quality = VNDetectFaceCaptureQualityRequest()

    init() {
        faceRects.revision = VNDetectFaceRectanglesRequestRevision3
        landmarks.revision = VNDetectFaceLandmarksRequestRevision3
        landmarks.constellation = .constellation76Points
        hands.maximumHandCount = 1
    }

    // Called on the capture queue; reuse request objects across frames.
    func process(_ pb: CVPixelBuffer) throws -> (VNFaceObservation?, VNHumanHandPoseObservation?) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up, options: [:])
        try handler.perform([faceRects, hands])            // one pass, shared image prep
        if let face = faceRects.results?.first {
            landmarks.inputFaceObservations = [face]        // skip re-detection; keeps yaw/pitch/roll
            try handler.perform([landmarks])
        }
        let hand = hands.results?.first
        if let tip = try? hand?.recognizedPoint(.indexTip), tip.confidence > 0.3 { /* cursor */ }
        return (landmarks.results?.first, hand)
    }
}
```

**The same work with the Swift API (macOS 15+):**

```swift
if #available(macOS 15, *) {
    let handler = ImageRequestHandler(pixelBuffer)
    var hand = DetectHumanHandPoseRequest(); hand.maximumHandCount = 1
    let (faces, handObs) = try await handler.perform(DetectFaceLandmarksRequest(), hand)
}
```

**Capture tuning:**

```swift
AVCaptureDevice.centerStageControlMode = .app        // take control from Control Center
AVCaptureDevice.isCenterStageEnabled = false         // cropping/zoom breaks the geometric model
try device.lockForConfiguration()
device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30) // fixed fps, no low-light slowdown
device.unlockForConfiguration()
output.alwaysDiscardsLateVideoFrames = true
output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] // native; luma plane for PupilRefiner
```

In Info.plist, set `NSCameraReactionEffectGesturesEnabledDefault = false` (macOS 14.4+). Portrait, Studio Light, and background effects are user-controlled. You can read them (`AVCaptureDevice.isPortraitEffectEnabled`, `isStudioLightEnabled`) and send the user to the system panel with `AVCaptureDevice.showSystemUserInterface(.videoEffects)`.

**Core ML conversion:**

```python
import torch, coremltools as ct, coremltools.optimize.coreml as cto
traced = torch.jit.trace(model.eval(), torch.rand(1, 3, 448, 448))
ml = ct.convert(traced, convert_to="mlprogram",
                inputs=[ct.ImageType(name="image", shape=(1, 3, 448, 448),
                                     scale=1/255.0, color_layout=ct.colorlayout.RGB)],
                compute_precision=ct.precision.FLOAT16,
                minimum_deployment_target=ct.target.macOS14)
cfg = cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric"))
ml = cto.linear_quantize_weights(ml, config=cfg)   # or cto.palettize_weights(nbits=6)
ml.save("L2CS.mlpackage")
```

Precompile the model with `xcrun coremlcompiler compile L2CS.mlpackage out/`, then profile it in Xcode (open the model, then Performance → *Create Report*). Alternatively, use `MLComputePlan.load(contentsOf:configuration:)` and `plan.deviceUsage(for:)` to list any ops that fall back from the ANE.

## Recommendations for oculOS

1. **Build a shared `FrameHub` in GazeKit.** `CameraCapture` should hand out one `CVPixelBuffer` per frame, and a single `VNImageRequestHandler` should serve `FaceFeatureExtractor`, the future hand app, and `GazeNetwork` (which already takes a `handler`). Don't give each app its own `AVCaptureSession`, because two sessions on one camera will fight each other.
2. **Pass the face rectangle into landmarks.** In `FaceFeatureExtractor`, set `landmarks.inputFaceObservations = [poseResult]` so the face is detected once per frame, not twice. Measure the result before and after.
3. **Change the camera defaults.** `CameraCapture` currently tries 1080p first. For hands, 720p at a locked 30 fps (60 fps where the camera supports it) is probably enough and cuts Vision time. Keep 1080p optional for the eye tracker, where pupil pixels matter (*trade-off needs measurement*). Lock Center Stage off, and lock exposure/white balance after calibration if the camera allows it.
4. **Disable Reactions in both apps' Info.plist.** For the gesture app this is a correctness issue: thumbs-up, peace sign, and two-hand hearts trigger the system effects.
5. **Build the gesture state machine like Apple's pinch sample**, then improve on it.
   - Normalize the thumb–index distance by hand size (wrist → middle MCP), not raw pixels.
   - Add hysteresis: separate enter and exit thresholds.
   - Require roughly 3 frames of agreement before committing.
   - Smooth the cursor with a One-Euro filter. `FixationStabilizer` fits eyes, not hands.
6. **Core ML hygiene.** In `GazeNetwork`, try `.cpuAndNeuralEngine` against `.all` and keep whichever is faster. Ship a W8 or 6-bit palettized `.mlpackage`, and precompile it in the bundle so first launch doesn't have to compile it (`MLModel.compileModel` is already called at runtime). Run the CNN every other frame if the frame budget is tight.
7. **Latency budget (target under 50 ms from photon to cursor at 30 fps):** capture about 33 ms, then Vision face + landmarks + hand ≤ 15 ms, CNN ≤ 5 ms, filtering ≤ 1 ms, and cursor post ≤ 1 ms. Log per-stage timings with `os_signpost` and check them in Instruments.
8. **Adopt the macOS 15 API** only where a feature needs it, such as holistic body+hand pose for assigning hands to users. Otherwise keep the `VN*` API for the macOS 14 floor.

## Pitfalls

- **Coordinates.** Vision uses normalized coordinates with the origin at the lower left. Front cameras are mirrored for display, but buffers from `AVCaptureVideoDataOutput` are not. Convert to screen space in exactly one place.
- **Don't retain buffers.** Holding a `CVPixelBuffer` past the capture callback drains the pool and stalls capture. Do Vision work synchronously on the capture queue, or copy what you need.
- **Default revisions change with the SDK.** Pin `revision` explicitly, as GazeKit already does.
- **Frame rate drops in low light.** Auto-exposure lowers fps unless the minimum/maximum frame durations are locked.
- **Center Stage** crops and zooms, which breaks the pinhole head-position model and the calibration.
- **Portrait blur** can blur the face edges. Its effect on landmarks is *unverified*.
- **Some external webcams report odd formats**, and Studio Display cameras sometimes stop producing frames (reported by nonstrict.eu). Add a watchdog that restarts the session.
- **The Reactions plist default can be overridden** by the user's own per-app choice, and one report says it did not take effect in multi-process apps.
- **Hand pose is weak for edge-on hands**, which is exactly the pose people use for a "point". Ask users to point with the palm partly facing the camera.
- **The ANE falls back silently** on unsupported ops or dynamic shapes. Use fixed input shapes.

## Sources

- https://developer.apple.com/videos/play/wwdc2024/10163/ — Discover Swift enhancements in the Vision framework
- https://developer.apple.com/videos/play/wwdc2020/10653/ — Detect Body and Hand Pose with Vision
- https://developer.apple.com/videos/play/wwdc2026/237/ — What's new in image understanding
- https://developer.apple.com/videos/play/wwdc2024/10161/ — Deploy models on-device with Core ML
- https://developer.apple.com/videos/play/wwdc2023/10047/ — Core ML Tools model compression
- https://github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS13.0.sdk/System/Library/Frameworks/Vision.framework/Headers/VNDetectFaceLandmarksRequest.h
- https://developer.apple.com/documentation/avfoundation/avcapturedevice/3738418-centerstagecontrolmode
- https://developer.apple.com/documentation/avfoundation/avcapturedevice/reactioneffectgesturesenabled
- https://developer.apple.com/forums/thread/763369 — Reactions plist default issue
- https://github.com/obsproject/obs-studio/pull/11652 — OBS disabling Reactions via Info.plist
- https://developer.apple.com/tutorials/data/documentation/arkit/arfacetrackingconfiguration.md
- https://github.com/freedomtan/coreml_modelc_profling — MLComputePlan per-op profiling
- https://blakecrosley.com/blog/vision-framework-built-in — latency claims (third-party)
- https://nonstrict.eu/blog/2025/studio-display-camera-fails/
