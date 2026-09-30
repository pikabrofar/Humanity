# 16 — Facial expressions as hands-free click/command triggers

## TL;DR

- Project Gameface (Google) and Apple's Head Pointer both use a small set of large, deliberate expressions (open mouth, raise eyebrows, smile, pucker, tongue out) mapped to clicks. Each has its own sensitivity setting.
- Vision has no blendshapes, but mouth-open and brow-raise can be computed well from `VNFaceLandmarks2D` as ratios normalized by face scale. Smile and pucker are weaker in 2D (they rely on mouth width only). Tongue-out can't be detected from landmarks at all.
- Make triggers work like a debounced switch: per-user baseline and maximum, a threshold set as a fraction of that range, hysteresis (separate on and off levels), a minimum hold time (about 150–300 ms), and a refractory period after each fire.
- Talking is the main source of false mouth-open triggers. Require a long hold, or a "wide open" level above normal speech, or both. Brow raise also fires during expressive speech.

## Key findings

- **Gameface** uses MediaPipe's 52 face blendshape scores (0–1). The desktop version exposes open mouth, mouth left/right, raise left/right eyebrow and lower eyebrow. For each gesture a "gesture size" slider sets its own threshold, and a live bar turns from yellow to green when the threshold is crossed. The repo was archived in Sep 2025. A GitHub issue asks for several gestures to map to one action, so mapping is one gesture to one action by default. *(Default threshold values not verified: the README fetch did not show them.)*
- **Apple macOS Head Pointer** ("alternate pointer actions") offers Smile, Open Mouth, Stick Out Tongue, Raise Eyebrows, Eye Blink, Scrunch Nose, and Pucker Lips (outwards, left, right). These can be assigned to Left, Right, Double or Triple Click and to Drag and Drop. Sensitivity is set per expression as Slight, Default or Exaggerated. These three levels are the UX model to copy. Apple likely uses an internal ML expression classifier, not public landmarks *(unverified)*.
- **Research on MAR/EAR thresholds** (drowsiness and yawn detection) finds that fixed thresholds generalize poorly across faces and lighting. A short per-user calibration improves results. Speech is a known source of false yawn detections, which is reduced by adding a hold time or a second cue.

## How to program it

Use `pointsInImage(imageSize:)`, not `normalizedPoints`. Normalized points are relative to the face bounding box, which distorts ratios when the box isn't square. Normalize by inter-ocular distance so the ratio doesn't change with camera distance. Use region extents (min/max) rather than hard-coded point indices, because the point order in the 76-point set is not documented *(uncertain)*.

```swift
import Vision

struct FaceExpr { var mouthOpen: Double; var browRaise: Double }

func centroid(_ p: [CGPoint]) -> CGPoint {
    let n = CGFloat(max(p.count, 1))
    return CGPoint(x: p.reduce(0) { $0 + $1.x } / n, y: p.reduce(0) { $0 + $1.y } / n)
}

func expressions(_ lm: VNFaceLandmarks2D, imageSize: CGSize) -> FaceExpr? {
    guard let inner = lm.innerLips?.pointsInImage(imageSize: imageSize),
          let outer = lm.outerLips?.pointsInImage(imageSize: imageSize),
          let lEye = lm.leftEye?.pointsInImage(imageSize: imageSize),
          let rEye = lm.rightEye?.pointsInImage(imageSize: imageSize),
          let lBrow = lm.leftEyebrow?.pointsInImage(imageSize: imageSize),
          let rBrow = lm.rightEyebrow?.pointsInImage(imageSize: imageSize),
          !inner.isEmpty, !outer.isEmpty else { return nil }

    let le = centroid(lEye), re = centroid(rEye)
    let iod = hypot(le.x - re.x, le.y - re.y)            // scale reference
    guard iod > 1 else { return nil }

    // Mouth aspect ratio: inner-lip vertical gap / outer-lip width.
    let ys = inner.map(\.y), xs = outer.map(\.x)
    let mar = Double((ys.max()! - ys.min()!) / (xs.max()! - xs.min()!))

    // Brow raise: brow-to-eye distance / IOD, averaged over both sides.
    // (Image space here is bottom-left origin, so brow.y > eye.y.)
    let dl = centroid(lBrow).y - le.y, dr = centroid(rBrow).y - re.y
    let brow = Double((dl + dr) / 2 / iod)
    return FaceExpr(mouthOpen: mar, browRaise: brow)
}

/// Debounced switch: calibrated range, hysteresis, hold time, refractory period.
struct ExpressionSwitch {
    var baseline: Double, maxValue: Double          // from calibration
    var onFrac = 0.55, offFrac = 0.35               // hysteresis band
    var hold: TimeInterval = 0.25, refractory: TimeInterval = 0.6
    private var above: Date?, lastFire = Date.distantPast, latched = false

    mutating func update(_ raw: Double, now: Date = .now) -> Bool {
        let v = (raw - baseline) / max(maxValue - baseline, 1e-6)   // 0...1
        if latched { if v < offFrac { latched = false; above = nil }; return false }
        guard v > onFrac else { above = nil; return false }
        if above == nil { above = now }
        if now.timeIntervalSince(above!) >= hold, now.timeIntervalSince(lastFire) >= refractory {
            latched = true; lastFire = now; return true
        }
        return false
    }
}
```

Smooth `raw` with a light One Euro or EMA filter before calling `update` (see report 05).

## Recommendations for oculOS

1. **Start with two triggers**: mouth-open (click) and brow-raise (secondary click or mode toggle). Add smile (MAR width relative to baseline) only after measuring it.
2. **Calibration step**: record 2 s neutral, 2 s max mouth-open, and 2 s max brow-raise, then store baseline and max per user. Offer Slight, Default and Exaggerated presets (onFrac about 0.35, 0.55, 0.75), following Apple's model.
3. **Suppress brow-raise and mouth triggers when head pitch changes quickly.** Pitch changes the 2D brow-to-eye distance. Divide by a pitch-dependent baseline, or skip frames where |Δpitch| is large.
4. **Gaze and blink conflict**: raising the brows and opening the mouth widely both shift eye landmarks. Freeze the gaze cursor while an expression is above its "off" level, following the "freeze on pinch" rule from reports 07 and 09.
5. **Show a live meter** with threshold ticks, as Gameface does, and give audio or visual feedback when a trigger fires.
6. Add a **pause/"talking" mode**: a hotkey or a long brow hold turns triggers off during calls.

## Pitfalls

- **Speech**: normal speech opens the mouth to about 30–50% of max *(estimate)*. Pair a high onFrac with a 250 ms+ hold. Consider a speech-rhythm reject: several short MAR peaks inside 1 s mean the user is talking.
- Beards, glasses and poor lighting make Vision's lip and brow points jittery *(unverified for Vision specifically)*.
- Inner lip points collapse together when the mouth is closed, which is fine for MAR, but check for `pointCount == 0`.
- The 2D brow ratio mixes brow raise with head pitch and changes with the camera's height relative to the face.
- Holding an expression for a long time tires users with some motor conditions, so make hold time and refractory period adjustable.
- Vision's landmark quality changes with OS version, so re-check calibration after macOS updates.

## Sources

- https://developers.googleblog.com/2023/06/project-gameface.html
- https://developers.googleblog.com/project-gameface-launches-on-android/
- https://github.com/google/project-gameface
- https://github.com/google/project-gameface/issues/16
- https://caniplaythat.com/2023/05/11/google-reveals-project-gameface-mouse-control-using-facial-expressions/
- https://www.howtogeek.com/788217/how-to-use-your-head-and-face-to-control-your-mac/
- https://thoughtbot.com/blog/an-introduction-to-macos-head-pointer
- https://eshop.macsales.com/blog/64948-control-mac-with-head-gestures/
- https://arxiv.org/html/2604.22479 (personalized EAR/MAR thresholds)
- https://www.emergentmind.com/topics/mouth-aspect-ratio-mar
- https://github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS13.0.sdk/System/Library/Frameworks/Vision.framework/Headers/VNFaceLandmarks.h
