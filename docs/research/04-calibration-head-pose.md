# 04 — Gaze calibration and head-pose compensation

## TL;DR

- VisionGaze's hybrid geometric model (pinhole head position + eye polynomial + ray/plane intersection, fit with Huber-weighted LM) is the right family. The literature finds hybrid geometric/regression methods beat pure 2D regression once the head moves. Its calibration protocol (grid + pursuit + head motion + held-out validation) is already stronger than WebGazer's.
- The biggest head-pose gap is that **head rotation enters as an additive, linearly weighted yaw/pitch term** (prior 0±3), rather than rotating the eye-in-head gaze vector by the full head rotation. **Roll is levelled out of the features but never rotated back into screen space.**
- Distance comes from the face-box width, which shrinks with yaw (foreshortening). A **PnP head pose** from the 76 landmarks and a generic 3D face would give a consistent 6-DoF pose and an eye-centred ray origin.
- Click learning **refits the full model** with up to 400 click samples. The literature favours a **separate low-dimensional drift layer** (an offset or affine map in angle space, time-decayed), which is safer when clicks cluster (menu bar, toolbars).
- Data-quality reporting has accuracy and RMS-S2S precision. It lacks **STD precision, data loss %, and accuracy by screen region and head pose**. It also has no **multi-monitor geometry**: the model assumes the screen lies in the camera plane (z = 0).

## Key findings

**Regression mappings and number of points.** A 2nd-order polynomial (constant, linear, quadratic and cross terms) is the classic mapping. Its 6 terms per axis need at least 6 targets, which is why a 9-point grid is standard; many studies calibrate with 16 points and validate with 9. Pure 2D regression must be recalibrated whenever the head moves relative to the tracker. The usual fixes are adding head pose to the features, roll correction and vertical compensation. Webcam calibration typically reaches about 2° (100–150 px). Other mappings in use:
- Gaussian-process regression (Sugano's saliency work)
- Ridge regression on 120-D eye patches (WebGazer: about 175 px mean error with click plus cursor sampling)
- Few-shot personalisation of a generic CNN, where a linear per-user correction is standard. WebEyeTrack (2025) uses on-device few-shot adaptation, but I could not access its figures (arXiv blocked), so they are *unverified*.

**Head pose.**
- **Vision:** `VNDetectFaceRectanglesRequest` revision 3 returns *continuous* roll, pitch and yaw (revision 2 had discrete bins and no pitch). It returns no translation and no covariance. Its noise level is undocumented, so VisionGaze should *measure* it.
- **PnP:** PnP recovers rotation and translation from n 2D–3D correspondences given camera intrinsics. EPnP is non-iterative, O(n), works for n ≥ 4 and is what OpenCV's `solvePnP` uses. Refining it with Gauss–Newton/LM on reprojection error is standard. Reported yaw/pitch MAE for landmark PnP is about 2–3°, though that comes from a secondary source (*uncertain*).
- **Data normalization:** Zhang, Sugano and Bulling (ETRA 2018) warp each eye image to a virtual camera that looks at the eye with roll cancelled, and they rotate the gaze labels the same way. Removing the scaling factor improved results by 9.5–32.7%.

**3D eyeball models.** EyeTab (Wood & Bulling 2014) fits the iris ellipse, back-projects it to a 3D circle, and takes the circle's normal as the optical axis. The eyeball centre is not directly observable, which is the known weak point of model-based methods. The visual axis differs from the optical axis by the per-person angle **kappa**, roughly 5° horizontal and 1–2° vertical (typical values, *from memory*). In VisionGaze's polynomial, kappa and the eye-centre offset are absorbed by the constant terms a0 and b0. That is fine as long as rotation is applied correctly (see Recommendations).

**Implicit and calibration-free methods.**
- **Clicks and cursor:** WebGazer learns from clicks and cursor movement.
- **Saliency:** Sugano et al. treat saliency maps as gaze probability distributions, aggregate them by eye-appearance similarity and fit a GP. They report about 6° accuracy, which is usable for coarse attention but not for pointing.
- **Pursuit and saccades:** Pursuits (Pfeuffer 2013) and SacCalib use eye-movement dynamics to calibrate.
- **Fixations:** fixation-based self-calibration in VR headsets builds on the same statistics.

**Drift.** "Calibration drift" is error that grows over a session, often vertically, as posture and lighting change. A linear map (translate, rotate, scale, shear), or a quadratic map fitted to error vectors at known targets, removes most systematic offset. A 2026 arXiv paper models residuals as a session-specific displacement field; I could see only its abstract.

**Data quality (Holmqvist).** Holmqvist's framework has three measures:
- **Accuracy:** offset between true and reported gaze.
- **Precision:** reported both as RMS-S2S (sample-to-sample, temporal noise) and STD (spatial spread). Precision varies widely between participants.
- **Data loss:** the share of samples that are missing or invalid.

## How to program it

**1. PnP head pose (Gauss–Newton, warm-started).**
1. Pick about 12 stable landmarks: the eye corners, nose bridge and tip, mouth corners and chin. Map each to a generic 3D face model. The MediaPipe canonical face mesh is Apache-2.0, but map it by index to Vision's 76 points *manually* (unverified correspondence).
2. Use intrinsics `f = 0.5·W / tan(FOV/2)` and put the principal point at the image centre.
3. Solve as in the sketch below.

```swift
// state: rotation vector r (so(3)) and translation t (mm), 6 params
func residuals(r: SIMD3<Double>, t: SIMD3<Double>) -> [Double] {
    let R = rodrigues(r)
    return zip(model3D, image2D).flatMap { X, u in
        let Xc = R * X + t                         // camera frame
        let p = SIMD2(f * Xc.x / Xc.z + cx, f * Xc.y / Xc.z + cy)
        return [p.x - u.x, p.y - u.y]              // pixels, Huber-weighted
    }
}
// init: r from Vision roll/pitch/yaw (first frame) or previous frame; t.z from face box
// 3–5 LM iterations with the existing LinearAlgebra LM; reject if RMS reprojection > ~3 px
```

Take the eye centres as `R·E_l + t` and `R·E_r + t`, where E_l and E_r are the 3D model's eye-centre points. Their midpoint is the ray origin, replacing the face-box centre. Then smooth the pose with a constant-velocity Kalman filter or a One-Euro filter. Unknown intrinsics: fold `f` and the face-model scale into the existing `scale` parameter. The lateral position already cancels `f`, because x = (u−0.5)·scale·W/size.

**2. Rotation-consistent gaze direction.**

```
g_head = normalize(-sinθe·cosφe, sinφe, -cosθe·cosφe)   // θe, φe from eye polynomial (+kappa via a0/b0)
g_cam  = R_head · g_head                                  // full 3×3, includes roll
point  = o + s·g_cam  with  s = -o.z / g_cam.z            // plane z=0
```

Keep a small learned correction on yaw and pitch, centred at weight 1 rather than 0, to absorb any gain error in Vision or PnP.

**3. Drift layer (recursive least squares with forgetting).** Keep the calibrated model frozen. Fit a correction in angle space, `[Δθ, Δφ] = A·[θ, φ, 1]` (2×3), starting from A = [I | 0].

```
on confirmed implicit sample (x = [θ,φ,1], y = required angles − predicted):
  k = P x / (λ + xᵀ P x);  A += (y − A x) kᵀ;  P = (P − k xᵀ P)/λ    // λ≈0.98–0.995
```

Start in offset-only mode, where x = [1], until the samples span at least 30% of the screen in each axis. Otherwise a cluster of clicks produces a spurious gain. Gate each sample on four conditions: a fixation of at least 150 ms before the click, a stable head pose, error under about 5°, and no dominance by a single UI location (for example, at most N samples per 50-px cell).

**4. Quality report.** Compute these on the validation points:
- Accuracy: mean angular offset, plus the 95th percentile.
- Precision: RMS-S2S and STD within each fixation.
- Data loss: dropped or blink frames divided by expected frames.
- Accuracy split by screen region (centre vs edges) and by head-pose bin.

## Recommendations for oculOS/VisionGaze (prioritized)

1. **Fix roll handling (P0, small).** Rotate the (θ, φ) eye-in-head vector back into screen space by the head roll, or use the full rotation matrix. With the current additive yaw/pitch weights, a 10° head tilt mixes the horizontal and vertical eye components. *Verify first*: I found no code that re-rotates by roll, but I read only `GazeCalibration.swift`.
2. **Split the drift layer from the refit (P0).** Replace the refit with a 400-click cap with an RLS offset/affine correction that has a forgetting factor (step 3 above). Leave the calibrated geometry fixed and show the drift magnitude in the UI. Offer "Recalibrate" when drift exceeds about 2°.
3. **PnP 6-DoF head pose and an eye-centred ray origin (P1).** This removes the face-box foreshortening under yaw and gives true translation, which is the README's open "3D face pose" item. Use Vision's roll, pitch and yaw only as the initial guess and as a sanity check.
4. **Add data loss and STD precision to `CalibrationReport` (P1)**, plus per-region error, following Holmqvist's recommended reporting.
5. **Model a non-coplanar screen for external monitors (P2).** The z = 0 assumption fails for an external display with a laptop camera. Add screen rotation (pitch and yaw of the plane) and a 3D offset as layout parameters with strong priors, identified by the head-motion phase. Keep a separate calibration per `displayID` and pick one from the gaze ray, since all screens can share one head/eye model.
6. **Normalize the eye patches before ridge (P2).** Warp them with the PnP rotation, cancelling roll, as in Zhang et al. 2018 (a 9.5–32.7% gain for appearance models).
7. **Pursuit-based silent re-anchoring (P3).** Correlate gaze with moving UI elements such as the cursor or scrolling text, Pursuits-style, as a second implicit signal. Saliency-only calibration (about 6°) is too coarse to act on alone.

## Pitfalls

- Click samples are *not* i.i.d. People look ahead of the click, glance at the cursor, and clicks cluster in the menu bar. Weight and bin them by location, and use the frames in a fixation just before mouse-down, not 250 ms blindly.
- Refitting geometry from implicit data can make layout parameters wander (camera X, gap, scale). Freeze them after explicit calibration.
- PnP with a generic face model has a depth/scale ambiguity (a face-size prior of about ±10%, *uncertain*). Jitter in the landmarks around the eyes and mouth moves the pose, so use rigid points only: not the mouth, and not the lower lid.
- Vision yaw near ±30° or more degrades landmark quality, so data loss and error rise sharply. Report accuracy by pose bin.
- Degrees depend on viewing distance. Report degrees using the *estimated* distance and state the assumption.
- Forgetting factors that are too small make the cursor "swim" toward recent clicks. Clamp the per-update change.

## Sources

- https://cs.brown.edu/people/apapouts/papers/ijcai2016webgazer.pdf (WebGazer)
- https://webgazer.cs.brown.edu/
- https://github.com/errollw/EyeTab ; https://www.researchgate.net/publication/261961246_EyeTab_Model-based_gaze_estimation_on_unmodified_tablet_computers
- https://dl.acm.org/doi/10.1145/3530797 (Rethinking Model-Based Gaze Estimation)
- https://developer.apple.com/videos/play/wwdc2021/10040/ ; https://www.kodeco.com/29023965-vision-tutorial-for-ios-what-s-new-with-face-detection/page/2 (Vision rev 3 continuous pose)
- https://vincentlepetit.github.io/files/papers/comp_lepetit_ijcv08.pdf (EPnP) ; https://en.wikipedia.org/wiki/Perspective-n-Point
- https://www.mpi-inf.mpg.de/departments/computer-vision-and-machine-learning/research/gaze-based-human-computer-interaction/revisiting-data-normalization-for-appearance-based-gaze-estimation
- https://www.researchgate.net/publication/221362759_Calibration-free_gaze_sensing_using_saliency_maps (Sugano)
- https://arxiv.org/pdf/1903.04047 (SacCalib) ; https://arxiv.org/pdf/2311.00391 (fixation-based self-calibration), abstracts via search only
- https://arxiv.org/html/2608.29739 (Drift calibration in geometric eye tracking), abstract via search only
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12015841/ (linear transformation for gaze error)
- https://www.researchgate.net/profile/Kenneth-Holmqvist/publication/321678981_Common_predictors_of_accuracy_precision_and_data_loss_in_12_eye-trackers/links/5a2a9401aca2728e05de621d/Common-predictors-of-accuracy-precision-and-data-loss-in-12-eye-trackers.pdf
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7733312/ (polynomial mapping errors)
- https://doi.org/10.3390/jemr18060071 (camera-based tracking with head movement)
- https://arxiv.org/html/2508.19544v1 (WebEyeTrack; fetch blocked, cited from search snippet only)
