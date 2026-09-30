# 03 — Pupil / iris localization and eye-region features (webcam, visible light)

## TL;DR

- On an RGB webcam you mostly cannot see the **pupil**. Brown irises are about as dark as the pupil, so you are really tracking the **iris center (limbus)**. The dark-blob centroid in PupilRefiner is an iris-blob estimate, and the eyelid and lashes bias it upward.
- Signal budget: at 60 cm with a 1280-px-wide, ~60° HFOV camera (f ≈ 1100 px), the iris is ~21 px across, and **1° of eye rotation moves the iris center only ~0.4 px** (~0.6 px at 1080p). Sub-pixel localization with ≤0.3 px noise is needed to get ~1° precision. Temporal filtering does the rest.
- **MediaPipe Face Landmarker** (478 landmarks, 5 iris points per eye, 52 blendshapes including `eyeLook{In,Out,Up,Down}{L,R}` and `eyeBlink{L,R}`) is the strongest free off-the-shelf iris source. The official Swift pod targets iOS, so native macOS use means running the `.tflite` models yourself or converting them to Core ML.
- Iris diameter is **11.7 ± 0.5 mm** across people. MediaPipe Iris reports **4.3% ± 2.4%** mean relative depth error from it (4.8% with glasses), which makes a good per-frame distance cue.
- Classical near-eye IR pupil detectors (Starburst, ExCuSe, ElSe, PuRe) assume a high-resolution, IR-lit, dark-pupil image, so they don't carry over. The methods that fit a 20-px webcam iris are **gradient voting (Timm & Barth)** and **limbus circle/ellipse fitting**.

## Key findings

- **MediaPipe Iris/Face Mesh.** The output is 468 face landmarks plus 10 iris landmarks (indices 468–477: a center and 4 boundary points per eye). The iris sub-model runs on an eye crop (*reported as 64×64, uncertain*) and also refines 71 eye-contour points. Blendshapes come from a small MLP on a subset of landmarks. `*Left/*Right` refer to the face's own side *in the input image*, so mirroring the frame swaps them (issue #6368).
- **Running it on macOS.** `MediaPipeTasksVision` is distributed via CocoaPods for iOS, and I found no official macOS target (*uncertain; Mac Catalyst might work*). Options: (a) TensorFlow Lite C/Swift runtime on macOS with the `.tflite` files extracted from `face_landmarker.task` (a zip); (b) convert TFLite → ONNX (`tflite2onnx`) → Core ML with coremltools, which can't read TFLite directly. Community Core ML ports exist, e.g. HF `robertteleng/face-landmarks-coreml`, but I could not verify them (blocked). You still need a face detector for the crop, and Vision's `VNDetectFaceRectanglesRequest` works for that.
- **Timm & Barth (VISAPP 2011).** The eye center is the point c that maximizes the mean squared dot product between normalized displacement vectors (xᵢ − c) and image gradients gᵢ, weighted by inverted, smoothed intensity. Reported BioID accuracy is ~82.5% at e ≤ 0.05 and ~93% at e ≤ 0.10 (*from memory of the paper, not re-verified*). It is simple and needs no training, but it's O(N²) per eye patch unless you downscale or restrict the candidates.
- **PuRe / ElSe / ExCuSe** (Santini, Fuhl, Kasneci): edge and ellipse-selection pupil detectors for head-mounted IR trackers. PuRe runs at 120 fps and wins about 72% of benchmark comparisons. It is not applicable to 20-px visible-light irises, apart from the ideas it shares with limbus fitting (edge filtering, ellipse scoring by contrast along the boundary).
- **EAR (Soukupová & Čech 2016).** `EAR = (|p2−p6| + |p3−p5|) / (2|p1−p4|)`. The open eye sits at ~0.25–0.35 and is person-dependent. A fixed threshold of 0.2 misses some blinks, so the paper classifies a temporal window of EAR values with an SVM (±6 frames, *uncertain*) or uses an HMM.
- **Webcam gaze accuracy in the literature.** Iris-center + eye-corner vector methods reach ~1.7–3° (and 2–5° unconstrained). A 1080p setup reported an iris radius of ~9 px (at a larger distance).

## How to program it

**Gradient eye center (Timm & Barth), on a ~40×25 px luma patch:**
```swift
// patch: Float luma, eye crop scaled to ~50 px wide; mask excludes lids
let (gx, gy) = sobel(patch)                      // vImage/Accelerate
let mags = zip(gx, gy).map { hypot($0, $1) }
let thr = mean(mags) + 0.3 * stddev(mags)        // keep strong edges only
let w = gaussianBlur(patch).map { 255 - $0 }     // dark-center prior
var best = (score: -Float.infinity, c: SIMD2<Float>.zero)
for c in candidates {                            // pixels inside shrunken contour
  var s: Float = 0
  for i in edgePixels where mags[i] > thr {
    var d = pos[i] - c; let n = simd_length(d); if n == 0 { continue }
    d /= n
    let g = SIMD2(gx[i], gy[i]) / mags[i]
    s += max(0, simd_dot(d, g)).squared          // dark→light gradients only
  }
  s = w[c] * s / Float(edgeCount)
  if s > best.score { best = (s, c) }
}
// sub-pixel: fit a 2D quadratic to the 3×3 score neighbourhood of best.c
```

**Iris circle fit (limbus).** Cast rays from the seed center, over horizontal sectors only (−45°…45° and 135°…225°, since the lids occlude the top and bottom). Take the strongest positive dark→light radial gradient along each ray within r ∈ [0.15, 0.35]·eyeWidth. Then fit a circle with algebraic least squares (Kåsa) and reject outliers with RANSAC:
```swift
// minimize Σ (x²+y² + D x + E y + F)²  → solve 3×3 normal equations
// center = (-D/2, -E/2), r = sqrt(D²/4 + E²/4 - F)
```
Fitting two-sided limbus edges uses points on both sides of the iris, so it's far less lid-biased than a dark-pixel centroid.

**EAR blink** (Vision's 76-point landmarks: use the eye contour extremes and the two upper/lower pairs):
```swift
func ear(_ p: [CGPoint]) -> CGFloat {   // p1..p6
  (dist(p[1], p[5]) + dist(p[2], p[4])) / (2 * dist(p[0], p[3]))
}
// per-user: baseline = rolling 80th percentile of EAR while calibrated
// closed if ear < 0.6 * baseline for >= 2 frames; blink if closure 60–400 ms
```

**Iris-based distance:**
```swift
// f_px from camera intrinsics (AVCaptureDevice / cameraIntrinsicMatrix if
// delivered) or estimated: f = (W/2) / tan(HFOV/2)
let dIrisPx = mean(horizontal iris diameter, both eyes)   // limbus fit or MP pts 469/471
let zMM = f_px * 11.7 / dIrisPx
```

## Recommendations for oculOS / VisionGaze PupilRefiner

1. **Cascade the pipeline.** Use the dark-22% centroid as a seed, run the Timm & Barth score in a ±0.15·eyeWidth window around it, then run the limbus circle fit. Output the circle center, which is lid-unbiased and sub-pixel, and fall back to the centroid when fit residuals are high.
2. **Upsample before measuring.** Crop the eye to ~64 px wide with bilinear/Lanczos interpolation (vImage) before gradient work. Normalize the patch per frame: stretch luma to the 2nd–98th percentile, or apply CLAHE (e.g. clip 2.0, 2×4 tiles). Global histogram equalization amplifies sensor noise in dark rooms, so avoid it.
3. **Make vertical gaze a first-class feature.** Use the iris-center-to-lid-midline distance *plus* lid openness (EAR). The upper lid moves with vertical gaze, so the pupil y-coordinate alone is compressed and biased. Keep eyelid openness as a regression feature (already done) and add the upper-lid-to-iris-top distance.
4. **Add iris-diameter depth** (`zMM`) as a feature or a normalizer next to eye-width normalization. It is more robust to head yaw than eye width, which foreshortens with cos(yaw).
5. **Blinks.** Replace any fixed threshold with EAR relative to a per-user baseline, and add hysteresis. Drop 2 frames on either side of a detected blink because the iris estimates are corrupted there.
6. **Evaluate MediaPipe iris landmarks as an optional backend.** Convert TFLite → ONNX → Core ML, or run TFLite on the CPU, and A/B test the jitter against PupilRefiner on recorded sessions. Its `eyeLook*` blendshapes are coarse expression cues and too coarse for cursor control, but useful as a sanity or outlier check.
7. **Measure the noise.** While the user fixates a static dot, log the frame-to-frame std of the iris center in pixels. The target is ≤0.3 px at 720p. Report it in the calibration UI.

## Pitfalls

- **Lids and lashes.** Dark lashes, mascara and lid shadow bias dark-pixel methods upward, and the iris top is almost always occluded. The existing 0.75 vertical shrink helps but also clips the iris during down-gaze.
- **Specular glints and glasses.** Screen and window reflections on the cornea punch bright holes. Glasses frames create strong false gradients, so mask pixels above the ~98th percentile before gradient voting.
- **Light irises.** Blue and green irises flip the contrast model. The pupil becomes the only dark blob, and it's small (2–8 mm) and changes with screen brightness. The limbus fit still works because it uses the iris/sclera edge.
- **Camera processing.** Auto-exposure, denoise and compression smear 1-px edges. Lock exposure where possible and use the 4:2:0 luma plane only.
- **Mirroring.** Mirroring swaps Left/Right in MediaPipe outputs and in Vision's eye labels.
- **Frame rate vs. noise.** Webcam noise is ~0.3–1 px per frame, which is ≈1–2.5° at 720p. Averaging trades lag for precision; combine with the existing stabilizer rather than filtering twice.

## Sources

- https://github.com/google/mediapipe/blob/master/docs/solutions/iris.md
- https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/face_mesh.md
- https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker/ios (search snippet; fetch blocked)
- https://github.com/google-ai-edge/mediapipe/issues/6368 (Left/Right blendshape mirroring)
- https://github.com/google-ai-edge/mediapipe/issues/6207
- https://syncedreview.com/2020/08/07/eyes-on-me-google-ai-mediapipe-iris-improves-iris-tracking-and-distance-estimation/ (4.3% ± 2.4% depth error)
- https://huggingface.co/robertteleng/face-landmarks-coreml (search snippet only)
- https://libraries.io/cocoapods/MediaPipeTasksVision
- https://cmp.felk.cvut.cz/ftp/articles/cech/Soukupova-TR-2016-05.pdf (search snippet; fetch blocked)
- https://pyimagesearch.com/2017/04/24/eye-blink-detection-opencv-python-dlib/
- https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0139098 (cites Timm & Barth, BioID)
- https://github.com/lepisma/gaze
- https://dl.acm.org/doi/10.1016/j.cviu.2018.02.002 (PuRe)
- https://www.semanticscholar.org/paper/ElSe:-ellipse-selection-for-robust-pupil-detection-Fuhl-Santini/a448cd6521a8e23c672871fde040362228032b27
- https://www.researchgate.net/publication/305791310_Robust_Gaze_Estimation_via_Normalized_Iris_Center-Eye_Corner_Vector
- https://www.arxiv.org/pdf/1605.05272 (low-res eye localization; search snippet)
