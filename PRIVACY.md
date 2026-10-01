# Privacy

sentidoS apps watch your face and hands and listen to your voice. This page
explains exactly what they do with that.

## What goes over the network

Camera frames and audio are processed on your Mac and never uploaded. The apps
have no analytics, telemetry, crash reporting or update checks. They make
network requests in only these cases:

- **Cloud AI, if you set it up.** In AI Providers you can connect your own API
  key (Groq, Gemini, OpenAI, Anthropic, OpenRouter and others) for a task such
  as summaries or dictation cleanup. Only then is that task's *text* (a
  transcript, never audio) sent to the provider you chose, under its terms.
  Keys live in your macOS Keychain. Every task defaults to on-device. Dictation
  while macOS reports a password field (secure input) is never sent, cleaned up
  or saved. Some apps and web pages don't report this, so don't dictate passwords.
- **Speaker-separation models.** The first time you process a meeting, MeetingKit
  downloads its Core ML models (pyannote and WeSpeaker, via FluidAudio) from
  Hugging Face.
- **Apple's speech models.** On macOS 26, macOS may download its on-device speech
  model the first time you dictate. Apple handles this download.
- **Donations.** "Support sentidoS…" opens a Gumroad page in your browser. If you
  donate, Gumroad handles the payment under its own privacy policy; the apps
  never contact Gumroad themselves.
- **Scripts you run yourself**, such as ojoS's `make cnn-model`.

## What is stored

Everything is stored under `~/Library/Application Support/`, and you can delete
it at any time.

- **Camera video is never saved or uploaded.** Each frame is analyzed in memory and
  discarded, except for the tiny eye crops ojoS keeps for calibration (below). Otherwise only derived data is kept:
  - **ojoS** (`Ojos/`) saves your calibration: eye-feature measurements, a
    few model parameters and small 10×6-pixel eye patches. It also saves the
    gaze recordings you start (gaze coordinates and an optional screenshot).
    To delete it, use ojoS → Calibrate → Clear Calibration, or delete the folder.
  - **manoS** saves your pinch thresholds and settings in macOS preferences. Nothing else.
- **bocaS** (`Bocas/Recordings/`) saves your dictations and notes: text, and
  audio for notes (dictation audio only if you turn that on). Delete them in Library, or delete the folder.
- **Meetings** (`Sentidos/Meetings/`) saves each meeting's mic and call audio,
  the transcript and its summary.
- **Voice profiles** (`Sentidos/VoiceProfiles/`) save a numeric voiceprint for
  each person you name, so bocaS can recognize them in later meetings. Delete
  profiles in Meetings → Voice Profiles.

Gaze data and voiceprints can count as biometric data under laws like the GDPR.
Tell people when you record a meeting, and follow your local consent laws.

## Biometric data and retention

Some data the apps create on your Mac may count as biometric data under laws
such as Illinois BIPA, Texas CUBI and Colorado's biometric law. The developer
never receives any of it. Retention schedule:

| Data | Purpose | Kept until |
|---|---|---|
| Voice profiles (voiceprints) | Recognize people you named in later meetings | You delete them; automatically after 12 months unused, and at most 3 years |
| ojoS calibration (eye measurements, 10×6-pixel eye crops), including up to 400 samples taken when you click while tracking ("Learn from clicks", on by default, can be turned off in ojoS settings) | Estimating where you look | You clear or redo calibration |
| Speaker voiceprints inside each meeting (people not remembered) | Letting you choose "Remember this voice" later | Removed 30 days after the meeting (checked when Meetings opens), or when you delete the meeting |
| Meeting audio and transcripts | Your record of the call | You delete them |
| Dictations and notes | Your history | You delete them, or automatically after 30, 90 or 365 days if you choose |
| ojoS gaze recordings and screenshots | Heatmaps you asked for | You delete them |

Before saving someone's voiceprint, the app asks you to confirm they agreed.
Settings → Data → **Delete All sentidoS Data** erases the apps' files and settings
on this Mac (not AI provider keys, which you remove in AI Providers, and not copies
in your own backups such as Time Machine)
(Settings → bocaS → **Delete All bocaS Data** erases just recordings, meetings
and voice profiles). sentidoS never uses this data to infer health,
emotions or other sensitive traits.

## Children

sentidoS is not directed to children under 13, and its developer collects no
personal information from users of any age: everything the apps record stays on
your Mac. Don't create voice profiles of children, and don't record children
without their parent or guardian's permission.

## Permissions

All permissions are granted to **sentidoS** once. Each one is used for:

- **Camera** (ojoS, manoS): tracking.
- **Microphone** (bocaS): dictation, notes, and your side of a meeting.
- **Speech Recognition** (bocaS): Apple's on-device transcription.
- **System audio recording** (Meetings): the other side of a call.
- **Accessibility** (manoS, bocaS, ojoS): moving the pointer, clicking,
  pasting dictation, and snapping gaze clicks to buttons.
- **Screen Recording** (optional): heatmap screenshots in ojoS, and capturing
  call audio on older macOS.

Don't take our word for it. The code is short. Camera code is in
`Ojos/Sources/GazeKit/CameraCapture.swift`, and all network code is in
`AIKit/` and MeetingKit's `Diarizer.swift`.
