# MeetingKit

Records voice meetings and calls (Zoom, Google Meet, Teams, FaceTime, Discord, browser calls), works out who spoke when, recognizes people from saved voice profiles, and produces a speaker-labeled transcript. All processing happens on the Mac.

Products:

- **MeetingKit**: capture, diarization, voice profiles, transcription and export.
- **MeetingUI**: compact SwiftUI views (`MeetingRecorderControl`, `MeetingDetailView`, `VoiceProfilesView`).

Requires macOS 14 or later. Builds with the Command Line Tools alone: run `swift build`, then `make test` (Swift Testing).

## Architecture

```
            ┌── mic (AVAudioEngine) ───────────────► mic.m4a      "You", exact
 Record ────┤
            └── app audio ─ process tap (14.4+) ──► system.m4a   everyone else
                           └ ScreenCaptureKit fallback
                                 │ (both padded to one host-clock origin)
 After the call (MeetingProcessor):
   system.m4a ─► FluidDiarizer ─► segments [start, end, cluster] + centroid per cluster
   both files ─► SpeechFileTranscriber ─► timed words
   centroids ─► VoiceProfileStore.assign ─► "Alice" / "Speaker 1"…
   TranscriptAligner ─► MeetingTranscript (turns) ─► markdown() / plainText
```

- **Two tracks.** The microphone and the meeting app are recorded separately. Your words come from your own device, so they are labeled "You" with no guessing, and diarization only has to separate the remote voices. `TrackWriter` stamps buffers with the host clock and pads gaps with silence, so frame *N* in either file falls at the same moment.
- **System audio.** `ProcessTapCapture` uses a Core Audio process tap (`CATapDescription` + `AudioHardwareCreateProcessTap` in a private aggregate device). It records only the chosen app's processes, including browser helpers, and the call keeps playing normally. On macOS before 14.4, or if the tap fails, `ScreenCaptureAudio` uses `SCStream` with `capturesAudio` and `excludesCurrentProcessAudio`. Choose "All system audio" for a call in an app that isn't listed.
- **Diarization.** [FluidAudio](https://github.com/FluidInference/FluidAudio) 0.17 (Apache-2.0) runs its offline pipeline: pyannote community-1 segmentation, WeSpeaker 256-d embeddings and VBx clustering, all in Core ML. It runs once after the meeting, which is more accurate than live diarization. The models download from Hugging Face on first use into `~/Library/Application Support/FluidAudio/Models`. FluidAudio also links a prebuilt text-normalization binary (about 8 MB) that MeetingKit doesn't use. Dropping it needs swift-tools 6.2 traits, which isn't worth the bump.
- **Transcription.** This follows Murmur: on macOS 26 it uses `SpeechAnalyzer`/`SpeechTranscriber` with `audioTimeRange` attributes for word timings. Otherwise it uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition`, fed windows under a minute long and cut at quiet points.
- **Alignment.** Each system-track word goes to the diarization segment it overlaps most. Words in gaps go to the nearest segment. Words are grouped into utterances per track before the tracks are interleaved, so crosstalk becomes two whole turns rather than alternating fragments. A mic word that matches a system word within 0.5 s is treated as speaker echo and dropped.
- **Voice profiles.** `VoiceProfileStore` keeps `~/Library/Application Support/Humanity/VoiceProfiles/profiles.json`: a name plus up to 20 L2-normalized embeddings per person. Each cluster centroid is compared with a profile's embeddings by cosine similarity, and the best one counts. Assignment is one-to-one, most confident pair first. `matchThreshold` defaults to **0.5**. FluidAudio's own streaming matcher accepts 0.35, but a wrong name is worse than "Speaker 2". Raise the threshold if similar voices get confused; lower it if known people stay unnamed. Automatic matches never change a profile. Naming a speaker only labels the transcript; embeddings are saved only when the user also attests the person agreed (`Meeting.name(speaker:as:rememberWithConsentAt:in:)`), so a wrong match leaves nothing to undo. Profiles store `consentAt` and `lastMatchedAt`, and are deleted on load when unused for 12 months or 3 years after consent.

## Integrating

```swift
let recorder = MeetingRecorder()                 // @MainActor ObservableObject
let apps = MeetingRecorder.availableApps()       // [AudioApp], playing first
try await recorder.start(.app(apps[0]), consentConfirmedAt: Date()) // or .allSystemAudio; after the user confirms consent
let recording = await recorder.stop()!           // MeetingRecording (mic.m4a + system.m4a)

let profiles = VoiceProfileStore()
var meeting = try await MeetingProcessor().process(recording, profiles: profiles) // saves meeting.json
meeting.transcript.markdown(title: recording.title) // "**Alice** [00:01:23]: …"
meeting.transcript.plainText                         // "Alice: …" lines for AIKit
try meeting.name(speaker: "S2", as: "Bob", rememberWithConsentAt: Date(), in: profiles); try meeting.save()
let reopened = try Meeting.load(from: recording.folder)
```

The UI pieces are `MeetingRecorderControl(recorder:onFinish:)`, `MeetingDetailView(meeting: $meeting, profiles:)` and `VoiceProfilesView(store:)`.

## Permissions (host app Info.plist / TCC)

| Need | Key / permission |
|---|---|
| Microphone track | `NSMicrophoneUsageDescription`; the App Sandbox also needs `com.apple.security.device.audio-input` |
| Process tap (macOS 14.4+) | `NSAudioCaptureUsageDescription`. macOS shows a one-time audio-capture prompt. There is no API to check the result: if access is denied, the tap delivers silence. |
| ScreenCaptureKit fallback | Screen Recording permission in System Settings › Privacy & Security |
| Transcription on macOS 14–15 | `NSSpeechRecognitionUsageDescription` (SFSpeechRecognizer authorization) and on-device Dictation installed for the language |
| First-run model downloads | Network access for the FluidAudio models and, on macOS 26, Apple's speech assets. Audio is never uploaded. |

## Privacy and consent

- **Tell participants before you record.** Many jurisdictions require consent from every party, and the recorder UI says so. Some meeting apps also show their own recording notices, and MeetingKit does not trigger those.
- Recordings stay in `~/Library/Application Support/Humanity/Meetings/<date>/`. Delete that folder to remove a meeting.
- Voice profiles store only embeddings, numeric voiceprints of timbre. They are biometric data: name people only with their agreement, and delete a profile when asked.
- Nothing is sent off the Mac. The only network use is downloading models.

## Accuracy limits

- **Overlapping speech.** Each word gets exactly one speaker. When two remote people talk at once, words go to whichever segment overlaps them most, and FluidAudio produces exclusive segments. Crosstalk between you and a remote speaker is handled well because the two are on separate tracks.
- **Similar voices.** Siblings, or people of the same gender and accent on a narrowband phone bridge, can end up in one cluster or match the wrong profile. Raise `matchThreshold`, or set `FluidDiarizer(expectedSpeakers:)` when the count is known.
- **Shared rooms.** Several people on one remote mic are separated by diarization as usual. Several people sharing *your* mic are all labeled "You", because the mic track isn't diarized.
- **Echo.** Without headphones the mic picks up the remote side. Identical words close in time are removed, but misrecognized echo can still appear as "You". Headphones avoid the problem.
- **Short speakers.** Someone who says only a few words may not get a reliable embedding. They can be folded into another cluster or matched with low confidence.
- **Cross-meeting drift.** A profile built from a headset recording may not match the same person on a laptop mic. Naming them again adds the new conditions as another sample.
- **macOS 14–15 transcription.** SFSpeechRecognizer is much less accurate (about 9% WER versus about 2% for SpeechAnalyzer), and a word can occasionally split at a window boundary.
- **Process tap scope.** The tap covers the app processes that exist when recording starts. Start recording after you've joined the call. If a browser starts a new audio helper midway, record "All system audio" instead.
