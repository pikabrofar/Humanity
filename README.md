# Humanity

Open-source macOS software for controlling your computer with your eyes, hands
and voice, using just a webcam and microphone. Everything runs on-device with
Apple's Vision framework: no extra hardware, no cloud.

**Humanity** is one app that holds every module. They share one camera, so they
can run side by side and, later, combine: look at a button and pinch to click.
Each module also builds as a standalone app.

| Module | What it does | Status |
|---|---|---|
| [VisionGaze](VisionGaze/) | Eye tracking: calibrated gaze cursor, heatmaps, recordings | Beta |
| [ManOS](ManOS/) | Hand-gesture mouse: point with your palm, pinch to click, drag and scroll | Beta |
| [Murmur](Murmur/) | Voice: hold-to-talk dictation into any app, recordings with on-device summaries | Beta |

## Install

Download **Humanity** (or a single module) from
[Releases](https://github.com/pikabrofar/oculOS/releases) and drag it to
Applications. It isn't notarized yet, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click
**Open Anyway**. Each app then walks you through a one-minute Quick Setup.

Everything runs on your Mac. See [PRIVACY.md](PRIVACY.md).

## Requirements

- macOS 14 Sonoma or later
- A webcam (the built-in FaceTime camera works)
- Xcode 15+ or just the Command Line Tools (`xcode-select --install`)

```sh
git clone https://github.com/pikabrofar/oculOS.git
cd oculOS/Humanity && make run      # the all-in-one app
```

Each module is a Swift package with a reusable core library (`GazeKit`,
`HandKit`, `MurmurKit`), a UI module (`VisionGazeUI`, `ManOSUI`, `MurmurUI`)
and a thin standalone app.
`scripts/package.sh <App>` builds a DMG locally.

## Research

The design draws on [22 research notes](research/README.md) covering competing
products, HCI literature, accessibility, Apple APIs, privacy and distribution,
plus a roadmap distilled from them.

## License

MIT. See [LICENSE](LICENSE).
