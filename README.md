# oculOS

A collection of open-source macOS apps for controlling and understanding your
computer with just a webcam. Everything runs on-device with Apple's Vision
framework: no extra hardware, no cloud.

| App | What it does | Status |
|---|---|---|
| [VisionGaze](VisionGaze/) | Eye tracking: calibrated gaze cursor, heatmaps, recordings | Working |
| Hand gesture control | Point, pinch to click, and scroll with your hands | Planned |

## Requirements

- macOS 14 Sonoma or later
- A webcam (the built-in FaceTime camera works)
- Xcode 15+ or just the Command Line Tools (`xcode-select --install`)

Each app is a self-contained Swift package. See its README to build it.

## Research

[docs/research](docs/research/) collects thirty reports on camera eye and hand
tracking (gaze models, pupil detection, calibration, filtering, hand pose,
gestures, macOS input injection, gaze + hand interaction, accessibility,
privacy, performance, CI and distribution, and more), plus a combined roadmap.
[docs/reviews](docs/reviews/) holds a code review of VisionGaze and a review
of the repository and research.

## License

MIT. See [LICENSE](LICENSE).
