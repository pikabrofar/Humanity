# Privacy

Humanity apps watch your face and hands, and listen to your voice, so here is
exactly what they do with that.

- **Nothing leaves your Mac.** The apps make no network requests: no analytics,
  no telemetry, no crash reporting, no update checks. Only scripts you run
  yourself download anything (for example, VisionGaze's `make cnn-model`).
- **Camera frames are never stored.** Each frame is analyzed in memory and
  discarded. Only derived numbers are kept:
  - **VisionGaze** saves your calibration: eye-feature measurements and a few
    model parameters, plus small 10×6-pixel eye patches used by the appearance
    model. It also saves recordings you start, which hold gaze coordinates and an
    optional screenshot.
  - **ManOS** saves your pinch thresholds and settings. Nothing else.
- **Eye-tracking data is sensitive.** Under laws like the GDPR, gaze can count as
  biometric data. It stays in `~/Library/Application Support/<App>/`, and you
  can delete it at any time: VisionGaze → Calibrate → Clear Calibration, or
  delete the folder.
- **Permissions, and why each app needs them:**
  - Camera (VisionGaze, ManOS): tracking.
  - Accessibility (ManOS): moving the pointer and clicking.
  - Screen Recording (VisionGaze, optional): the screenshot behind a heatmap.

Don't take our word for it. The code is short, and the camera code lives in
`VisionGaze/Sources/GazeKit/CameraCapture.swift`.
