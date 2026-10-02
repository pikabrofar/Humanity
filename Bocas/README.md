# bocaS

Part of [sentidoS](../README.md). Dictate into any Mac app: press a shortcut,
speak, and clean text appears at your cursor. bocaS also records longer voice
notes and writes summaries and action items for them. Everything runs on your
Mac. There's no account and no analytics, and cloud AI is used only if you add
your own key in AI Providers.

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
cd sentidoS/Bocas
make run    # builds build/Bocas.app and opens it
make test   # unit tests (Swift Testing)
```

Ad-hoc signing changes on every build, so macOS forgets permission grants each
time you rebuild. To keep them, sign with a stable identity:
`SIGN_ID="sentidoS Self-Signed" make app`.

On first launch, **Quick Setup** asks for the microphone, Speech Recognition and
(optionally) Accessibility, then gives you a box to try dictation in.

## How it works

| Step | macOS 26 | macOS 14–15 |
|---|---|---|
| Speech to text | `SpeechAnalyzer` + `SpeechTranscriber`, streaming | `SFSpeechRecognizer` with `requiresOnDeviceRecognition` |
| Cleanup | Apple Foundation Models (when Apple Intelligence is on) | Deterministic rules: fillers, stutters, punctuation, capitalization |
| Summary + action items | Foundation Models, chunked to fit its 4K context | Opening sentences + sentences that sound like tasks |
| Insertion | Clipboard + synthesized ⌘V, then the old clipboard is restored; typed into terminals and password fields | Same |

If Apple Intelligence is unavailable, or the model's reply doesn't look like an
edit of what you said (it answered a question you dictated, translated it, or
brought in words you didn't say), bocaS uses the rules instead. The filler and
stutter rules apply to English only; other languages get spacing, punctuation
and capitalization.

## Privacy

- **Audio never leaves your Mac.** bocaS doesn't use cloud recognition: if
  on-device recognition isn't installed for your language, it shows an error
  rather than sending audio to Apple's servers. On macOS 26 the first use of a
  language downloads Apple's speech model, which is shared by all apps.
- Cleanup and summaries run on Apple's on-device model, or on local rules.
- No screenshots, and no reading of other apps' content. The only thing bocaS
  notes is the frontmost app's name, which is saved with each dictation.
- Pasted text is marked `org.nspasteboard.TransientType`, so clipboard managers
  skip it. Your previous clipboard is put back after 1–2 s (busy apps read the
  clipboard late, and longer text waits longer), unless you copied something
  else in the meantime. Two dictations in a row still put back your clipboard.
- Recordings are plain files in `~/Library/Application Support/Bocas/Recordings`
  (`<id>.m4a` + `<id>.json`). You can delete them in the app, in Finder, or
  stop saving dictations in Settings.

## Layout

- `Sources/BocasKit`: pure logic, no UI. Contains the recording model and file
  store, the cleanup rules, summary parsing and fallback, Markdown export,
  clipboard-restore sequencing, and the tap/hold hotkey logic. All of it is
  unit-tested.
- `Sources/BocasUI` (run by the `Bocas` app target): the audio engine,
  transcribers, Foundation Models, paste injection, the HUD and the views.

## Limitations

- Text is typed instead of pasted into terminals and password fields. Other
  apps that block ⌘V don't receive it.
- There are no per-app modes or configurable shortcut yet.
- The legacy engine (macOS 14–15) is noticeably less accurate than the macOS 26
  one.
