# 12 — Robustness to lighting, glasses, and demographics

## TL;DR

- **Glasses are the biggest predictor of webcam gaze error.** In one controlled WebGazer study, hit accuracy was 20% for people wearing glasses and 54% for people without. An iMotions validation found glasses to be the only participant factor with a significant effect.
- **VisionGaze's darkest-luma pupil refiner is fragile to this.** Mascara, eyeliner, lashes, hooded or narrow lids, and dark frames all produce "darkest pixels" that aren't the pupil. Gate the refiner and fall back to the landmark or iris centroid.
- **Lighting problems are usually temporal.** Screen glow changes with content, auto-exposure keeps adjusting, and backlight turns the face into a silhouette. Normalize per frame and measure illumination stability.
- **Skin-tone bias is real but poorly quantified.** Google's MediaPipe Hands model card reports no skin-tone error pattern. Independent write-ups and a WebGazer face-detector analysis report worse detection on darker skin *(partly unverified)*.
- **Ship a tracking-quality score** with specific, actionable hints ("light is behind you", "glare on glasses"), and pause control when it is low instead of producing a jittery cursor.

## Key findings

- **Glasses:** Lens reflections of the screen and ceiling lights can cover the iris and pupil, and thick lenses shift and magnify the eye region. A PMC study (glint-based tracker) handles glasses by detecting large saturated reflection blobs and rejecting or relighting them. iMotions attributes the glasses effect to lens thickness and to reflections of the screen and the room.
- **Low light and sidelight:** Strong sidelight caused a systematic offset (about 4.9° mean accuracy) and about 5% lost trials in a webcam study (arXiv 2207.14380; figures from a search summary). In low light the webcam raises gain, which adds noise, and lowers the frame rate, which blurs saccades *(typical macOS behavior, not measured here)*.
- **Screen glow:** In a dark room the display is the main light source, so the brightness of the face follows what is on screen, for example a switch from dark mode to a white page. This moves the darkest-pixel threshold between frames.
- **Eye shape and makeup:** Holmqvist-lab data (Blignaut and Wium 2014) found lower accuracy and precision for Asian participants on IR trackers, attributed to narrower eye openings and eyelid occlusion. The Cambridge MRC eye-tracking guide says mascara "can make eye tracking impossible" because it is mistaken for the pupil. Driver-monitoring patents report eyeliner edges being detected as eyelids.
- **Contact lenses:** These are generally a minor issue for appearance-based webcam tracking. Colored or limbal-ring lenses can bias an iris-circle fit *(unverified)*.
- **Skin tone:** WebGazer's clmtrackr/face detector fails more often on darker skin, beards, and glasses (Pomona senior project). Apple does not publish per-group accuracy for Vision face or hand landmarks, so oculOS has to measure its own.

## How to program it

Compute a quality score per frame, smooth it, and derive a user hint from it.

```swift
struct QualityInputs {
    var faceConfidence: Float      // VNFaceObservation.confidence
    var captureQuality: Float?     // VNDetectFaceCaptureQualityRequest (0...1)
    var faceLuma: Float            // mean Y inside face bbox, 0...1
    var bgLuma: Float              // mean Y outside bbox
    var eyeSaturatedFrac: Float    // fraction of eye-ROI pixels with Y > 0.96
    var eyeOpenness: Float         // lid distance / eye width from landmarks
    var lumaDelta: Float           // |faceLuma - faceLuma(prev)|
    var refinerAgreement: Float    // px distance darkest-luma vs landmark pupil
}

enum Hint { case ok, tooDark, backlit, glare, eyesOccluded, unstableLight }

func quality(_ q: QualityInputs, iod: Float) -> (score: Float, hint: Hint) {
    var s: Float = 1; var hint = Hint.ok
    func penal(_ cond: Bool, _ w: Float, _ h: Hint) { if cond { s -= w; if hint == .ok { hint = h } } }
    penal(q.faceLuma < 0.18,                      0.35, .tooDark)
    penal(q.bgLuma - q.faceLuma > 0.30,           0.30, .backlit)
    penal(q.eyeSaturatedFrac > 0.03,              0.30, .glare)       // lens reflection
    penal(q.eyeOpenness < 0.18,                   0.25, .eyesOccluded)
    penal(q.lumaDelta > 0.08,                     0.15, .unstableLight)
    if q.refinerAgreement > 0.08 * iod { s -= 0.2 }  // refiner likely hit lashes/mascara
    s *= q.faceConfidence * (q.captureQuality ?? 1)
    return (max(0, s), hint)
}
// Smooth with an EMA over about 0.5 s. Show the hint only after about 1 s below 0.5, and hide it with hysteresis.
// Freeze or disable gaze output while score < 0.3.
```

Gate the pupil refiner per frame. Use the darkest-luma estimate only when it is within about 8% of the interocular distance of the landmark or iris centroid, when the eye ROI has no saturated blob, and when the eye is open. Otherwise use the landmark pupil. Normalize the eye ROI before thresholding (CLAHE, or a percentile threshold such as the darkest 3% instead of a fixed value) so that screen glow doesn't move it.

## Recommendations for oculOS

1. Add a **calibration preflight** that checks face luma, backlight ratio, eye-ROI glare, and the frame rate reported by `AVCaptureDevice.activeFormat`. It should tell the user what to change ("tilt your glasses down slightly", "add a lamp in front of you", "move away from the window").
2. **Lock exposure after calibration** where `isExposureModeSupported(.locked)` allows it. Many built-in Mac cameras don't support this *(unverified)*. If not, compensate by computing features relative to the face's mean luma.
3. **Re-trigger the drift correction** (report 04) when face luma shifts by more than a threshold for more than 2 s. A change in lighting often means the calibration no longer holds.
4. Show a small **quality indicator** (green, amber, or red dot and the hint) in the menu bar, and **log quality alongside accuracy** in the replay/eval harness (report 10).
5. **Build a small in-house test matrix**: glasses and no glasses, mascara, monolid, a range of skin tones, dark room with screen glow, backlit window. Report accuracy and data loss for each cell, not one average.
6. For hands, check hand-box luma and keypoint confidence the same way. Treat low average joint confidence as "hand lost", not as a gesture.

## Pitfalls

- A fixed darkest-luma threshold breaks as soon as screen content changes.
- Saturation detection can mistake sclera or skin for glare on overexposed webcams. Require a compact, very bright blob.
- Too many hints annoy users. Debounce them and show one at a time.
- Averaged accuracy hides the groups the tracker fails for. Always break results down by condition.
- Night Shift and True Tone change the screen's color cast. Use luma rather than RGB-specific thresholds.

## Sources

- https://imotions.com/blog/learning/product-news/webcam-eye-tracking-validation-study/
- https://arxiv.org/pdf/2207.14380 (search summary only)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC3958289/
- https://arxiv.org/pdf/2402.19133 (WebGazer glasses 20% vs 54%, via summary)
- https://github.com/chinasatokolo/TowardsMoreInclusiveFacialDetection
- https://storage.googleapis.com/mediapipe-assets/Model%20Card%20Hand%20Tracking%20(Lite_Full)%20with%20Fairness%20Oct%202021.pdf
- https://github.com/google-ai-edge/mediapipe/issues/3645
- https://link.springer.com/article/10.3758/s13428-013-0343-0
- https://imaging.mrc-cbu.cam.ac.uk/meg/EyeTrackingProblems
- https://webgazer.cs.brown.edu/data/
