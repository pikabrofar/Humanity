# VisionGaze code review

Branch: `claude/camera-eye-hand-tracking-0y2amh`. I reviewed by reading the code only, because Swift is not available in the review container, so nothing was compiled or run. Paths are relative to `VisionGaze/Sources/`.

## Status

All 11 findings were addressed in commits `5659c64` and `53bf2c9` (Milestone 1 of [report 31](../research/31-improvement-plan.md)). CI (macos-15) builds the package and passes all 24 tests. The app-layer fixes (#1–4, #6, #8, #11) compile, but nothing tests them automatically; they still need a manual run with a camera. #10 was fixed only for the roll fallback: the eye features still use the raw inter-ocular angle, so existing calibrations stay valid.

## Summary

**Verdict: solid, with a few fixes needed before relying on click-learning.** The geometric model and its inverse agree, LM/IRLS are sound, and the pupil refiner's coordinate flips are consistent. The main problems are in the app-layer concurrency around the engine: a stale background refit can overwrite a fresh calibration, and the camera callback and session are configured from the main thread while the capture queue is live.

| Severity | Count |
|---|---|
| High | 1 |
| Medium | 4 |
| Low | 6 |

## Findings

| # | Severity | File:line | Issue | Suggested fix | Confidence |
|---|---|---|---|---|---|
| 1 | High | VisionGaze/Engine/GazeEngine.swift:224-230 | A click-triggered refit that finishes after the user recalibrates does `calibration?.model = model`. That replaces the **new** calibration's model with one fitted on the **old** samples and geometry, which can belong to a different display. The only guard is `calibration != nil`. | Capture an identity (e.g. `stored.model.createdAt` or a generation counter) before the detached task. Apply the result only if it still matches. Better still, merge click samples into the current `calibration` value instead of replacing its model. | High |
| 2 | Medium | GazeKit/CameraCapture.swift:71, VisionGaze/Engine/GazeEngine.swift:136 | `onFrame` is a plain `var` that the main actor writes and the capture queue reads on every frame. When `cameraID` changes, `start()` runs again and reassigns it while frames are flowing. This is a data race, hidden by `@unchecked Sendable`. | Set `onFrame` once at init, or read and write it under a lock, or assign it via `queue.async`. | High |
| 3 | Medium | GazeKit/CameraCapture.swift:94-121 (called from GazeEngine.swift:131 on main) | `beginConfiguration`/`commitConfiguration` and `removeInput`/`addInput` run on the main thread. Meanwhile `startRunning` and `stopRunning` run on `queue`. The `AVCaptureSession` is then mutated from two threads, and a camera switch while running blocks the main thread on session reconfiguration. | Run `configure` on the same serial `queue` (e.g. `queue.sync` or an async API). | Medium |
| 4 | Medium | VisionGaze/Engine/GazeEngine.swift:27-31, 216-218, 229; Engine/Persistence.swift:89-91 | Every accepted click assigns `calibration`, and `didSet` then JSON-encodes and writes the whole `StoredCalibration` synchronously on the main actor. That includes every sample, each with a 120-float appearance vector (EyePatch 10x6 per eye) plus up to 400 click samples, so it can be MBs per click. The same write happens again when the refit lands. This will cause UI and cursor hitches during normal clicking. | Debounce the save and encode and write it off the main actor. Or persist click samples separately and incrementally. | High |
| 5 | Medium | GazeKit/FaceFeatureExtractor.swift:78-83 | The blink baseline only updates on frames that are *not* classified as blinks. If the baseline gets inflated (the first frame is wide-eyed, or a head turn spikes openness), or openness drops for a sustained period (squint, lower gaze, glasses glare), then every later frame reads as `isBlinking` and the baseline can never adapt back. Tracking then freezes permanently: engine line 164 returns early and calibration drops those samples. | Keep adapting slowly during "blinks" too (e.g. an asymmetric EMA). Or cap a blink at roughly 400 ms, after which you re-baseline. | High |
| 6 | Low | VisionGaze/Engine/GazeEngine.swift:211-212 | The click window is measured from `recentFeatures.last` rather than the current time. After a gap in face frames, "the frames just before the click" can be stale. It is partly mitigated by requiring `gaze != nil`. | Filter on `CACurrentMediaTime() - $0.timestamp <= 0.25` (the timestamps are host-clock). | Medium |
| 7 | Low | GazeKit/GazeCalibration.swift:98-109, 408-416 | Decoding checks only `params.count`. A corrupted or old file with `featureMean.count < 3`, or with `appearance.weights[k].count != mean.count`, will index out of bounds in `thetaRow`/`phiRow`/`correction` and crash. | Also validate `featureMean.count == 3` and `weights.count == 2 && weights.allSatisfy { $0.count == mean.count }`. | High |
| 8 | Low | VisionGaze/Engine/GazeEngine.swift:74 | `NSScreen.screens[0]` is evaluated on every frame through `targetScreen`. It crashes if no screen is attached (clamshell mode during a display change). | Cache the screen and return an optional, or skip the frame. | Medium |
| 9 | Low | GazeKit/LinearAlgebra.swift:10 | The singular-pivot tolerance is absolute (`1e-12`), while the Gram matrices are in mm² or pixel units. Ill-conditioned systems pass the check and yield huge weights instead of `.singular`. | Use a tolerance relative to the matrix scale (e.g. `1e-12 * maxAbsDiagonal`). | Medium |
| 10 | Low | GazeKit/FaceFeatureExtractor.swift:72-73, 91 | If Vision's `leftEye` lies at larger image x than `rightEye`, `eyeLineAngle` is about ±π. That flips both feature axes (calibration absorbs this). It also makes the `roll` fallback about π instead of about 0 and puts the angle near the ±π wrap. I did not verify Vision's left/right convention. | Normalize the angle to (-π/2, π/2], or order the eyes by x before `atan2`. | Low |
| 11 | Low | VisionGaze/Engine/GazeEngine.swift:138 | Every frame is posted to the main queue with no coalescing. If the main thread stalls (for example during save #4), analyses pile up and then play back late. | Coalesce: keep only the latest analysis and post only if nothing is already pending. | Medium |

## Details

### 1. A stale refit overwrites a new calibration
`learnFromClick` snapshots `stored.samples + stored.clickSamples` and `stored.model.geometry`, then fits them on a detached task. `CalibrationController.swift:153` can assign a completely new `engine.calibration` while that task runs. When the task finishes, `GazeEngine.swift:229` checks only `calibration != nil` and writes the old-data model into the new `StoredCalibration`. That value is persisted immediately by `didSet`. The user sees a fresh calibration that performs like the old one, possibly on the wrong display geometry. `isRefitting` does not help, because it only blocks *new* refits.

### 2 and 3. Capture-queue races
`CameraCapture` is `@unchecked Sendable`, but two things are touched from both threads. `onFrame` is written on main at `GazeEngine.start()` and read on `queue` in `captureOutput`. The session configuration runs on main while `startRunning()` or `stopRunning()` may be executing on `queue`. Changing the camera in Settings triggers both at once: `cameraID.didSet` leads to `start()`. Fix it by routing all session mutation and the callback assignment through `queue`.

### 4. Synchronous persistence on the hot path
`StoredCalibration` holds the full calibration sample set. Each `GazeFeatures` carries a 120-float `appearance` array, and Foundation's `JSONEncoder` is slow on large float arrays. That work runs on main on every useful click and again when the refit lands, and it competes with `handle(_:)` for the main actor.

### 5. A blink detector that can latch on
Line 80 compares against `baseline * 0.65`, and line 81 only updates the baseline on non-blink frames. So the state "all frames are blinks" is absorbing. At engine line 164 blink frames produce no gaze output, and at `GazeCalibration.swift:214` they are excluded from fitting, so a latched detector makes tracking silently stop.

## Checked and correct

- **Forward and inverse projection** (`GazeCalibration.swift:181-200`). The ray direction `(-sinθcosφ, sinφ, -cosθcosφ)` meeting z = 0 gives `x = hx - hz·tanθ` and `y = hy + hz·tanφ/cosθ`. `requiredAngles` is its exact inverse. The screen mapping signs (x mirrored, y down from the camera gap) agree in both directions.
- **Head position.** The pinhole math is right: the y offset is converted from image heights to image widths using `imageAspect`, and `faceSize` is floored at 0.01.
- **Parameter layout.** `thetaRow`/`phiRow` line up with `thetaWeights`/`phiWeights` and the `P` enum. The ridge penalty vectors have the right lengths (8 and 9).
- **IRLS and LM.** The Huber weights (`min(1, 2σ/e)`) are applied as √w on the residuals. LM damping and acceptance are correct, `fitted!` is safe because the loop runs at least once, and NaN costs fail `c < cost`, so LM returns the last finite parameters.
- **LinearAlgebra.solve.** The ranges `(col+1)..<n` and `(row+1)..<n` are safe at the boundaries. Partial pivoting is present.
- **PupilRefiner.** The bottom-left to top-left flip and back is consistent, including the +0.5 pixel centres. Bounds are clamped, and the `eyeWidth >= 8` guard also prevents inverted ranges. `threshold - v` cannot underflow because of `where v <= threshold`. The buffer lock is paired with `defer`.
- **FixationStabilizer.** No division by zero, since `count >= 1` whenever a center exists, and `confirmSamples` stays in 2...6 as set by the engine.
- **Retain cycles.** The frame closure captures `processor` strongly and `self` weakly, and the event monitors use `[weak self]`.

## Positives

- The geometric, head-pose-aware model extrapolates physically rather than learning head/gaze correlations, and the reasoning is well documented inline.
- Robust fitting: Huber IRLS with outlier rejection above 5σ, priors that keep weakly observed layout parameters physical, and ridge-regularized linear warm start.
- The appearance correction is kept only when it lowers held-out error, and the ridge penalty is chosen on validation data.
- Reuses the face observation between the rectangle and landmark requests (`FaceFeatureExtractor.swift:52`), which avoids a second detection.
- The pupil refiner rejects implausible refinements (`maxDeviation`) instead of trusting them.
- The capture timestamps are converted to host time, so they can be matched against on-screen moving targets.

## Not reviewed (time limit)

- `GazeKit/GazeNetwork.swift`, `EyePatch.swift` (only the dimensions were checked), `GazeFeatures.swift`, `PursuitFilter.swift`, `FixationDetector.swift`, `HeatmapRenderer.swift`
- `VisionGaze/Calibration/CalibrationController.swift` (only the fitting section, lines 125-160), `CalibrationOverlayView.swift`
- `VisionGaze/AppModel.swift` (only click handling), `Engine/Persistence.swift` (only save), `Engine/HotKey.swift`
- `VisionGaze/Overlay/*`, `Views/*`, `Recording/*`, `VisionGazeApp.swift`, `Package.swift`
- `Tests/GazeKitTests/GazeKitTests.swift`
