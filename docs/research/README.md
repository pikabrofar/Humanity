# Camera eye and hand tracking research

Thirty research reports on webcam eye and hand tracking and how to program it
for oculOS. Reports 01–10 were written by ten research agents working in
parallel (10-minute limit each), and reports 11–30 by twenty more (5-minute
limit each, so they are shorter). Each covers one topic. Every report has a
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

### Second round (reports 11–30, 5-minute agents)

| # | Report | One-line takeaway |
|---|---|---|
| 11 | [Camera hardware](11-camera-hardware.md) | Built-in cameras are tuned for calls. Continuity Camera gives 60 fps but no depth. Center Stage must be off. USB webcams rarely allow locking exposure. |
| 12 | [Lighting, glasses, demographics](12-lighting-glasses-robustness.md) | Glasses are the biggest error factor, and makeup/lids fool the darkest-pixel refiner. Ship a quality score with specific hints and pause when it's low. |
| 13 | [Synthetic training data](13-synthetic-training-data.md) | Most synthetic datasets are non-commercial too. Our own Blender + CC0 pipeline is the only licence-clean route. Accuracy still comes from calibration. |
| 14 | [On-device personalization](14-on-device-personalization.md) | Closed-form ridge on Accelerate beats gradient training for calibration. `MLUpdateTask` works for last-layer fine-tuning only. Create ML allows custom hand poses. |
| 15 | [Head pointer](15-head-pointer.md) | Relative nose-offset pointer with dead zone and acceleration. More precise than gaze. Gaze for the coarse jump, head for the fine correction. |
| 16 | [Facial-gesture triggers](16-facial-gesture-triggers.md) | Mouth-open and brow-raise from 2D landmarks, with per-user range, hysteresis, hold time, and refractory period. Speech causes false triggers. |
| 17 | [Dwell and accessibility](17-dwell-accessibility.md) | Adjustable dwell (novice about 1 s, experts about 300 ms), progress ring, big targets or two-step zoom, pause area, word prediction or Dasher. |
| 18 | [Reading detection and gaze scrolling](18-reading-gaze-scrolling.md) | Detect reading from return sweeps (robust at 2–4°). Ship gaze Page Down first. Continuous scroll keeps eyes in the middle third. |
| 19 | [Two-hand and dynamic gestures](19-bimanual-dynamic-gestures.md) | Two-hand zoom/rotate is geometry. Velocity-gated swipes map to Spaces shortcuts. $Q/DTW for custom gestures later. Synthetic magnify is fragile. |
| 20 | [Tracking several faces and hands](20-multi-target-tracking.md) | Pick the primary user once, keep them by IoU. `VNTrackObjectRequest` between detections. Link hands to the user by geometry. Hand over eyes = invalid gaze. |
| 21 | [Privacy and legal](21-privacy-legal.md) | Gaze reveals health and identity. Never store frames. Persist only opt-in gaze points. GDPR, BIPA, and Apple 5.1.2 notes (not legal advice). |
| 22 | [Energy and thermal](22-energy-performance.md) | Cost = frames × pixels × requests. Drop to 2–5 fps when idle. Respond to thermal state and Low Power Mode. Measure with signposts and powermetrics. |
| 23 | [Swift 6 concurrency pipeline](23-swift-concurrency-pipeline.md) | An actor on the capture queue (custom executor), `AsyncStream(.bufferingNewest(1))`, a wrapper only at the hand-off, and a display link pulling results. |
| 24 | [CI on GitHub Actions](24-ci-github-actions.md) | macOS runners are free on public repos. Pin `macos-15`/`macos-26` (14 retires 2026-11-02). No camera or TCC in CI. Includes a ready `ci.yml`. |
| 25 | [Distribution and notarization](25-distribution-notarization.md) | Developer ID + hardened runtime + notarize/staple the DMG. Sparkle 2 for updates. Homebrew now blocks casks that fail Gatekeeper. No App Store. |
| 26 | [Gaze analytics and AOIs](26-gaze-analytics.md) | TTFF, dwell, visits, and fixation count per AOI. Heatmap σ in degrees from measured accuracy. Few large AOIs. Levenshtein for scanpaths. |
| 27 | [Voice + gaze](27-voice-gaze.md) | Talon model: gaze points, a "pop" sound clicks (SoundAnalysis). Use gaze from speech onset (the eyes lead by about 630 ms). SpeechAnalyzer on macOS 26. |
| 28 | [Head-pose models](28-head-pose-models.md) | 6DRepNet (MIT) at about 4° MAE, rotation only. PnP on Vision landmarks for 6-DoF. Vision's angles are coarse. img2pose and FLAME are non-commercial. |
| 29 | [Eye gestures and fatigue](29-eye-gestures-fatigue.md) | Long blink ≥ 600 ms as a command, optional calibrated winks, relative gaze strokes, PERCLOS P80 over 60 s, and 20-20-20 reminders. |
| 30 | [Accessibility API targets](30-accessibility-api-targets.md) | Hit test plus walk up to an actionable parent. Scan the focused window once and cache. Batch attributes, short timeouts, `AXManualAccessibility` for Electron. |

### Improvement plan

| # | Report | One-line takeaway |
|---|---|---|
| 31 | [Improvement plan](31-improvement-plan.md) | Prioritized, file:line-backed plan for the current system: fix 4 correctness bugs first, then roll handling, drift layer, time-based smoothing, pupil refinement; CI, replay tests, and first hand-app steps. Six milestones. |

Reviews of the code and of these reports are in [../reviews](../reviews/).

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
