# Calibration & Personalization for Webcam Eye Trackers

## Summary

VisionGaze sits at about 5° accuracy and 4° precision. That is roughly the middle of commercial webcam systems (RealEye reports 3–5°). The literature suggests three ways to improve it. First, use a learned feature extractor and personalize only a small head on ≤9 samples, which is the FAZE/WebEyeTrack recipe. Second, make head pose an explicit model input so drift comes from head motion we can detect, not from noise we can't see. Third, treat recalibration as continual learning: trigger it when head pose leaves the calibrated region, and keep a replay buffer so old samples aren't forgotten. Adding more explicit calibration points gives diminishing, roughly linear-in-log returns.

## Key findings

- **Point count has diminishing returns.** RealEye's in-house comparison: 5-pt 137 px, 13-pt 127 px, 21-pt 113 px, 39-pt 106 px, 78-pt 92 px (n≈46–102 per arm). Going from 9 to about 20 points buys roughly 15–20 px. RealEye ships a ~30 s, ~40-dot calibration followed by a 3-point validation that passes only if each target is within 150 px. It reports 3–5° typical accuracy, a 2.08° median, and 92% of participants under 5.5°.
- **Few-shot personalization works with 3–9 samples.** FAZE (meta-learned, rotation-aware latent) reaches 3.18° on GazeCapture with k=3 and 3.14° with k=9. With 4 samples it matches baselines that use k=256. Google's on-device personalization (He et al., GAZE'19 best paper) beats prior methods that needed 13+ points while using only 2–5 points.
- **WebEyeTrack (2025)** is the closest analogue to VisionGaze. It uses a 670 KB BlazeBlock CNN encoder, freezes the encoder, and adapts only an MLP gaze head with first-order MAML on ≤9 points. Latency is 0.88 ms/frame on CPU and 2.4 ms on iPhone 14. Over 20 minutes its error rose only 20% (7.24→8.72 cm), against 49% for WebGazer (7.79→11.62 cm). The authors credit metric head-pose awareness for that robustness.
- **Click-based implicit calibration** (WebGazer) works because users look where they click. It reaches reasonable calibration after about 3 clicks, with cursor-movement sampling at about 175 px error. Online-EYE (CHI'25, XR) needed 8–9 implicit interactions to become usable.
- **Drift is mostly head motion.** When the head pose at runtime differs from the calibration pose, the gaze mapping degrades, with about 17% higher error reported in the MAC-Gaze work. GazeRecorder loses about 9% accuracy when head movement is allowed.
- **Recalibration triggers.** MAC-Gaze detects a new motion state, fires recalibration, and updates the calibrator with a replay buffer mixed 70% old and 30% new data. That cut error by 20–32% (2.81→1.92 cm). Removing replay raised error by 23%.
- **Saliency-based calibration** (Sugano; SalGaze; vGaze) can reach 3–5° with no explicit calibration. vGaze notes that raw saliency is often unusable for calibration, so it should only be used on frames with a sharply peaked saliency map.
- **Commercial practice.** GazeRecorder offers 1/5/9/16-point calibration (16 recommended) and claims about 1°. Independent tests measure about 1.4–1.75 cm. RealEye publishes per-participant validation thresholds. Vendor claims consistently beat independent numbers, so we should only publish held-out validation results.

## Recommendations for OculOS (ranked)

1. **Personalize a small head, not the whole model.** Freeze the CNN backbone, export the features, and fit a per-user MLP or ridge head on the 9-point, pursuit, and click samples. Meta-train that head offline (first-order MAML) on GazeCapture/MPIIGaze so 9 points behave like hundreds. Target under 3.5° on held-out points. Running it through Core ML or Accelerate should take under 1 s on-device.
2. **Make head pose a first-class input and use it to trigger recalibration.** Feed the 6-DoF head pose (Vision/ARKit-style face landmarks) into the head. Record the convex hull of head poses seen during calibration. When the live pose stays outside that hull, or beyond about 5 cm or 10° from it, for more than 2 s, show a soft "quick 3-point refresh" prompt. Never force it.
3. **Upgrade click recalibration into continual learning.** Take the gaze sample from a short window before each click, not at the click. Only accept clicks on small targets, under about 1.5° in size. Reject outliers more than 3σ from the current prediction. Weight replay at about 70/30 old to new so a user's calibration data is never overwritten. Add cursor-pursuit samples when the cursor moves smoothly and gaze velocity correlates with it.
4. **Detect drift continuously.** Track a running median of the click-minus-gaze residual. If it exceeds 1.5× the validation accuracy for N≥5 clicks, flag drift, apply an offset-only correction first (a cheap 2-parameter fix), and escalate to a full refit only if the residual persists.
5. **Report quality honestly.** After calibration, show accuracy and precision in degrees and in pixels from held-out points, measured per screen region (center vs edges). Show a pass/fail threshold as RealEye does, for example a "≥5.5° — recalibrate recommended" warning. Re-estimate accuracy live from click residuals, show "calibration age", and expose a confidence value per gaze sample. Never quote best-case numbers.
6. **Skip adding more explicit points.** Moving from 9 to 21 points costs time for about 15%. Spend that effort on 2–3 extra smooth-pursuit sweeps through the corners, since edges are where error concentrates.
7. **Later: opt-in saliency calibration** on high-confidence frames only (a single dominant salient object, such as a text cursor or a notification popup).

## Sources

- https://www.realeye.io/blog/post/optimizing-realeye-calibration-point-count-and-accuracy-on-computers
- https://www.realeye.io/whitepaper
- https://arxiv.org/abs/1905.01941 (FAZE)
- https://research.google/pubs/on-device-few-shot-personalization-for-real-time-gaze-estimation/
- https://arxiv.org/html/2508.19544 (WebEyeTrack)
- https://jeffhuang.com/papers/WebGazer_IJCAI16.pdf
- https://dl.acm.org/doi/10.1145/3706598.3713461 (Online-EYE)
- https://arxiv.org/html/2505.22769v1 (MAC-Gaze)
- https://arxiv.org/abs/1910.10603 (SalGaze)
- https://arxiv.org/pdf/2209.15196 (vGaze)
- http://cvl.ist.osaka-u.ac.jp/user/matsushita/papers/Sugano_pami2011.pdf
- https://www.frontiersin.org/journals/robotics-and-ai/articles/10.3389/frobt.2024.1369566/full (GazeRecorder comparison)
- https://arxiv.org/pdf/1903.04047 (SacCalib)
