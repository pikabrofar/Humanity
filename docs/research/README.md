# Camera eye and hand tracking research

Ten research reports on webcam eye and hand tracking and how to program it
for oculOS. Each was written by one of ten research agents working in parallel,
with a 10-minute limit per agent, and each covers one topic. Every report has a
TL;DR, key findings, code (Swift or pseudocode), recommendations for oculOS,
pitfalls, and sources.

Some sources (arXiv, some university and Google pages) were blocked during the
research. Claims taken only from search summaries are marked *(unverified)* or
*(?)* in each report. Check those before relying on them. The Swift snippets
have not been compiled.

## Reports

| # | Report | One-line takeaway |
|---|---|---|
| 01 | [Gaze estimation: state of the art](01-gaze-estimation-sota.md) | Without calibration, even 2025 foundation models manage only 4–7° on datasets they weren't trained on, so per-user correction matters more than the model. Nearly all datasets and weights are non-commercial. |
| 02 | [Apple Vision and Core ML on macOS](02-apple-vision-coreml.md) | One `VNImageRequestHandler` per frame serves face, hand, and CNN requests. Turn off Reactions and Center Stage. Use the macOS 15 Swift Vision API behind `#available`. |
| 03 | [Pupil and iris detection](03-pupil-iris-detection.md) | Webcams track the iris, not the pupil, and 1° of gaze is about 0.4 px. Gradient voting plus a limbus circle fit, and an 11.7 mm iris for distance. |
| 04 | [Calibration and head pose](04-calibration-head-pose.md) | VisionGaze's hybrid model is the right family. Gaps: head rotation is additive not rotational, roll isn't restored, and there's no PnP, drift layer, or multi-monitor support. |
| 05 | [Filtering and eye-movement detection](05-filtering-event-detection.md) | One Euro filter for the hand pointer. Hold-and-jump for gaze. Adaptive I-VT. Budget latency in ms, not samples. |
| 06 | [Hand tracking](06-hand-tracking.md) | Start with Vision's 21-joint hand pose (2D). Use a MediaPipe Core ML port if depth is needed. Map an "interaction box" to the screen. |
| 07 | [Gesture recognition and interaction](07-gesture-recognition.md) | Rules plus hysteresis, not ML, for pinch/point/scroll. Normalize by hand size. Anchor on the index MCP. Freeze the cursor on pinch. Add a clutch gesture. |
| 08 | [macOS input integration](08-macos-input-integration.md) | `CGEvent` with the Post Event permission. Stable code signing so TCC grants survive rebuilds. Top-left global coordinates. Pixel scroll events with no phase fields. |
| 09 | [Multimodal gaze + hand](09-multimodal-gaze-hand.md) | Gaze picks the target and the hand commits. Snap to Accessibility elements. Use gaze from about 100–150 ms before the pinch. Hide the raw gaze cursor. |
| 10 | [Landscape and evaluation](10-landscape-evaluation.md) | Webcam trackers cluster at 1.5–4°, so interaction design is what sets them apart. Report accuracy, precision, and data loss, plus Fitts throughput. Replay feature streams in CI. |

## Themes across the reports

1. **Accuracy is capped; interaction design is not.** Webcam gaze tops out
   around 1.5–4° (01, 03, 10), and VisionGaze is already in that range. Big
   gains now come from snapping to real UI targets through the Accessibility
   tree (05, 08, 09), coarse-gaze/fine-hand cascades (MAGIC pointing), and
   feedback design, not from a bigger model.
2. **Personalize instead of generalizing.** A per-user linear or affine
   correction on a few samples beats swapping backbones (01, 04). Keep it as a
   separate, time-decayed drift layer instead of refitting the whole model on
   every click (04).
3. **Licenses are a hard constraint.** MPIIGaze, ETH-XGaze, Gaze360,
   GazeCapture, UniGaze weights, MANO/HaMeR, OpenFace 2.0 and WebGazer (GPL)
   can't ship in an MIT repo (01, 06, 10). Use them for local benchmarking at
   most.
4. **Stay on Apple Vision.** Face landmarks, head pose and 21-joint hands all
   come from Vision on one shared frame (02, 06). MediaPipe (iris landmarks,
   blendshapes, 3D hand) is an optional Core ML add-on, not a dependency
   (03, 06).
5. **Timing bugs matter more than position bugs.** Pinches land about 100 ms
   after the eyes have moved on (09), pinching moves the fingertip that drives
   the cursor (07), and every confirmation stage adds lag (05). Keep a short
   timestamped history of gaze and cursor positions and look back in it when
   a click happens.
6. **Hand control needs a clutch.** Without an explicit engage/disengage state,
   every hand movement moves the cursor, which is the Midas touch problem
   (07, 09). Laptop webcam placement makes gorilla arm a real problem, so keep
   gestures low and use gain (06, 07).

## Suggested roadmap

**VisionGaze fixes (small, high value)**
- Rotate the gaze vector by head roll and treat head rotation as a rotation,
  not additive yaw/pitch terms (04).
- Replace full-model click refits with a time-decayed offset/affine drift
  layer (04).
- Add STD precision, data-loss %, and per-region accuracy to the calibration
  report (04, 10).
- Make the `FixationStabilizer` radius depend on measured precision and use
  timestamps instead of sample counts (05).
- Straighten and rescale face crops (Zhang et al. 2018) before the CNN or ridge
  model (01, 04).
- Refine the pupil estimate with gradients and an iris circle fit, and apply
  CLAHE contrast normalization (03).

**New shared infrastructure**
- A shared camera/frame service so gaze and hand run on one `AVCaptureSession`
  and one Vision handler (02).
- A shared `InputKit` module: `MouseInjector` (move, click, drag, scroll),
  permission checks, coordinate conversion, and a stable signing identity
  (08).
- A regression suite that replays recorded `GazeFeatures` streams in
  `swift test`, plus an in-app Fitts' law benchmark (10).

**Hand-gesture app (`HandKit` + app, mirroring GazeKit)**
1. Vision hand pose → One Euro filter on the index MCP → interaction-box
   mapping to the screen (05, 06).
2. Gesture state machine: engage/disengage clutch, pinch with hysteresis
   (starting values: enter < 0.25, exit > 0.40 hand-size units, to be tuned),
   a cursor that freezes and rolls back 100 ms on pinch, drag, pinch-drag
   scroll, and right-click (07).
3. Disable Reactions in Info.plist so hand poses don't trigger system effects
   (02).

**Gaze + hand (later)**
1. MAGIC-style: gaze warps the cursor, and the hand refines it (09).
2. Gaze + pinch with Accessibility-tree snapping and a lookback to gaze
   ~100–150 ms before the pinch (09).
3. Gaze-aware scrolling, a dwell mode for accessibility, and privacy rules
   (gaze stays in-process and is never logged by default) (09).
