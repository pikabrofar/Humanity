# Humanity

Open-source macOS software for controlling your computer with your eyes, hands
and voice, using just a webcam and microphone. Camera and audio are processed on-device
with Apple's frameworks: no extra hardware, no account, and cloud AI only if
you add your own key.

**Humanity** is one app that holds every module. They share one camera, so they
can run side by side and, later, combine: look at a button and pinch to click.
Each module also builds as a standalone app.

| Module | What it does | Status |
|---|---|---|
| [OculOS](OculOS/) | Eye tracking: calibrated gaze cursor, heatmaps, recordings | Beta |
| [ManOS](ManOS/) | Hand-gesture mouse: point with your palm, pinch to click, drag and scroll | Beta |
| [Murmur](Murmur/) | Voice: hold-to-talk dictation into any app, recordings with on-device summaries | Beta |
| [MeetingKit](MeetingKit/) | Meeting capture (mic + app audio), on-device speaker separation, voice profiles, labeled transcripts (used by Murmur → Meetings) | Beta |
| [AIKit](AIKit/) | Optional bring-your-own-key AI (Groq, Gemini, OpenAI, Anthropic, OpenRouter, Ollama…) for summaries and more | Beta |

## Install

Download **Humanity** (or a single module) from
[Releases](https://github.com/pikabrofar/Humanity/releases) and drag it to
Applications. It isn't notarized yet, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click
**Open Anyway**. Each app then walks you through a one-minute Quick Setup.

See [PRIVACY.md](PRIVACY.md) for exactly what is stored and what (little) goes over the network.

## Requirements

- macOS 14 Sonoma or later
- A webcam (the built-in FaceTime camera works)
- Xcode 16+ or just the Command Line Tools with Swift 6 (`xcode-select --install`)

```sh
git clone https://github.com/pikabrofar/Humanity.git
cd Humanity/Humanity && make run      # the all-in-one app
```

Each module is a Swift package with a reusable core library (`GazeKit`,
`HandKit`, `MurmurKit`), a UI module (`OculOSUI`, `ManOSUI`, `MurmurUI`)
and a thin standalone app.
`scripts/package.sh <App>` builds a DMG locally.

### Keeping permissions across rebuilds

Local builds are ad-hoc signed with the signing requirement pinned to the bundle
ID, so macOS keeps your camera and Accessibility grants after a rebuild. Don't
share these builds. For a stable signature, create a code-signing certificate
named **Humanity Self-Signed** in Keychain Access (Certificate Assistant →
Create a Certificate → Code Signing), then build with
`SIGN_ID="Humanity Self-Signed" make app`.

## Research

The design draws on [22 research notes](research/README.md) covering competing
products, HCI literature, accessibility, Apple APIs, privacy and distribution,
plus a roadmap distilled from them.

## License

MIT. See [LICENSE](LICENSE).
