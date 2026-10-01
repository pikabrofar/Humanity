# Dictation App Landscape (Wispr Flow-style) for oculOS

## Summary
The category has settled on one interaction: **hold a hotkey, speak, release, and cleaned-up text appears at the cursor.** Products now compete on four things: latency, how well they handle custom vocabulary, how they adapt to each app, and how much they can be trusted with privacy. Cloud leaders (Wispr Flow, Aqua Voice) win on polish and LLM cleanup. Their pain points are privacy (screen capture sent to their servers), latency spikes, outages and subscription cost. On-device apps (VoiceInk, Superwhisper, Spokenly, MacWhisper) prove that local Whisper or Parakeet is good enough. oculOS can stand out by being fully local, auditable and free, with on-device cleanup and on-device context.

## Key findings

| App | Model | Notable features | Pricing |
|---|---|---|---|
| **Wispr Flow** | Cloud | Context awareness (tone set per app: Slack, email, docs), personal dictionary that learns words, snippets/voice shortcuts, filler-word removal and auto-formatting | Free 2k words/wk; Pro $15/mo ($12 annual); Enterprise $24 |
| **Superwhisper** | Local + cloud | "Modes" = model + prompt + hotkey; modes assigned per app; recording window with waveform and mode switcher; default ⌥Space push-to-talk | Pro $8.49/mo or $249.99 lifetime; BYOK only on Pro |
| **MacWhisper** | Local | Strongest at transcribing files and meetings, not live dictation | Pro about €64 one-time |
| **Aqua Voice** | Cloud (Avalon) | "Deep Context" reads the screen; 800-term dictionary; Instant mode (~450 ms) and Streaming mode (~850 ms); strong on code terms | Pro from about $8/mo |
| **VoiceInk** | Local (whisper.cpp, Parakeet via FluidAudio, SenseVoice) | GPL-3.0; **Power Mode** applies settings by active app *and URL*; dictionary plus text replacements; push-to-talk on keyboard or mouse; macOS 15+ | Free to build; paid binary |
| **Spokenly** | Local + BYOK | Local models free and unlimited, no account needed | Pro $99.99/yr (cloud, sync) |
| **Apple Dictation** | On-device (mostly) | Free, built in | Free; no custom vocabulary, stops after 30 s of silence, plain text only, some requests still go to Apple's servers |

- **Praise:** speed compared with typing (one reviewer logged 352k words at 126 WPM in Aqua), filler removal, tone matched to each app, Superwhisper's flexible modes, and local apps that need no account.
- **Complaints:** Wispr Flow screenshotted the active window every few seconds and uploaded the images, and the company's first response was to ban the user who reported it. Other complaints: 1–2 s cloud round-trip, an 8–10 s cold start, about 800 MB RAM and 8% CPU while idle (Windows build), freezing target apps, a 2.7/5 Trustpilot score, paywalls on BYOK and lifetime licenses, and loss of the user's clipboard.
- **Text insertion:** the common method is to put the text on the clipboard, synthesize Cmd+V, then restore the previous clipboard. Its problems are clipboard managers recording the text, fixed delays and terminals that block paste. Better implementations mark the pasteboard item as transient or concealed so clipboard managers skip it, and restore the old clipboard after the target app reads it. The fallback is typing the text with `CGEventKeyboardSetUnicodeString` in UTF-16 chunks. Setting `kAXSelectedTextAttribute` through the Accessibility API works only in some fields. Note that `CGPreflightPostEventAccess` can return false even when `AXIsProcessTrusted` is true.
- **New platform option:** macOS 26 SpeechAnalyzer/SpeechTranscriber runs on-device at about 3x the speed of Whisper Small. Together with Apple's Foundation Models, this gives a zero-download path for both transcription and cleanup.

## Recommendations (ranked)
1. **MVP core loop:** hold-to-talk on a configurable key (Fn or right-⌥), plus double-tap for hands-free mode and Esc to cancel. Show a small floating HUD pill near the bottom center with a live waveform, the current mode and a "processing" state. Insert text by paste with a transient pasteboard item and clipboard restore, falling back to typed Unicode keystrokes. Allow a per-app override, defaulting to typing in terminals. The target is under 500 ms from key release to text on short phrases.
2. **Two engines from day one:** Parakeet (FluidAudio/CoreML) as the default for speed in English, and whisper.cpp for multilingual use. Add SpeechAnalyzer as a zero-download option on macOS 26. Keep the model warm in memory to avoid Wispr Flow's cold-start problem.
3. **On-device cleanup as a toggle:** remove fillers, fix punctuation, handle self-corrections ("no, I mean…") and format lists. Run it on Apple Foundation Models or a small MLX/llama.cpp model, with a strict "never answer, only rewrite" prompt and a raw-text fallback if it fails.
4. **Personal dictionary and replacements:** feed vocabulary to the model (Whisper initial prompt or Parakeet boosting) plus deterministic find-and-replace. Offer one-click "add to dictionary" from history. Snippets (e.g. "my address") are cheap to build and well loved.
5. **Per-app modes (Power Mode-style):** match on bundle ID or URL to choose tone, cleanup prompt and language. **Differentiator:** "local context" reads only the focused field's text and the app name through the Accessibility API, entirely on-device. It never takes screenshots, and the UI shows exactly what it read. This turns Wispr Flow's scandal into oculOS's selling point.
6. **History and recordings:** a searchable local SQLite store with audio, raw and cleaned text, one-click re-insert or re-process, and long-form recordings with on-device summaries and action items (covering what MacWhisper does). Include retention settings and auto-delete.
7. **Trust features as product:** no account, no network traffic by default (provable with an offline mode and Little Snitch-style transparency), an MIT/Apache license (more permissive than VoiceInk's GPL), and BYOK cloud as strictly opt-in. Keep idle RAM low and publish benchmarks for latency and memory.
8. **Defer:** voice commands ("delete that", "new paragraph" beyond the basics), sync, iOS and streaming partial results.

## Sources
- https://www.techjockey.com/us/detail/wispr-flow
- https://efficient.app/apps/wispr-flow
- https://www.getvoibe.com/resources/wispr-flow-review/
- https://www.getvoibe.com/resources/is-wispr-flow-reliable/
- https://vocai.net/blog/wispr-flow-review-privacy-2026/
- https://spokenly.app/blog/wispr-flow-review
- https://github.com/Beingpax/VoiceInk
- https://www.getvoibe.com/resources/voiceink-review/
- https://superwhisper.com/docs/get-started/interface-rec-window
- https://spokenly.app/blog/superwhisper-review
- https://spokenly.app/blog/wispr-flow-vs-superwhisper-vs-macwhisper
- https://spokenly.app/comparison/superwhisper
- https://spokenly.app/blog/aqua-voice-review
- https://www.getvoibe.com/resources/aqua-voice-review/
- https://www.yaps.ai/blog/macos-tahoe-dictation-review-2026
- https://github.com/neogismm/megaphone
- https://github.com/GeiserX/akou/pull/100
- https://github.com/AshiqIqbal1/Whisperlet/pull/38
- https://vibetyper.com/blog/dictation-paste-preferences
