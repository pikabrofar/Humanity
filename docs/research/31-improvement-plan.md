# 31 — Improvement plan for the current VisionGaze system

Scope: a prioritized, implementable plan for the code as it stands on `claude/camera-eye-hand-tracking-0y2amh`. Paths are relative to `VisionGaze/Sources/`. Swift was not available, so nothing was compiled or measured. Every line reference comes from reading the source on 2026-09-30. Claims marked **(?)** are unverified estimates.

Inputs: the GazeKit sources, `GazeEngine.swift`, `CalibrationController.swift`, `docs/reviews/code-review.md`, `docs/reviews/repo-and-research-review.md`, the roadmap in `docs/research/README.md`, and targeted web research (see Sources).

**Status check.** All 11 code-review findings are still present in the current source. For example, `GazeEngine.swift:229` still guards only on `calibration != nil`, `FaceFeatureExtractor.swift:80-83` still updates the blink baseline only on non-blink frames, and `GazeEngine.swift:136` still reassigns `camera.onFrame` on every `start()`.

---

## Priority table

| ID | Item | Class | Effort | Risk | Priority |
|---|---|---|---|---|---|
| B1 | Stale refit overwrites a new calibration | Bug | S | Low | P0 |
| B2 | Blink detector latches, so tracking freezes | Bug | S | Low | P0 |
| B3 | Capture session and `onFrame` races | Bug | S | Low | P0 |
| B4 | Synchronous multi-MB JSON save on every click | Bug/perf | M | Low | P0 |
| B5 | Decode validation, `screens[0]` crash, relative pivot tolerance, eye-order ±π, click window timing, main-queue coalescing | Bug | S each | Low | P1 |
| A1 | Roll handling: rotate eye-in-head angles by head roll | Accuracy | M | Med | P1 |
| A2 | Drift layer replaces full refits on clicks | Accuracy/UX | M | Med | P1 |
| A3 | Pupil refinement: gradient-based center (Timm and Barth) plus a blend | Accuracy | M | Med | P2 |
| A4 | Pin the camera frame rate and use timestamp-based smoothing (1€ filter before the stabilizer) | Latency/precision | S–M | Low | P2 |
| A5 | Better head pose: landmark PnP or rotation-matrix composition instead of additive yaw/pitch | Accuracy | L | High | P3 |
| A6 | Normalized, roll-corrected eye-patch and face crops for the appearance model and CNN | Accuracy | M | Med | P3 |
| R1 | Calibration quality report: precision (RMS-S2S), data loss, per-region error | UX | S | Low | P2 |
| P1 | Per-frame compute budget: skip the landmark pass, downscale the ROI | Perf | M | Low | P2 |
| T1 | CI and replay regression suite | Testing | M | Low | P1 |
| H1 | Shared camera service, then HandKit MVP | Hand app | M–L | Med | P2 |

---

## 1. Correctness bugs (Milestone 1)

### B1. A stale refit overwrites a new calibration (P0)
- **Problem.** `GazeEngine.swift:221-229` snapshots samples and geometry, fits them on a detached task, then does `if let model, calibration != nil { calibration?.model = model }`. If `CalibrationController.swift:~153` assigns a new calibration in the meantime, the old-data model replaces it and gets persisted.
- **Change.** Add a `generation: UUID` to `StoredCalibration` (a fresh UUID for each full calibration). Capture it before the task, and apply the result only if it still matches. Samples that arrive while `isRefitting` is set are currently dropped from the pending fit (`:219`). After applying, trigger a single follow-up refit if new samples arrived. This becomes moot once A2 replaces full refits, but ship the guard first.
- **Verify.** Unit-test the engine logic with an injectable fitter: start a refit, replace the calibration, complete the fit, and assert that the model is unchanged.

### B2. The blink detector latches (P0)
- **Problem.** At `FaceFeatureExtractor.swift:79-83` the baseline updates only when `!isBlinking`. A baseline inflated by a wide-eyed first frame, or a sustained squint or downward gaze, makes every later frame a "blink". `GazeEngine.swift:164` then returns forever and `GazeCalibration.swift:214` drops the samples.
- **Change.** Track `blinkStart`. If a blink state lasts more than 400 ms (natural blinks last roughly 100–400 ms **(?)**, a textbook range), set `opennessBaseline = openness`. Also adapt slowly during blinks (α = 0.005 against 0.03 normally), and seed the baseline from the median of the first 15 frames instead of frame 1.
- **Verify.** Unit-test by feeding an openness sequence [0.35 ×1, 0.20 ×60] and assert that `isBlinking` clears within 400 ms of timestamps.

### B3. Capture-queue races (P0)
- **Problem.** `CameraCapture.configure` (`CameraCapture.swift:33-60`) runs on the main thread from `GazeEngine.start()` (`:131`). Meanwhile `start()` and `stop()` run on `queue` (`:64-70`). `onFrame` is written on main (`GazeEngine.swift:136`) and read on `queue` (`CameraCapture.swift:80`). Apple's guidance is that session calls block and belong on a dedicated serial queue (objc.io; Apple AVFoundation guide).
- **Change.** Make `configure` do its work in `queue.sync { ... }`. Pass `onFrame` in `init`, or guard it with an `OSAllocatedUnfairLock`. In `GazeEngine`, set the handler once in `init` rather than in `start()`. The same serial queue later becomes the shared frame service (H1).
- **Verify.** Run with Thread Sanitizer (`swift test --sanitize=thread`, plus a manual camera switch while running).

### B4. Synchronous persistence on every click (P0)
- **Problem.** `GazeEngine.swift:27-31`: `didSet` calls `CalibrationStore.save` synchronously. Each click assigns `calibration` (`:218`) and so does the refit result (`:229`). Every sample carries 120 floats of appearance data, and there are up to 400 click samples.
- **Change.** Add a `CalibrationSaver` actor with a 2 s debounce that encodes on a background executor. Use `PropertyListEncoder` in binary format, or store `appearance` as base64 `Data` of `[Float]` bytes, to shrink the file roughly 3–5× **(?)** compared with JSON float text.
- **Verify.** Use an os_signpost around save. Main-thread hitches during 20 rapid clicks should read 0 in Instruments.

### B5. Small fixes (P1, S each)
| Fix | Evidence | Change |
|---|---|---|
| Decode validation | `GazeCalibration.swift:98-109, 408-416` | Check `featureMean.count == 3` and that every appearance weight row count equals `mean.count`; otherwise throw `DecodingError.dataCorrupted`. |
| `screens[0]` crash | `GazeEngine.swift:74` | Make `targetScreen` optional, skip the frame when it is nil, and cache it on `NSApplication.didChangeScreenParametersNotification`. |
| Pivot tolerance | `LinearAlgebra.swift:10` | Use `tol = 1e-12 * max(1, maxAbsDiag)`. |
| Eye order / ±π | `FaceFeatureExtractor.swift:72-73` | Order the centroids by x before `atan2`, or wrap the angle into (-π/2, π/2]. This is required before A1, because roll feeds the model. |
| Click window | `GazeEngine.swift:212` | Filter on `CACurrentMediaTime() - $0.timestamp <= 0.25`. |
| Frame pile-up | `GazeEngine.swift:138` | Add a `pending` atomic flag and keep only the latest analysis. Frames whose analysis is dropped still count toward fps. |

---

## 2. Accuracy (Milestone 2)

### A1. Roll handling (P1)
- **Problem.** The eye features are levelled by `eyeLineAngle` (`FaceFeatureExtractor.swift:73-76, 113-131`), so they live in a head-aligned frame. The model then adds them straight to screen-aligned yaw/pitch (`GazeCalibration.swift:159-169`), and `roll` (`:91`) is never read. With a 15° head tilt, a purely horizontal eye movement predicts a horizontal screen movement when it should be tilted 15°. The cross-talk is sin 15° ≈ 26 % of the movement, about 2.6 cm on a 10 cm saccade at 60 cm **(?)**, a geometric estimate.
- **Change.** Split the angle model into an eye-in-head part (the eye terms plus the CNN terms) and a head part (the yaw/pitch terms plus the bias). Rotate the eye-in-head (Δθ, Δφ) by `+roll` (sign to be confirmed with a test) before adding the head part. Use `eyeLineAngle` as the roll source (it is more precise per the inline comment) and store it in `GazeFeatures.roll` unconditionally, after B5's normalization. Keep the parameter layout. This changes only `angles(...)`. `requiredAngles` stays valid because it does not depend on the decomposition. LM must re-fit, since the rows are no longer linear in roll, but `solve` already runs LM.
- **Verify.** Add a synthetic test: generate features from a known model at roll ∈ {-20°, 0°, 20°}, fit on roll = 0, and evaluate at ±20°. The error should drop by more than half. Live check: a head-tilt validation pass (tilt ±15°, 5 targets), comparing the mean error before and after.

### A2. A drift layer instead of full refits (P1)
- **Problem.** `learnFromClick` (`GazeEngine.swift:210-231`) refits the full 17-parameter model plus the appearance model on up to 400 click samples (about 55 clicks). Clicks cluster on UI elements, so they can bias the geometric layout parameters (camera X, gap, scale) that the explicit calibration pinned down. The work also costs a full LM fit per click.
- **Change.** Freeze `GazeCalibration` after explicit calibration. Add `DriftCorrector` (GazeKit, `Codable`): a 2D affine correction `x' = A·x + b` in normalized screen space, fitted by weighted ridge least squares. The ridge pulls toward the identity (λ = 1e-2 on A - I, 1e-4 on b). Weights decay exponentially with age, with a 10 min half-life **(?)** (tune it). Use only one sample per click, the median of the frames in the last 250 ms. With fewer than 6 clicks, fit only `b`. Cap the history at 200 clicks. Solving a 6×6 system costs microseconds, so it can run synchronously and needs no refit task at all, which also removes the cause of B1. Recent webcam work treats per-session bias correction as the main deployable lever (EMC-Gaze, 2026; Google on-device few-shot, 2019).
- **Verify.** Replay test (T1): inject a synthetic 40 px offset partway through and assert that the error returns under the pre-shift level within 10 clicks. Also assert that the layout parameters are unchanged after 100 clustered clicks.

### A3. Gradient-based pupil center (P2)
- **Problem.** `PupilRefiner.swift:52-73` uses a darkest-22 % intensity centroid. It is biased by eyelashes, shadows and eyelid occlusion (partly mitigated by the 0.75 vertical shrink at `:42`), and by glasses glare.
- **Change.** Add a `timmBarth` mode. Downscale the eye ROI to about 40 px wide, compute gradients, keep those above the mean + 0.3·std of the magnitude, and maximize Σ(dᵢ·gᵢ)² weighted by inverted smoothed intensity, over candidate centers in the ROI. That is O(N²) on about 40×20 pixels, or about 640k dot products per eye, which is fine on the CPU **(?)**, and vDSP helps. Refine to sub-pixel with a quadratic fit around the maximum. Blend it with the current centroid, or choose between them by agreement. Timm and Barth report the method is robust to scale, contrast and illumination.
- **Verify.** Record an A/B replay with frames (opt-in, local only) and compare fixation precision (RMS sample-to-sample, in degrees) and calibration validation error. Keep A3 only if it wins on both.

### A4. Frame rate and time-based smoothing (P2)
- **Problem.** `CameraCapture.swift:48-51` picks a preset but never sets `activeVideoMinFrameDuration`. `FixationStabilizer` counts samples (`:13-16`), so latency depends on whatever fps the camera delivers.
- **Change.** (a) Lock the device and pick the highest-fps format at 720p or above, capped at 60, setting min and max frame duration (Apple TN2445 and forum guidance: check the format's supported ranges first). (b) Put a 1€ filter (Casiez) before the stabilizer. Start with mincutoff 0.3–1 Hz and β around 0.3 (GazeChat used 0.3/0.3 for gaze), then tune with Casiez's two-step procedure. (c) Express the stabilizer's confirmation in ms (`confirmMs = 60…200`).
- **Verify.** Measure end-to-end latency with a target-jump test (a flash target, then time from the capture timestamp to the cursor crossing 50 %). Report the median in ms before and after.

### A5. Head rotation as a rotation (P3)
- **Problem.** `thetaRow` and `phiRow` add `f.yaw` and `f.pitch` linearly with learned weights and a 0±3 prior (`GazeCalibration.swift:162, 168, ~352`). Vision's yaw/pitch are coarse. The Apple documentation does not state their resolution, and I could not verify their accuracy.
- **Change.** Compute the head rotation R from the 76 landmarks with a small Gauss-Newton PnP against a generic 3D face mesh (about 10 stable points: eye corners, nose tip, mouth corners). Then compute gaze = R · eyeInHead. This also solves A1 in general. Keep Vision yaw/pitch as the initialization.
- **Risk.** A generic mesh introduces per-user bias, so calibration must absorb it. Do this only after A1 and T1 exist so the gain can be measured.

### A6. Normalized crops (P3)
Feed the CNN (`GazeNetwork.swift:30-36`, an unrotated 1.1× box) and `EyePatch` crops that are rotated by roll and scaled to a fixed distance. Zhang, Sugano and Bulling (ETRA 2018) show that normalization helps and recommend not scaling the gaze vector. Gains for this ridge-plus-CNN hybrid are unquantified **(?)**.

---

## 3. Robustness and UX

- **R1. Calibration report.** Next to the mean error, report precision (RMS-S2S), data loss (the fraction of blink or no-face frames), and a 3×3 per-region error grid. The inputs already exist in `CalibrationController.swift:128-147`. Warn when fps < 24 or when the face is under 12 % of the frame width.
- **R2. Recalibration prompts.** When the drift layer's |b| exceeds 5 % of the screen, or head-distance z moves more than 25 % from the calibration mean, show a non-modal "quick 5-point recalibration" (reusing `validationTargets`).
- **R3. Lighting guard.** Measure the mean eye-ROI luma. Below a threshold, show a hint and disable A3 (gradients are noisy in the dark).
- **R4. Docs.** Apply the wording fixes from the repo review: "partially compensated (yaw/pitch)", the report count, and the note that 400 samples is about 55 clicks.

## 4. Performance

- **P1.** Each frame runs two `handler.perform` calls (`FaceFeatureExtractor.swift:48, 53`), plus `EyePatch`, the refiner, and the optional CNN on a 1080p buffer. Options: (a) cap capture at 720p when the face covers more than 25 % of the width; (b) run the face-rectangles request only every Nth frame and reuse the previous box, expanded by 20 %, as `inputFaceObservations`. Head pose would then be 1–2 frames stale. The landmarks still update every frame, so that is acceptable. (c) Run the CNN at 15 Hz and hold its output. Target: under 12 ms per frame on M1 so the pipeline leaves headroom for the hand request (about 14–28 ms per frame on macOS by one report, so both cannot run at full rate **(?)**).
- Measure with `os_signpost` intervals per stage and show the timings in the Live view's fps area.

## 5. Testing and CI (T1)

- Add `.github/workflows/ci.yml` on **macos-15**. The macos-14 image is deprecated and removed on 2026-11-02 per the runner notes. Run `cd VisionGaze && swift test`, plus a TSan job.
- **Replay suite:** a `GazeFeatures` JSONL writer without `appearance` (to keep the privacy promise), and fixtures generated synthetically from a known model (roll sweeps, drift steps, blink latch sequences). Tests: B1, B2, A1, A2, and a decode round-trip including corrupted files (B5).
- Move `learnFromClick` logic into a GazeKit type (`ClickLearner`) so it can be tested without AppKit.

## 6. First steps toward the hand app (H1)

1. **FrameHub** (GazeKit, or a new `CaptureKit`): one `AVCaptureSession` on one serial queue (the B3 fix), with fan-out to subscribers `(CVPixelBuffer, hostTime)`. Each consumer drops frames independently (a latest-only mailbox).
2. **HandKit MVP:** `VNDetectHumanHandPoseRequest` (21 joints, `maximumHandCount = 1`) at up to 30 Hz, then a 1€ filter on the index MCP (not the tip, because pinching moves the tip), then interaction-box mapping. Include a pinch state machine with hysteresis (enter < 0.25, exit > 0.40 hand-size units, per the roadmap) and a 100 ms cursor rollback on pinch.
3. **InputKit:** a CGEvent `MouseInjector` plus Accessibility permission checks, shared by both apps.
4. Unit-test the gesture FSM with scripted joint sequences before any camera work.

---

## Swift sketches

**B1 + A2: generation guard and drift layer**
```swift
public struct DriftCorrector: Codable, Sendable {
    struct Obs: Codable { var p: SIMD2<Double>; var t: SIMD2<Double>; var time: Double }
    private var obs: [Obs] = []
    public var halfLife = 600.0, maxObs = 200
    private var A = simd_double2x2(1), b = SIMD2<Double>(0, 0)

    public func apply(_ p: CGPoint) -> CGPoint {
        let q = A * SIMD2(p.x, p.y) + b; return CGPoint(x: q.x, y: q.y)
    }
    public mutating func add(predicted: CGPoint, target: CGPoint, at time: Double) {
        obs.append(.init(p: .init(predicted.x, predicted.y), t: .init(target.x, target.y), time: time))
        if obs.count > maxObs { obs.removeFirst(obs.count - maxObs) }
        refit(now: time)
    }
    private mutating func refit(now: Double) {
        // Per axis k: minimize Σ w (a_k·p + b_k - t_k)² + λ|a_k - e_k|²; 3×3 normal equations.
        let affine = obs.count >= 6
        for k in 0..<2 {
            var M = [[Double]](repeating: [0, 0, 0], count: 3), v = [0.0, 0, 0]
            for o in obs {
                let w = exp2(-(now - o.time) / halfLife), x = [o.p.x, o.p.y, 1]
                for i in 0..<3 { v[i] += w * x[i] * o.t[k]; for j in 0..<3 { M[i][j] += w * x[i] * x[j] } }
            }
            let lam = affine ? 1e-2 : 1e6          // huge λ pins A to identity
            for i in 0..<2 { M[i][i] += lam; v[i] += lam * (i == k ? 1 : 0) }
            M[2][2] += 1e-4
            guard let s = try? LinearAlgebra.solve(M, v) else { continue }
            A[0][k] = s[0]; A[1][k] = s[1]; b[k] = s[2]
        }
    }
}
// GazeEngine: point = drift.apply(model.predict(f)); learnFromClick adds one median obs. No refit task.
// If full refits remain: let gen = stored.generation; ... if calibration?.generation == gen { ... }
```
The `LinearAlgebra.solve` signature is assumed. Adapt it to the real one.

**B2: a blink detector that cannot latch**
```swift
private var blinkSince: TimeInterval?
let isBlinking = openness < baseline * blinkRatio
if isBlinking {
    blinkSince = blinkSince ?? timestamp
    if timestamp - blinkSince! > 0.4 { opennessBaseline = openness; blinkSince = nil }  // re-baseline
    else { opennessBaseline = baseline * 0.995 + openness * 0.005 }
} else {
    blinkSince = nil
    opennessBaseline = baseline * 0.97 + openness * 0.03
}
```

**B3: session work on the capture queue**
```swift
public init(onFrame: @escaping @Sendable (CVPixelBuffer, TimeInterval) -> Void) { self.onFrame = onFrame; super.init() }
public func configure(deviceID: String?) throws {
    try queue.sync { try configureLocked(deviceID: deviceID) }   // never called from `queue` itself
}
private func setFrameRate(_ device: AVCaptureDevice, fps: Double = 60) throws {
    try device.lockForConfiguration(); defer { device.unlockForConfiguration() }
    guard let range = device.activeFormat.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) else { return }
    let d = CMTime(value: 1, timescale: CMTimeScale(min(fps, range.maxFrameRate)))
    device.activeVideoMinFrameDuration = d; device.activeVideoMaxFrameDuration = d
}
```

**A1: rotate eye-in-head angles by roll**
```swift
static func angles(_ f: GazeFeatures, _ p: [Double], _ mean: [Double], _ app: AppearanceModel?) -> (Double, Double) {
    let tw = thetaWeights(p), pw = phiWeights(p), tr = thetaRow(f, mean), pr = phiRow(f, mean)
    let headT = tw[0] + tw[5] * tr[5], headP = pw[0] + pw[6] * pr[6]        // bias + yaw/pitch
    var eT = dot(tr, tw) - headT, eP = dot(pr, pw) - headP                  // eye + CNN terms
    if let (dt, dp) = app?.correction(f) { eT += dt; eP += dp }
    let c = cos(f.roll), s = sin(f.roll)                                     // sign: verify by test
    return (headT + c * eT - s * eP, headP + s * eT + c * eP)
}
```

---

## Milestones

1. **M1: correctness (about 1 week).** B1–B5, the CI workflow, and TSan. Exit: all review findings closed, CI green, no main-thread hitches on click.
2. **M2: measurement (about 1 week).** The T1 replay suite and synthetic fixtures, R1 metrics, per-stage signposts, and the latency test. Exit: baseline numbers recorded (accuracy °/px, RMS-S2S, latency ms, fps).
3. **M3: accuracy (2–3 weeks).** A1 roll, A2 drift layer, A4 frame rate and 1€ filter, then A3 pupil as an A/B. Ship each only if it improves the M2 metrics.
4. **M4: robustness and UX (1 week).** R2 recalibration prompts, R3 lighting guard, R4 docs, P1 compute budget.
5. **M5: hand foundation (2–3 weeks).** FrameHub, InputKit, the HandKit MVP with the pinch FSM and tests.
6. **M6: research bets.** A5 PnP head pose, A6 normalized crops, gaze plus pinch (MAGIC).

## Sources
- Timm and Barth, Accurate Eye Centre Localisation by Means of Gradients: https://www.semanticscholar.org/paper/Accurate-Eye-Centre-Localisation-by-Means-of-Timm-Barth/7ae3c4bd0a4e7a86b1543fdf0fdeffc18d1981b4
- Tristan Hume, eye center tracking implementation notes: https://github.com/trishume/trishume.github.com/blob/master/_posts/2012-11-04-simple-accurate-eye-center-tracking-in-opencv.md
- objc.io, Capturing Video on iOS: https://www.objc.io/issues/23-video/capturing-video/
- Apple TN2445, Handling Frame Drops: https://developer.apple.com/library/archive/technotes/tn2445/_index.html
- Apple AVFoundation Media Capture guide: https://developer.apple.com/Library/ios/documentation/AudioVideo/Conceptual/AVFoundationPG/Articles/04_MediaCapture.html
- Casiez, 1€ Filter: https://gery.casiez.net/1euro/
- GazeChat (1€ parameters for gaze): https://dl.acm.org/doi/fullHtml/10.1145/3472749.3474785
- EMC-Gaze, session-wise meta-calibration (2026): https://arxiv.org/html/2603.12388
- He et al., On-device Few-shot Personalization: https://openaccess.thecvf.com/content_ICCVW_2019/papers/GAZE/He_On-Device_Few-Shot_Personalization_for_Real-Time_Gaze_Estimation_ICCVW_2019_paper.pdf
- Zhang, Sugano and Bulling, Revisiting Data Normalization (ETRA 2018): https://www.mpi-inf.mpg.de/departments/computer-vision-and-machine-learning/research/gaze-based-human-computer-interaction/revisiting-data-normalization-for-appearance-based-gaze-estimation
- Hand pose cost on macOS (gesture-mac issue): https://github.com/AlexHagemeister/gesture-mac/issues/6
- WWDC20, Detect Body and Hand Pose with Vision: https://developer.apple.com/videos/play/wwdc2020/10653/
- macOS runner / Xcode versions for CI: https://geekfence.com/four-green-checkmarks-github-ci-for-macos-ios-linux-and-windows/
