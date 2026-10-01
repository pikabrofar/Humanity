<div align="center">

<img src="docs/assets/hero.svg" alt="sentidoS: control your Mac with eyes, hands and voice. The menu bar panel shows the ojoS, manoS and bocaS toggles." width="100%">

<br>
<br>

<a href="https://github.com/pikabrofar/sentidoS/releases"><img alt="Download for macOS" src="https://img.shields.io/badge/Download%20for%20macOS-d2692a?style=for-the-badge&logo=apple&logoColor=white"></a>
<a href="https://gumroad.com/l/hamkad"><img alt="Support development" src="https://img.shields.io/badge/Support-3f3f46?style=for-the-badge&logo=gumroad&logoColor=white"></a>
<img alt="macOS 14+" src="https://img.shields.io/badge/macOS%2014%2B-27272a?style=for-the-badge">
<img alt="Apple silicon" src="https://img.shields.io/badge/Apple%20silicon-27272a?style=for-the-badge">
<img alt="License: MIT" src="https://img.shields.io/badge/MIT%20license-27272a?style=for-the-badge">

</div>

sentidoS is a small menu bar app that lets you control your Mac with your
**eyes**, **hands** and **voice**, using the webcam and microphone you already
have. Video and audio are processed on your Mac with Apple's own frameworks.
There's no account, no subscription and no license key: it's free and open
source. The names are Spanish: *sentidos* are senses, *ojos* eyes, *manos*
hands and *bocas* mouths.

## Modules

<table>
<tr>
<td rowspan="3" width="36%" valign="top">
<img src="docs/assets/sentidos-icon.png" width="112" alt="sentidoS icon">
<h3>sentidoS</h3>
<b>One menu bar app, all three modules.</b><br><br>
They share one camera, and you switch each on or off from the panel. With ojoS and manoS both on, you can <b>look at a button and pinch to click</b>.
</td>
<td width="64" valign="top"><img src="docs/assets/ojos-icon.png" width="56" alt="ojoS icon"></td>
<td valign="top">
<b>ojoS</b> &nbsp;<sub>eye tracking</sub><br>
A calibrated gaze cursor, hotkey or optional dwell clicks that snap to buttons, gaze recordings and heatmaps.
</td>
</tr>
<tr>
<td width="64" valign="top"><img src="docs/assets/manos-icon.png" width="56" alt="manoS icon"></td>
<td valign="top">
<b>manoS</b> &nbsp;<sub>hand-gesture mouse</sub><br>
Point with your palm, pinch to click, drag and scroll, and flick a V sign for next or previous.
</td>
</tr>
<tr>
<td width="64" valign="top"><img src="docs/assets/bocas-icon.png" width="56" alt="bocaS icon"></td>
<td valign="top">
<b>bocaS</b> &nbsp;<sub>voice</sub><br>
Hold-to-talk dictation into any app, voice notes with summaries, and meetings with speaker labels and a consent flow.
</td>
</tr>
</table>

## How it works

<img src="docs/assets/flow.svg" alt="The camera feeds Apple Vision, which drives ojoS and manoS. The microphone feeds Apple Speech, which drives bocaS. All of it runs on your Mac; an AI provider is optional and only gets transcript text." width="100%">

- **Eyes:** Vision face landmarks and a gradient-based pupil detector feed a
  geometric gaze model. You calibrate it once with a 9-point grid, a moving
  target and a head-motion pass.
- **Hands:** Vision hand pose, smoothed with a 1€ filter. Pinches are judged
  against your own calibrated hand, and each click is timed to the start of
  the pinch.
- **Voice:** Apple's on-device speech recognizer. Meetings add on-device speaker
  separation, and you can choose to remember voices with the person's
  consent.

## Install

1. Download **sentidoS** (or a single module) from
   [Releases](https://github.com/pikabrofar/sentidoS/releases) and drag it to
   Applications.
2. Open it once and click **Done**. sentidoS isn't notarized by Apple yet.
3. Open **System Settings → Privacy & Security**, click **Open Anyway** and enter
   your password.
4. Follow the one-minute Quick Setup. Every permission is granted once, to
   sentidoS.

Requires macOS 14 or later on Apple silicon. sentidoS is **free**: nothing is
locked, and paying changes nothing. If it's useful to you, you can
[support development](https://gumroad.com/l/hamkad) with an optional donation.

## Controls

| Shortcut or gesture | What it does |
|---|---|
| <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>H</kbd> | Turn hand control on or off (kill switch) |
| <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>D</kbd> | Hold to dictate, release to insert the text. Tap to start or stop |
| <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>G</kbd> | Click where you look |
| <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>E</kbd> | Turn dwell clicking on or off |
| <kbd>⌥</kbd><kbd>⌘</kbd><kbd>R</kbd> | Start or stop a gaze recording |
| <kbd>Esc</kbd> | Cancel dictation or a dwell click |
| Open hand, move palm | Move the pointer |
| Thumb + index pinch | Click; hold and move to drag |
| Thumb + middle pinch | Right-click; hold and move to scroll |
| Fist | Hold the pointer still while you reposition |
| V sign, flick up or down | Next or previous video, page or slide |

Your real mouse always takes over, and the menu bar panel shows what's on.

## Privacy at a glance

- **Never uploaded:** camera video and microphone audio.
- **Stays on your Mac:** calibration, recordings, transcripts and voice
  profiles. Delete it all from Settings → Data.
- **Over the network:**
  - a one-time download of the speaker-separation models;
  - transcript text sent to an AI provider, only if you add your own key.
- **Not included:** no analytics, telemetry or crash reporting.

[PRIVACY.md](PRIVACY.md) lists exactly what is stored and for how long.

## Build from source

Requires macOS 14+, and Xcode 16+ or just the Command Line Tools with Swift 6.

```sh
git clone https://github.com/pikabrofar/sentidoS.git
cd sentidoS/Sentidos && make run      # the all-in-one app
```

| Package | What's inside |
|---|---|
| [Sentidos](Sentidos/) | The menu bar app that hosts every module |
| [Ojos](Ojos/) | `GazeKit` (camera, gaze model, calibration) and `OjosUI` |
| [Manos](Manos/) | `HandKit` (pose, gestures, pointer mapping) and `ManosUI` |
| [Bocas](Bocas/) | `BocasKit` (dictation, notes, cleanup) and `BocasUI` |
| [MeetingKit](MeetingKit/) | Call capture, speaker separation, voice profiles |
| [AIKit](AIKit/) | Optional bring-your-own-key AI (Groq, Gemini, OpenAI, Anthropic, Ollama…) |

`make test` in a package folder runs its tests, and `scripts/package.sh <App>`
builds a DMG.

<details>
<summary><b>Keeping permissions across rebuilds</b></summary>

Local builds are ad-hoc signed, with the signing requirement pinned to the
bundle ID, so macOS keeps your camera and Accessibility grants after a rebuild.
Don't share these builds. For a stable signature, create a code-signing
certificate named **Sentidos Self-Signed** in Keychain Access (Certificate
Assistant → Create a Certificate → Code Signing), then build with
`SIGN_ID="Sentidos Self-Signed" make app`.
</details>

## Limitations and safe use

- sentidoS is general-purpose input software, **not a medical or assistive
  device**. Keep a keyboard and mouse or trackpad available, and don't rely on
  it for anything urgent or safety-critical.
- Webcam tracking is approximate (ojoS typically lands within 2-5°) and can
  misread you, so clicks and keystrokes can land in the wrong place.
- Recording a call or saving someone's voiceprint may require their consent by
  law. In Massachusetts and several other states, everyone on a call must agree.
  The app asks you to confirm before each recording.

## Research

The design draws on [22 research notes](research/README.md) covering competing
products, HCI literature, accessibility, Apple APIs, privacy and distribution.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Third-party components are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), and use of the project's
names is covered in [TRADEMARKS.md](TRADEMARKS.md). See also the
[Terms of Use](TERMS.md).

<sub>sentidoS is not affiliated with or endorsed by Apple. Mac and macOS are trademarks of Apple Inc.</sub>
