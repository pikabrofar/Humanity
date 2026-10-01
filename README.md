# OculOS

A collection of open-source macOS apps for controlling and understanding your
computer with just a webcam. Everything runs on-device with Apple's Vision
framework: no extra hardware, no cloud.

| App | What it does | Status |
|---|---|---|
| [VisionGaze](VisionGaze/) | Eye tracking: calibrated gaze cursor, heatmaps, recordings | Beta |
| [ManOS](ManOS/) | Hand-gesture mouse: point with your palm, pinch to click, drag and scroll | Beta |
| Voice app | On-device dictation, recordings and summaries | In progress |

## Install

Download a DMG from [Releases](https://github.com/pikabrofar/oculOS/releases)
and drag the app to Applications. OculOS isn't notarized yet, so macOS blocks
the first launch. Open **System Settings → Privacy & Security** and click
**Open Anyway**. Each app then walks you through a one-minute Quick Setup.

Everything runs on your Mac. See [PRIVACY.md](PRIVACY.md).

## Requirements

- macOS 14 Sonoma or later
- A webcam (the built-in FaceTime camera works)
- Xcode 15+ or just the Command Line Tools (`xcode-select --install`)

Each app is a self-contained Swift package. See its README to build it.
`scripts/package.sh <App>` builds a DMG locally.

## Research

The design draws on [22 research notes](research/README.md) covering competing
products, HCI literature, accessibility, Apple APIs, privacy and distribution,
plus a roadmap distilled from them.

## License

MIT. See [LICENSE](LICENSE).
