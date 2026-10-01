# Murmur

Part of [Humanity](../README.md). Dictate into any Mac app: press a shortcut,
speak, and clean text appears at your cursor. Murmur also records longer voice
notes and writes summaries and action items for them. Everything runs on your
Mac. There's no account, no cloud and no analytics.

## Using it

| Shortcut | Action |
|---|---|
| **⌃⌥⌘D** (tap) | Start dictating. Tap again to finish and paste. |
| **⌃⌥⌘D** (hold) | Push-to-talk. Release to finish and paste. |
| **Esc** | Cancel while recording. Nothing is pasted or saved. |

A small pill near the bottom of the screen shows the input level and the words
as they're recognized. **Record a Note** (in the app or the menu bar) saves a
recording to the **Library** instead of pasting it. In the Library you can
search, play back, summarize and export recordings to Markdown.

## Build

You only need the Command Line Tools (`xcode-select --install`).

```sh
cd oculOS/Murmur
make run    # builds build/Murmur.app and opens it
make test   # unit tests (Swift Testing)
```

Ad-hoc signing changes on every build, so macOS forgets permission grants each
time you rebuild. To keep them, sign with a stable identity:
`SIGN_ID="oculOS Dev" make app`.

On first launch, **Quick Setup** asks for the microphone, Speech Recognition and
(optionally) Accessibility, then gives you a box to try dictation in.

## How it works

| Step | macOS 26 | macOS 14–15 |
|---|---|---|
| Speech to text | `SpeechAnalyzer` + `SpeechTranscriber`, streaming | `SFSpeechRecognizer` with `requiresOnDeviceRecognition` |
| Cleanup | Apple Foundation Models (when Apple Intelligence is on) | Deterministic rules: fillers, stutters, punctuation, capitalization |
| Summary + action items | Foundation Models, chunked to fit its 4K context | Opening sentences + sentences that sound like tasks |
| Insertion | Clipboard + synthesized ⌘V, then the old clipboard is restored | Same |

If Apple Intelligence is unavailable or the model's reply doesn't look like an
edit of what you said, Murmur uses the rules instead.

## Privacy

- **Audio never leaves your Mac.** Murmur doesn't use cloud recognition: if
  on-device recognition isn't installed for your language, it shows an error
  rather than sending audio to Apple's servers. On macOS 26 the first use of a
  language downloads Apple's speech model, which is shared by all apps.
- Cleanup and summaries run on Apple's on-device model, or on local rules.
- No screenshots, and no reading of other apps' content. The only thing Murmur
  notes is the frontmost app's name, which is saved with each dictation.
- Pasted text is marked `org.nspasteboard.TransientType`, so clipboard managers
  skip it. Your previous clipboard is put back after 0.5 s, unless you copied
  something else in the meantime.
- Recordings are plain files in `~/Library/Application Support/Murmur/Recordings`
  (`<id>.m4a` + `<id>.json`). You can delete them in the app, in Finder, or
  stop saving dictations in Settings.

## Layout

- `Sources/MurmurKit`: pure logic, no UI. Contains the recording model and file
  store, the cleanup rules, summary parsing and fallback, Markdown export,
  clipboard-restore sequencing, and the tap/hold hotkey logic. All of it is
  unit-tested.
- `Sources/Murmur`: the SwiftUI app. Contains the audio engine, transcribers,
  Foundation Models, paste injection, the HUD and the views.

## Limitations

- Pasting doesn't work in apps that block ⌘V, such as some terminals and
  secure fields. There's no typing fallback yet.
- There's no custom vocabulary, per-app modes or configurable shortcut yet.
- The legacy engine (macOS 14–15) is noticeably less accurate than the macOS 26
  one.
