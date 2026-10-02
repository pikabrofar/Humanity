# Changelog

All notable changes to sentidoS are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **manoS:** the pointer follows the palm measured from the image centre, so
  leaning toward or away from the camera barely moves it (a quick 15% lean
  moved it ~380 pt before). Mostly vertical or horizontal scrolls lock to that
  axis, like on a trackpad.
- **ojoS:** click learning uses only mouse and trackpad clicks made during a
  steady look near the click (within 2.5× the calibration's accuracy). Before,
  manoS's look-and-pinch clicks, which land where gaze predicted, were learned
  as truth and pushed real clicks out of the sample buffer.
- **bocaS:** a model's rewrite is used only when it reuses the words you said,
  so a dictated question is never replaced by its answer, a translation or a
  refusal. The filler and stutter rules run only for English.

### Fixed

- **manoS:** a hand that comes into view already pinched (holding a pen or a
  mug), or a pinch held past 15 s, no longer clicks. A click right after a drag
  no longer jumps back to where the drag began, and drags no longer leap at the
  start. Fingers that rest near the click threshold no longer slow the pointer
  to a quarter speed. Crossed pinch sliders can't make a held pinch flicker.
  Holding an open palm still pauses at any frame rate, and a slowly moving palm
  never does. Stalled camera frames now also end a scroll. The hand that holds a
  button keeps control when the other hand comes into view. Flick arrow keys no
  longer pick up held modifier keys, and moves and drags now carry motion deltas
  for apps that read them.
- **ojoS:** the half-open frames around a blink no longer read as a glance down
  and move the cursor, and eyes kept shut for more than 0.5 s now count as
  closed instead of becoming the new "open". Two noisy samples on opposite sides
  of the cursor no longer make it jump, and samples on either side of a lost
  face no longer confirm a saccade. Dwell no longer counts time with your eyes
  closed, so it can't click while you rest them. Snapping radii follow the
  display's current resolution. Gaze recordings no longer merge a look away and
  back into one long fixation.
- **bocaS:** two dictations in a row no longer lose your clipboard. Cleanup no
  longer breaks web and email addresses ("apple.Com"), "i.e." and "a.m.",
  "mm-hmm", units ("5 mm"), acronyms ("ER") or repeated digits ("7 7 3 9"), and
  keeps "you know" when it's meant ("If you know, tell me"). Chinese and
  Japanese get "。", Thai gets no period. A dictation that was only fillers
  pastes nothing. A model call that runs past its time limit is now cancelled.
  Summaries read Markdown headings, "Action item:" and "Next steps:", and drop
  "No action items were mentioned."; one failed chunk no longer discards the
  whole summary. Delete All Data during "Polishing…" no longer saves the
  dictation again. A transcript containing `</details>` no longer breaks the
  Markdown export.

## [1.0.0] - 2026-10-01

First public release. sentidoS is a free, MIT-licensed macOS menu bar suite for
controlling your Mac with your eyes, hands and voice, using the webcam and
microphone you already have. It requires Apple silicon and macOS 14 or later.

### Added

- **sentidoS**, a compact menu bar app that hosts all three modules and shares
  one camera between them. Three toggles turn modules on and off (Liquid Glass
  on macOS 26, tinted circles before that), with one-minute Quick Setup, a
  tutorial and a single place to grant permissions.
- **ojoS (eye tracking):** a calibrated gaze cursor using Vision face landmarks,
  gradient-based (Timm and Barth) pupil centers and a geometric gaze model.
  Calibration uses a 9-point grid, a moving target and a head-motion pass.
  Includes a look-ahead saccade filter, Ctrl-Option-Command-G to click where you
  look, optional dwell clicks with a progress ring that snap to nearby buttons,
  and gaze recordings with heatmaps.
- **manoS (hand gestures):** point with your palm, pinch thumb and index to click
  or drag, pinch thumb and middle to right-click or scroll, make a fist to hold
  the pointer still, and flick a V sign to jump to the next or previous video,
  page or slide. Uses Vision hand pose with a 1-euro filter, pinch thresholds
  calibrated to your hand, an adaptive region of interest for distant hands, and
  fatigue and posture hints.
- **Look and pinch:** with ojoS and manoS both on, gaze aims and a pinch clicks.
- **bocaS (voice):** hold-to-talk dictation into any app with
  Ctrl-Option-Command-D, voice notes with summaries, custom words, and on-device
  transcription with Apple's speech recognizer.
- **bocaS Meetings:** mic and call audio capture (process tap with a
  ScreenCaptureKit fallback), on-device speaker separation, transcripts with
  speaker labels, summaries and optional voice profiles.
- **AIKit:** optional bring-your-own-key AI providers (Groq, Gemini, OpenAI,
  Anthropic, OpenRouter, Ollama and others) for summaries and dictation cleanup.
  Every task defaults to on-device.
- Signed release builds from GitHub Actions with the hardened runtime, per-app
  entitlements and a SHA-256 checksum for each DMG. Each module is also
  available as a standalone app.

### Safeguards

- Ctrl-Option-Command-H is a kill switch for hand control, and hand control
  never resumes on launch. Your real mouse always takes over.
- Dwell clicking starts off on each launch, avoids dialogs and close buttons,
  and can be toggled with Ctrl-Option-Command-E. Esc cancels a dwell click or
  dictation. Held buttons are released if camera frames stall.
- Meetings show a recording banner that can't be closed, a menu bar indicator
  and 30-minute reminders. Each recording needs a consent checkbox (the time is
  saved), and Copy to Chat helps you announce it. There is no silent
  all-system-audio fallback, and Stop and Delete discards a recording.
- A call transcript is sent to a cloud AI provider only after you confirm.
- Dictation is never sent, cleaned up or saved while macOS reports a password
  field, control and invisible characters are stripped before typing, and a
  concealed clipboard is never restored.
- No features designed for covert recording or tracking of other people.

### Privacy

- Camera video and microphone audio are processed on the Mac and never
  uploaded. There are no analytics, telemetry, crash reporting or update checks.
- The only network requests are cloud AI (only with your own key, and only
  text), a one-time download of the speaker-separation models, Apple's
  on-device speech model download, and the donation page opened in your browser.
- Saving a voiceprint is opt-in and requires confirming the person agreed.
  Voice profiles are deleted after 12 months unused and kept at most 3 years.
  Voiceprints of people you didn't remember are removed after 30 days.
- Data lives in owner-only folders under Application Support. Voiceprints and
  ojoS calibration are excluded from backups. Delete All sentidoS Data erases
  everything on the Mac, and dictation history can expire after 30, 90 or 365
  days.
- PRIVACY.md documents every stored file, every network path and a biometric
  data retention schedule. TERMS.md, TRADEMARKS.md, SECURITY.md and
  THIRD_PARTY_NOTICES.md ship alongside it.

### Changed

- sentidoS is free. Nothing is locked and the apps never contact Gumroad. An
  optional pay-what-you-want donation at https://gumroad.com/l/hamkad unlocks
  nothing and changes nothing. License keys and the activation window were
  removed before release.
- Renamed the suite from Humanity to sentidoS, and its modules from OculOS to
  ojoS (eyes), ManOS to manoS (hands) and Murmur to bocaS (voice). Bundle IDs
  are now io.github.pikabrofar.sentidos, .ojos, .manos and .bocas. Existing data
  in the old Application Support folders moves over automatically on first
  launch.

[Unreleased]: https://github.com/pikabrofar/sentidoS/compare/sentidos/v1.0.0...HEAD
[1.0.0]: https://github.com/pikabrofar/sentidoS/releases/tag/sentidos/v1.0.0
