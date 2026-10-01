# Privacy

Humanity apps watch your face and hands and listen to your voice. This page
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
  into password fields is never sent.
- **Speaker-separation models.** The first time you process a meeting, MeetingKit
  downloads its Core ML models (pyannote and WeSpeaker, via FluidAudio) from
  Hugging Face.
- **Apple's speech models.** On macOS 26, macOS may download its on-device speech
  model the first time you dictate. Apple handles this download.
- **Scripts you run yourself**, such as OculOS's `make cnn-model`.

## What is stored

Everything is stored under `~/Library/Application Support/`, and you can delete
it at any time.

- **Camera frames are never stored.** Each frame is analyzed in memory and
  discarded. Only derived numbers are kept:
  - **OculOS** (`OculOS/`) saves your calibration: eye-feature measurements, a
    few model parameters and small 10×6-pixel eye patches. It also saves the
    gaze recordings you start (gaze coordinates and an optional screenshot).
    To delete it, use OculOS → Calibrate → Clear Calibration, or delete the folder.
  - **ManOS** (`ManOS/`) saves your pinch thresholds and settings. Nothing else.
- **Murmur** (`Murmur/Recordings/`) saves your dictations and notes: text, and
  audio for notes. Delete them in Library, or delete the folder.
- **Meetings** (`Humanity/Meetings/`) saves each meeting's mic and call audio,
  the transcript and its summary.
- **Voice profiles** (`Humanity/VoiceProfiles/`) save a numeric voiceprint for
  each person you name, so Murmur can recognize them in later meetings. Delete
  profiles in Meetings → Voice Profiles.

Gaze data and voiceprints can count as biometric data under laws like the GDPR.
Tell people when you record a meeting, and follow your local consent laws.

## Permissions

All permissions are granted to **Humanity** once. Each one is used for:

- **Camera** (OculOS, ManOS): tracking.
- **Microphone** (Murmur): dictation, notes, and your side of a meeting.
- **Speech Recognition** (Murmur): Apple's on-device transcription.
- **System audio recording** (Meetings): the other side of a call.
- **Accessibility** (ManOS, Murmur, OculOS): moving the pointer, clicking,
  pasting dictation, and snapping gaze clicks to buttons.
- **Screen Recording** (optional): heatmap screenshots in OculOS, and capturing
  call audio on older macOS.

Don't take our word for it. The code is short. Camera code is in
`OculOS/Sources/GazeKit/CameraCapture.swift`, and all network code is in
`AIKit/` and MeetingKit's `Diarizer.swift`.
