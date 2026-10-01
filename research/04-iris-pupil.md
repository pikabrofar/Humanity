# 04: Accurate Iris/Pupil Localization from RGB Webcams

## Summary

OculOS's ~4° frame-to-frame jitter is about what an unfiltered webcam pipeline produces. A recent capture-clock benchmark measured 2.2–4.3° within-fixation jitter for both WebGazer and MediaPipe FaceMesh+KRR. The cause is mostly geometric. At 60 cm on a 720p webcam the iris is only about 20 px wide, and a 1 px iris shift equals about 2–3° of eye rotation (iris ≈ 11.7 mm, eyeball radius ≈ 12 mm). Cutting jitter therefore takes three things: (a) sub-pixel limbus/iris-center estimation on full-resolution crops, (b) a stable eye-corner reference frame, and (c) speed-adaptive temporal filtering. A dark-blob centroid in luma does poorly here. In visible light the pupil/iris contrast is weak (especially for dark irises), and eyelids, lashes and glints bias the centroid. The limbus (iris/sclera edge) is the strongest, most stable edge in RGB.

## Key findings

- **Iris pixel budget.** Horizontal iris diameter is 11.7 ± 0.5 mm across populations (MediaPipe Iris). By the arithmetic above, holding gaze jitter under 1° needs iris-center noise of about 0.3–0.4 px. That requires sub-pixel methods and full-resolution capture, not downscaled frames.
- **MediaPipe Iris / Face Landmarker (refine_landmarks).** Outputs 478 landmarks: 468 face points plus 5 iris points per eye (center plus 4 contour points), with refined eyelid contours. Trained on ~50k annotated images covering varied lighting and head pose. Iris-derived depth has 4.3% ± 2.4% mean relative error, rising to only 4.8% ± 3.1% with glasses, so the model is fairly robust to eyewear. It runs on an eye crop (64×64 in the iris_landmark model, as I recall it, not confirmed this session).
- **Core ML paths exist.** MediaPipeTasksVision ships officially for iOS (CocoaPods). Community conversions turn the TFLite face mesh/iris models into Core ML: facemesh_coreml_tf, MediaPipeToCoreMLmodel (TFLite → pb → coremltools), and a face-landmarks-coreml .mlpackage on Hugging Face that targets the ANE.
- **Iris landmarks raise accuracy but also jitter.** In the capture-clock benchmark (arXiv 2608.11566), FaceMesh+KRR had a lower mean error than WebGazer (6.5–8.1° vs ~11.1°). However, its within-fixation jitter velocity (vp99) was 1.6–3.5× higher (65.8–145.7 °/s vs ~41 °/s), and the authors attribute this to per-frame iris micro-movements. The paper used a One-Euro filter (minCutoff 1.0, β 0.007) and I-VT fixation segmentation. A β sweep from 0.003 to 0.030 was noise-dominated, so filter parameters alone did not fix it. Neither engine got below 2° accuracy.
- **Timm & Barth gradient method.** It picks the center where the most normalized gradient vectors intersect, weighted by inverted intensity. On BioID it reaches 82.5% at e ≤ 0.05 (about pupil-diameter error) and 93.4% at e ≤ 0.10. It needs no training, is cheap, and is robust to partial occlusion. It is a good drop-in replacement for blob centroids.
- **Radial edge plus ellipse fitting.** Starburst-style radial rays from a coarse center, sub-pixel strongest-edge selection with agreeing gradient direction, median outlier filtering, then a Fitzgibbon ellipse fit inside RANSAC. This is reported to give 96.67% at e ≤ 0.05 on webcam data and ~2.4° gaze accuracy in low-resolution images (arXiv 1605.05272).
- **One-Euro filter.** A low-pass filter whose cutoff adapts to speed: low cutoff at rest kills jitter, and it rises during motion to limit lag. It is the standard choice for this problem. Kalman variants are also used for webcam gaze.

## Recommendations (ranked)

1. **Measure first, per stage.** Log raw iris-center std (px) per eye with the head fixed, separately from eye-corner jitter and final gaze jitter. Report RMS sample-to-sample error plus std, as the benchmark did. This shows whether the noise comes from the pupil estimate, the reference frame, or the regressor.
2. **Replace the blob centroid with Timm & Barth plus a limbus ellipse fit.** Run on the full-resolution capture crop (1080p or higher; lock the camera format), upsampled 2× and Gaussian-smoothed (σ ≈ 1 px). Mask out the eyelids using the Vision eye contour, and drop pixels brighter than about the 98th percentile (glints and glasses reflections) before computing gradients. Seed with Timm & Barth, then cast 32–64 radial rays, take sub-pixel edge peaks (parabolic fit over 3 samples), and RANSAC-fit an ellipse. Use the ellipse center. Target noise is ≤ 0.3 px.
3. **Stabilize the reference frame.** Express iris position relative to eye corners or a face-pose-normalized eye frame. Smooth the corners and head pose more heavily than the iris, since the head moves slowly: for example a One-Euro with minCutoff ≈ 0.3 Hz on corners. Average the left and right eyes, weighted by confidence, which gives about a √2 noise reduction.
4. **Add MediaPipe iris as a second estimator.** Convert iris_landmark.tflite to Core ML, or run Face Landmarker. Fuse its iris center with the gradient/ellipse center using inverse-variance weights measured from rolling per-estimator variance. Then calibrate on the fused features rather than on 10×6 patches alone.
5. **Make filtering fixation-aware.** Apply a One-Euro filter to the features before regression (start with minCutoff 1.0, β 0.007, then tune with repeated trials). Apply another to the output, plus an I-VT gate (saccade above ~30 °/s for 2 frames). During fixations, use heavier smoothing or a median of the last 5–7 frames; release it on a saccade.
6. **Gate low light and blinks.** Lock exposure and white balance. Prefer 30 fps with a longer exposure over a noisy 60 fps. Drop frames when the eye aspect ratio shows a blink or the ellipse-fit inlier ratio falls below about 60%, and hold the last good value instead.

Expected outcome: gaze precision of about 1–1.5° during fixation. Accuracy will stay around 2–5°, because calibration and head pose dominate it.

## Sources

- https://github.com/google/mediapipe/blob/master/docs/solutions/iris.md
- https://research.google/blog/mediapipe-iris-real-time-iris-tracking-depth-estimation/
- https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/ios
- https://github.com/gouthamvgk/facemesh_coreml_tf
- https://github.com/daisymind/MediaPipeToCoreMLmodel
- https://huggingface.co/robertteleng/face-landmarks-coreml
- https://www.researchgate.net/publication/221415814_Accurate_Eye_Centre_Localisation_by_Means_of_Gradients
- https://arxiv.org/pdf/1605.05272
- https://arxiv.org/pdf/2608.11566
- https://dl.acm.org/doi/10.1145/2207676.2208639
- https://link.springer.com/chapter/10.1007/978-3-032-25038-4_19
