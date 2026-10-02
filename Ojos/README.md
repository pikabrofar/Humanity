# ojoS

Part of [sentidoS](../README.md). Webcam eye tracking for macOS, built on Apple's Vision framework. No extra
hardware, no cloud, no third-party dependencies.

- **Multi-stage calibration**: 9-point grid, smooth-pursuit target, head-motion
  phase, and held-out validation that reports accuracy and precision in degrees
- **Advanced:** load your own Core ML gaze model to combine with the geometric model (bring your own;
  public research models are usually non-commercial)
- **Tolerates common calibration mistakes**: fixation detection per point, retries for missed
  points, per-user pursuit lag, and Huber-weighted fitting
- **Live gaze cursor** (ring, dot, or spotlight) drawn over every app
- **Recordings** with heatmaps, I-DT fixation scanpaths, and PNG/CSV export
- **GazeKit**, a reusable Swift library with the whole pipeline

Everything runs on-device. Video frames are processed in memory and never saved.

## Requirements

- macOS 14 Sonoma or later
- A built-in or external webcam
- Xcode 16+ **or** just the Command Line Tools (`xcode-select --install`)

## Build & run

```sh
git clone https://github.com/pikabrofar/sentidoS.git
cd sentidoS/Ojos
make run      # builds build/Ojos.app and opens it
make test     # runs the GazeKit test suite
```

You can also open `Package.swift` in Xcode and run the `Ojos` scheme.
The app must run from a bundle for the camera permission prompt to appear, so
use `make run` instead of `swift run`.

## Using it

1. Grant camera access on first launch.
2. Click **Calibrate…** and follow the nine dots with your eyes, keeping your
   head still. It takes about 20 seconds. The results screen shows the error at
   each target, and a live gaze circle you can use to check the fit.
3. Turn on **Show gaze cursor** (⇧⌘G), or press **Record** (⌥⌘R, which works
   from any app) to capture a session.
4. Open **Recordings** to view the heatmap or scanpath, overlay it on your
   screen, or export it.

Expect roughly 2–4° of accuracy (about 80–150 pt on a laptop), which is typical
for webcam eye tracking. That's enough to tell which region of the screen
you're looking at, but not which word. Head movement is compensated. Recalibrate
after moving the camera or switching displays.

## How it works

```
AVCaptureSession (1080p, 420f)
  └─ VNDetectFaceRectanglesRequest rev 3 ─ head yaw / pitch / roll
  └─ VNDetectFaceLandmarksRequest rev 3, 76-pt ─ eye contours + pupils
       └─ PupilRefiner ─ dark-blob centroid in the luma plane
       └─ eye-local features ─ pupil relative to eye corners, roll-compensated,
                               normalized by eye width; blink detection
  └─ GazeCalibration ─ geometric model:
       head position from face box (pinhole) ─ gaze angles = eye polynomial + head yaw/pitch
       ─ ray intersected with the estimated screen plane
       └─ refit on every click (implicit recalibration)
  └─ FixationStabilizer ─ holds still during fixations, jumps on confirmed saccades
  └─ spring animation ─ renders jumps smoothly at display rate
  └─ normalized screen point (0…1)
```

**Features.** For each eye, the pupil position is measured relative to the two
eye corners, in a frame rotated to level the eyes, and divided by eye width. This
makes the features roughly invariant to distance from the camera and to head
tilt. The two eyes are averaged to reduce noise.

**Pupil refinement.** Vision's pupil landmark jitters by a few pixels. The
refiner shrinks the eye contour vertically (to exclude eyelashes) and finds the
point inside it where the image gradients converge (Timm and Barth's means of
gradients, with a sub-pixel peak). If the result lands too far from Vision's
estimate, it's discarded.

**Geometric model.** ojoS models the physical setup instead of fitting a
plain feature regression:

- Camera frame in mm, with the screen as the plane z = 0, hanging below the camera.
- Head distance comes from the face box's apparent size, and lateral offset from
  its image position (pinhole camera with a 72° FOV).
- Gaze angles are a quadratic polynomial of eye-in-head features, plus learned
  weights on Vision's head yaw and pitch.
- The gaze ray from the head is intersected with the screen plane.

Calibration fits the eye polynomial and the layout together with
Levenberg–Marquardt on on-screen error in mm. The layout is the camera position
along the top edge, the camera-to-screen gap, a distance scale, and the head
rotation weights. Priors keep weakly observed parameters physical. When you move
your head after calibrating, the ray origin and direction change for physical
reasons, so the model extrapolates instead of drifting. The Calibrate page shows
the estimated layout.

**Calibration** takes about 45 s and borrows from published methods:

| Step | What it does | Borrowed from |
|---|---|---|
| 9-point grid | Stable anchor targets across the screen | Standard in Tobii/EyeLink |
| Smooth pursuit (16 s) | A dot on a Lissajous path gives hundreds of distinct targets. Frames are matched to the dot's position at capture time (host clock). Windows where eye movement doesn't correlate with the dot are dropped. | Pfeuffer et al., UIST 2013 |
| Head motion (8 s) | Fixed dot while the head moves, which identifies the head parameters | — |
| Validation (5 points) | Held-out points. Reports accuracy (mean offset to median gaze) and precision (RMS sample-to-sample) in degrees, then they're folded into the final model | Tobii / Holmqvist data-quality measures |

**Eye-appearance model.** Each eye is resampled to a 10×6 grayscale patch
aligned to its corners and histogram-equalized, giving 120 values for both eyes.
Ridge regression maps them to the gaze-angle residual left by the geometric
model. The ridge penalty is chosen on the validation points, and the model is
dropped entirely if it doesn't reduce held-out error. The Calibrate page shows
whether it's on.

Details of the fixation steps: each dot appears, pauses for 0.5 s so the eyes can settle,
then collects samples for 1–3.5 s, until it has a steady fixation, while its ring shrinks. Blinks are
dropped. Last, you hold your gaze on the center dot for 8 s while moving your
head. The target stays fixed while the head pose varies, and this is what
identifies the head parameters. The model is fit, samples with residuals above
3× the median are removed, and the model is fit again. Eyelid openness is also a feature, because the
upper lid follows the eye when you look down.

**Gaze CNN (optional).** ojoS can run an appearance-based gaze network on
the face crop each frame through Vision and Core ML. Its two output angles become
extra terms in the gaze-angle polynomial. Calibration learns which output is
which axis, the signs, and the per-user bias. That linear per-user correction is
the standard way to personalize a generic gaze CNN. To build one from
[MobileGaze](https://github.com/yakhyo/gaze-estimation) (MobileOne-S0 by default;
set `ARCH=resnet18` and so on for larger models):

```sh
make cnn-model   # downloads PyTorch + weights (~500 MB), writes build/GazeCNN.mlpackage
```

Then open **Settings → Gaze CNN → Load Model…** and recalibrate. MobileGaze's
code is MIT, but its weights were trained on
[Gaze360](https://github.com/erkil1452/gaze360/blob/master/LICENSE.md), whose
terms allow non-commercial research use only (including models trained on it)
and forbid redistribution. The script asks you to confirm that before it
downloads anything. No model is bundled in this repo or in releases; never
share or host one you convert. Gaze360: Kellnhofer et al., "Gaze360: Physically
Unconstrained Gaze Estimation in the Wild", ICCV 2019. Any Core ML model with an image input and a 2-value output
works.

**Handling human error.** People don't fixate like machines:

- *Refocusing and undershoot.* Eyes often land short of a dot, then make a
  corrective saccade. For each point, only the longest stable fixation is kept
  (I-DT with a noise-adaptive threshold), so the approach and correction are
  dropped.
- *Loss of focus.* If no steady fixation is found (looked away, blinked, face
  lost), the point is shown again at the end. A dot also advances as soon as a
  1 s fixation is found, so you don't wait on points you've already nailed.
- *Deviation from the point.* Drift and microsaccades within a fixation remain.
  The fit uses Huber-weighted least squares, so moderate misses count linearly
  and gross outliers (more than 5σ) are ignored, instead of hard trimming.
- *Pursuit lag.* Eye latency varies by person. It's estimated per calibration
  by aligning eye and dot motion, and catch-up saccades are removed.
- *During use.* Blinks hold the cursor, and dwell time doesn't run while your
  eyes are closed. Looking off-screen for 4 frames hides it, instead of pinning
  it to an edge.

**Learning from clicks** (like WebGazer). You almost always look at what you click. On each
mouse or trackpad click, the steady frames from the previous 300 ms become
samples for the click point, and the model is refit (up to 400 click samples).
A click is ignored when the gaze in those frames was moving (a saccade) or more
than 2.5× the calibration's accuracy (3–8°) from the click. Synthetic clicks,
ojoS's own and manoS's look-and-pinch, are never learned: they land where gaze
predicted. This corrects head movement and posture changes since calibration.
Turn it off in Settings → Accuracy.

**Smoothing.** Webcam gaze noise is larger than eye movements within a
fixation, so a low-pass filter either jitters or lags. `FixationStabilizer`
holds the cursor at the running mean of the current fixation. It moves only
after several consecutive samples agree on a new spot, so single noisy frames
are ignored, and so are outliers on opposite sides of the cursor. Blinks are
held, including the half-open frames on either side of one, which would read
as a downward glance. A critically damped spring animates each jump.

## Using GazeKit in your own app

```swift
import GazeKit

let camera = CameraCapture()
let extractor = FaceFeatureExtractor()
var stabilizer = FixationStabilizer(radius: 0.06) // same units as input
var calibration: GazeCalibration? // from GazeCalibration.fit(samples:geometry:)

try camera.configure()
camera.onFrame = { pixelBuffer, time in
    guard let features = extractor.analyze(pixelBuffer: pixelBuffer, timestamp: time).features,
          !features.isBlinking, let calibration else { return }
    let gaze = stabilizer.update(calibration.predict(features), at: time) // normalized, top-left origin
}
camera.start()
```

Other building blocks: `FixationDetector` (I-DT) and `HeatmapRenderer`.

## Project layout

```
Sources/GazeKit/        tracking library (no UI)
Sources/Ojos/     SwiftUI app: Engine/, Calibration/, Overlay/, Recording/, Views/
Tests/GazeKitTests/     regression, filter, fixation, and geometry tests
scripts/                app bundling and icon generation
```

Data is stored in `~/Library/Application Support/Ojos/`.

## Contributing

Issues and PRs are welcome. Ideas that would make a real difference:

- Drift correction from implicit fixations (for example, on clicks)
- Head-movement compensation with 3D face pose
- A gaze CNN trained on commercially licensed data, so a model can ship with the app

## License

MIT. See [LICENSE](LICENSE).
