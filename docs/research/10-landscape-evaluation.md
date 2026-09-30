# 10 — Landscape of webcam eye/hand tracking, and how to evaluate it

## TL;DR

- Webcam gaze trackers cluster around **1.5–4° accuracy**: Eyeware Beam claims 1.5° in ideal conditions; WebGazer is about 100 px. VisionGaze's stated 2–4° is normal for the category. What sets a product apart is **interaction design** (snapping, zoom, dwell, head fusion), not raw accuracy.
- The permissively licensed prior art oculOS can borrow ideas or code from: **EyeTrax (MIT)**, **GazeTracking (MIT)**, **OpenSeeFace (BSD-2)**, **Precision Gaze Mouse (Apache-2.0)**, **Project Gameface (open source; Apache-2.0 unverified)**. Avoid copying from **WebGazer (GPLv3)** and **OpenFace 2.0 (non-commercial)**.
- Report the three standard eye-tracker data-quality numbers (Holmqvist/Nyström): **accuracy (°), precision (RMS-S2S and STD, °), and data loss (%)**. For the cursor as a pointing device, add **ISO 9241-411 Fitts throughput (bits/s)** and error rate.
- `GazeFeatures` is already `Codable`. That makes a **feature-stream replay regression suite** cheap to build: record JSONL feature streams with ground-truth targets, then replay them through calibration, the filters, and the stabilizer in `swift test` on CI, with no camera.
- The public gaze datasets (MPIIFaceGaze, ETH-XGaze) are **CC BY-NC-SA**. Use them only locally for benchmarking. Never commit them or anything derived from them to the MIT repo.

## Key findings

### Part A: landscape

| Project | Approach | Platform | License | Claimed accuracy | What oculOS can learn |
|---|---|---|---|---|---|
| WebGazer.js (Brown HCI) | Face mesh, eye patches, ridge regression; **implicit calibration from clicks and cursor moves** | Browser | GPLv3 (LGPLv3 for companies valued under $1M) | ~100 px | Implicit recalibration on clicks (VisionGaze already does this). No longer officially maintained as of 2026. **Don't copy code.** |
| GazeTracking (antoinelame) | dlib landmarks, pupil threshold blob, horizontal/vertical *ratio* | Python | MIT | None published; gives direction only (left/right/center) | Pupil threshold auto-tuning is similar to `PupilRefiner` |
| EyeTrax (ck-zhang) | MediaPipe face-mesh features, then a regression model (ridge/SVR/etc.), 9-point or 5-point calibration, Kalman/KDE smoothing | Python | MIT | Not stated (uncertain) | Pluggable regressor interface; Kalman option; virtual-camera overlay |
| OpenFace 2.0 (Baltrušaitis) | CLNF landmarks + model-based gaze vector, head pose, AUs | C++ (Win/Linux/mac) | **Academic/non-commercial only**; paid commercial license | Published evaluations report several degrees in the wild (uncertain) | Usable only as an offline reference baseline. Never bundle it. |
| OpenSeeFace | Custom MobileNet-style landmark CNN on CPU, 66 pts, eye gaze points | Python/ONNX, Unity | BSD-2 (code **and models**) | Not stated for gaze | Robust fast landmarks; models are license-compatible if a Vision replacement is ever needed |
| Project Gameface (Google) | MediaPipe face landmarks and 52 blendshapes; head moves the cursor, facial gestures click | Windows (Python), Android | Open source on GitHub (Apache-2.0 believed, **unverified**) | n/a (head pointer) | Gesture→action mapping with per-gesture thresholds; this is the model for the planned hand app's config UI |
| Talon Voice | Tobii 4C/5 **eye+head fusion**, "zoom mouse" (look → zoom → look again), noise triggers (pop = click, hiss = drag) | macOS/Win/Linux | Proprietary (free beta) | Depends on Tobii hardware | The **zoom mouse** is the best-known fix for 2–4° error. Multimodal clicks avoid the Midas touch problem. |
| Precision Gaze Mouse | Gaze warps the cursor, head movement fine-tunes it | Windows, Tobii EyeX | Apache-2.0 | n/a | **Gaze-then-head refinement** fits VisionGaze well, since it already estimates head pose |
| Beam Eye Tracker (Eyeware) | Webcam 3D head+eye model; SDK exposes per-eye 3D gaze rays and a 2D point of regard | Windows (+ iPhone as camera) | Proprietary SDK | **1.5°** ideal, worse at screen edges and on large screens; 30–80 cm; FOV 50–80° recommended | Warn users about wide-angle webcams (90–120° overshoots); report accuracy per screen region |
| Tobii (4C/5, Pro) | IR pupil–corneal reflection, dedicated hardware | Win (consumer), research SDKs | Proprietary | ~0.5–1° (uncertain for consumer units) | The ground-truth reference if one can be borrowed for validation |
| Apple Head Pointer / Dwell | Camera head pose moves the pointer; Dwell + Accessibility Keyboard give clicks; macOS Dwell also accepts third-party eye trackers | macOS | Built-in | n/a | oculOS should **interoperate** with Dwell (it only needs to move the system cursor) rather than reimplement dwell menus. Apple's camera-based *Eye Tracking* ships on iOS/iPadOS 18; I did not confirm it exists on macOS. |
| MediaPipe "virtual mouse" repos | 21 hand landmarks; index tip moves the cursor, thumb–index distance pinches to click; PyAutoGUI | Python | Mostly MIT/unlicensed, varies | Rarely measured | Shows the typical failures: jitter, and the cursor jumping at the moment of the pinch. Apple Vision's `VNDetectHumanHandPoseRequest` gives the same 21 joints natively. |
| Ultraleap (Leap Motion 2) | Stereo IR hand tracking | Win, macOS (Gemini ≥5.14, Apple Silicon) | Proprietary SDK | Sub-cm (uncertain) | A reference for gesture vocabulary. macOS may grab the device as a webcam. |

### Part B: evaluation metrics

- **Accuracy**: mean angular offset between gaze and a fixated target, measured on **held-out** points only.
- **Precision**: RMS sample-to-sample (RMS-S2S) and STD, both in °. Precision is measured before and after filtering, because the stabilizer hides noise.
- **Data loss**: invalid samples ÷ expected samples. Count blinks separately from tracking loss.
- **Pixel conversion**: convert px to ° using the viewing distance. VisionGaze estimates this from the face box.
- **Fitts throughput (ISO 9241-411)**: use a multidirectional ring of 13 or so targets. Compute We = 4.133·SDx along the task axis, IDe = log2(De/We + 1), and TP = IDe/MT averaged per subject. Report error rate and MT. MacKenzie's ISO 9241-9 eye-tracking evaluation found eye-tracker throughput to be competitive only with dwell or key selection tuned well (see source).
- **Protocol**: have at least 12 participants and counterbalance the input methods (mouse baseline, gaze+key, gaze+dwell, gaze+head). Vary glasses and lighting. Collect subjective ratings on the ISO comfort questionnaire.

## How to program it

**1. Replay regression suite (GazeKit, and HandKit later).**
- A `Recorder` writes `session.jsonl`. Line 1 is a header with `ScreenGeometry`, camera FOV, app version, and a device tag. Each following line is `{features: GazeFeatures, target: CGPoint?, phase: "calib"|"validate"|"free"}`.
- Record from real users with consent. Record features only, never video, which fits the privacy promise.
- Add `Tests/Fixtures/*.jsonl.gz`, kept small with a few thousand frames each.
- The `ReplayTests` suite runs `GazeCalibration.fit` on the calib phase and predicts the validate phase. It asserts accuracy, RMS-S2S, and data loss against a checked-in `baselines.json` with a tolerance (e.g. `≤ baseline × 1.10`). This catches regressions while letting improvements through. Print a diff table so PRs show the metric deltas.
- Keep the existing synthetic `World` generator as the deterministic unit layer. Add perturbation sweeps (head z 400–800 mm, yaw ±0.3 rad, noise ×2, 5% glance outliers, dropped frames) as property tests.
- Record a second, optional tier of raw `.mov` clips locally and run it on a macOS runner through `FaceFeatureExtractor` using `AVAssetReader`. This tests Vision-revision drift. Keep the clips out of git unless every subject gave consent under a CC-BY license.
- HandKit gets the same design: `HandFeatures: Codable` (21 joints + chirality + confidence) plus labeled gesture events. The metrics are gesture precision/recall, false clicks per minute, and cursor drift at pinch onset.

**2. Fitts' law harness (in-app "Benchmark" window).**
- `FittsTrial { amplitude, width, targetIndex, startTime, endTime, selectPoint, hit }`.
- The window lays out the ISO ring and randomizes A×W conditions (e.g. A ∈ {256, 512, 768} pt, W ∈ {32, 64, 128} pt).
- Selection comes from a key, dwell, or pinch.
- The harness computes We, IDe, and TP per condition and exports CSV, so it can compare the mouse baseline, VisionGaze, and HandKit on the same screen.
- Put the math in a pure `FittsAnalysis` struct in GazeKit so it gets unit tests.

## Recommendations for oculOS

1. Add `ReplayTests` with 3–5 consented feature recordings and metric baselines. CI (macos-14) runs `make test`.
2. Report RMS-S2S and data loss next to accuracy on the calibration results screen, using Holmqvist terminology.
3. Prototype a **zoom-mouse or gaze-then-head refinement** mode, taking the ideas from Talon and Precision Gaze Mouse rather than their code. It works around the 2–4° floor.
4. Warn about wide-FOV cameras (Beam's guidance) and show accuracy per screen region.
5. Hand app: use `VNDetectHumanHandPoseRequest`, borrow Gameface's gesture→action config, and freeze the cursor at pinch onset.
6. Make sure the cursor output works with macOS Dwell / Accessibility Keyboard.

## Pitfalls

- Validating on the calibration points overstates accuracy. Always use held-out points.
- Smoothing improves precision numbers while adding latency, so report both.
- Fitts throughput must use effective width. Nominal W inflates TP for noisy devices.
- License contamination: GPL (WebGazer), OpenFace, and NC datasets. L2CS-Net weights trained on Gaze360/MPII may carry NC terms (verify).
- Vision request revisions change landmark outputs, so pin `revision` and replay video fixtures on updates.
- Replay tests need `Codable` stability. Version the JSONL schema.

## Sources

- https://github.com/brownhci/WebGazer
- https://github.com/ck-zhang/eyetrax ; https://pypi.org/project/eyetrax/
- https://github.com/antoinelame/GazeTracking/blob/master/LICENSE
- https://github.com/emilianavt/OpenSeeFace/blob/master/LICENSE
- https://github.com/TadasBaltrusaitis/OpenFace/blob/master/OpenFace-license.txt ; https://dl.acm.org/doi/10.1007/978-3-031-35596-7_34
- https://developers.googleblog.com/en/project-gameface-launches-on-android/ ; https://blog.google/innovation-and-ai/products/google-project-gameface/
- https://talonvoice.com/dl/latest/changelog.html ; https://handsfreecoding.org/2021/12/12/talon-in-depth-review/
- https://github.com/PrecisionGazeMouse/PrecisionGazeMouse
- https://beam.eyeware.tech/developers/ ; https://beam.eyeware.tech/webcams/
- https://support.apple.com/en-gb/guide/mac-help/mchlb2d4782b/mac ; https://support.apple.com/en-ca/guide/accessibility-mac/mchl437b47b0/mac
- https://forum.derivative.ca/t/leap-motion-now-supported-on-macos-silicon-hopefully-touchdesigner-soon/363524
- https://github.com/topics/virtual-mouse-using-hand-gesture
- https://www.yorku.ca/mack/45520779.pdf ; https://www.yorku.ca/mack/CHI99b.html
- https://www.researchgate.net/publication/222353245_Towards_a_Standard_for_Pointing_Device_Evaluation_Perspectives_on_27_Years_of_Fitts'_Law_Research_in_HCI
- https://www.researchgate.net/publication/357166749_Eye_tracking_empirical_foundations_for_a_minimal_reporting_guideline ; https://lup.lub.lu.se/search/publication/d8e79b2e-23cc-496a-9f7d-8cff84c5fe9f
- https://www.collaborative-ai.org/research/datasets/MPIIFaceGaze/ ; https://ait.ethz.ch/xgaze
