# sentidoS: Privacy Requirements (traced from the code)

| | |
|---|---|
| Scope | sentidoS suite v1.0.0 (`sentidoS`, `ojoS`, `manoS`, `bocaS`, `MeetingKit`, `AIKit`, `LicenseKit`) and the bundled dependency FluidAudio 0.17.4 (`MeetingKit/Package.resolved`) |
| Date | 2026-10-01 |
| Prepared by | Privacy engineering / research analysis. **This is not legal advice.** Every legal statement below is a pointer for counsel, not a conclusion. |
| Method | I read `PRIVACY.md`, `README.md` and `SECURITY.md`, then traced every sensor, file write, network call, log call, clipboard access, Accessibility (AX) call, window-list call and CGEvent post in the source. I searched every Swift source for `URLSession`, `URLRequest`, `FileManager`, `write(to:`, `UserDefaults`, `Logger`/`os_log`/`print`, `NSPasteboard`, `AXUIElement`, `CGWindowList`, `CGEvent`, `addGlobalMonitorForEvents`, `isExcludedFromBackup`, `posixPermissions` and `temporaryDirectory`. Where this document disagrees with the docs, the code wins. |
| Evidence format | `path:line` relative to the repo root. FluidAudio paths are under `MeetingKit/.build/checkouts/FluidAudio/`. |
| Baseline | **All line references are against git commit `e098368`** ("Launch prep: Gumroad license keys, 1.0.0, license notices"); I spot-checked them with `git show HEAD:<path>`. While this audit ran, other work modified about 40 files in the working tree without committing. Examples: `PRIVACY.md`, `README.md`, the `Info.plist` files, `LicenseKit`, `AIKit`, `ojoS` and `VoiceProfileStore.swift` (which gained `consentAt`, `lastMatchedAt` and retention), and `scripts/app.entitlements` was deleted. **Those uncommitted changes are not part of this audit.** Some of them start to address findings below. Re-run the §6 claim check and the §9 tests after they land, and in particular check that any new PRIVACY.md wording (such as consent prompts or "Delete All bocaS Data") matches the shipped code. |

---

## 0. Top findings (read this first)

1. **Dictation audio is saved to disk by default, contrary to PRIVACY.md.** When "Keep dictations in the Library" is on (the default), each dictation is recorded to `~/Library/Application Support/bocaS/Recordings/<UUID>.m4a` (`bocaS/Sources/MurmurUI/AppModel.swift:75-77,168-170`). PRIVACY.md says bocaS keeps "text, and audio for notes".
2. **Every meeting stores a voiceprint of every remote speaker, named or not.** `meeting.json` holds `diarization.centroids`, one 256-float WeSpeaker embedding per speaker cluster (`MeetingKit/Sources/MeetingKit/Transcript.swift:31-41`, `Meeting.swift:131`). They are kept indefinitely and survive deleting the matching voice profile. PRIVACY.md mentions only the "voice profiles" of people you name.
3. **Naming a speaker creates a voiceprint, with no consent step.** Typing a name in the "Who is this?" popover calls `VoiceProfileStore.enroll` or `refine` (`Meeting.swift:53-67`, `MeetingDetailView.swift:110-118`). Renaming and remembering a voice can't be done separately, and the person whose voice it is is never asked.
4. **Meeting recording has no consent gate.** The only safeguard is a static caption ("Tell everyone on the call…", `MeetingRecorderControl.swift:66-70`). If no app is playing audio, the source silently falls back to **All system audio** (`MeetingRecorderControl.swift:78-82,93`). The menu bar icon doesn't show that a meeting is being recorded (`sentidoS/Sources/sentidoS/HumanityApp.swift:548-550`).
5. **Cloud AI runs automatically on meetings and notes once configured.** If the user has picked a provider for "Summaries", every processed meeting and every note goes to that provider without asking again (`MeetingsView.swift:60,90`, `AppModel.swift:287,360`). For meetings, that means other participants' words and the names the user gave them.
6. **The "password fields are never sent" promise rests on a heuristic.** It holds only when macOS reports secure input (`IsSecureEventInputEnabled()`, `AppModel.swift:153,248`). Even when it works, the spoken password appears in the on-screen HUD while the user speaks (`bocaS/Sources/MurmurUI/Views/HUD.swift:84`).
7. **There's no "delete all data" control, no retention limit and no backup exclusion anywhere.** Time Machine backs up all of it, including raw meeting audio and voiceprints, and APFS local snapshots keep it too. If the app crashes mid-recording, the audio is left as an orphan file the UI never shows and "Delete All" never removes.
8. **The network surface matches the docs, with small gaps.** The only egress is Gumroad, the AI provider the user picked, Hugging Face (via FluidAudio) and Apple's own model downloads. I found no analytics, telemetry, crash reporting or update checks in the app or in FluidAudio's diarization path. The gaps: the license check runs at launch, not weekly; the AI settings screen fetches model lists automatically; and FluidAudio honors environment variables that can redirect its downloads.

---

## 1. Legal reference points (for counsel)

| Source | What matters here | URL |
|---|---|---|
| Illinois BIPA, 740 ILCS 14/10 | "Biometric identifier" means "a retina or iris scan, fingerprint, voiceprint, or scan of hand or face geometry". "Biometric information" is information based on a biometric identifier that is used to identify a person. | https://www.ilga.gov/legislation/ilcs/ilcs3.asp?ActID=3004&ChapterID=57 |
| BIPA 740 ILCS 14/15 | (a) A public retention schedule, with destruction when the purpose is satisfied or within 3 years of the last interaction. (b) Notice and a written release before collection. (e) Reasonable security. | same |
| Texas CUBI, Bus. & Com. Code § 503.001 | Biometric identifier includes "voiceprint" and "record of hand or face geometry". Notice and consent before capture for a commercial purpose. | https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm |
| Washington RCW 19.375 | Biometric identifiers enrolled for a commercial purpose. | https://app.leg.wa.gov/RCW/default.aspx?cite=19.375 |
| Washington My Health My Data Act, RCW 19.373 | "Consumer health data" includes biometric data. No revenue threshold. | https://app.leg.wa.gov/RCW/default.aspx?cite=19.373 |
| Colorado Privacy Act biometric amendment (HB24-1130, C.R.S. 6-1-1314) | Biometric duties apply to any controller that processes biometric identifiers, regardless of the CPA's volume thresholds. Requires a retention and deletion policy. | https://leg.colorado.gov/bills/hb24-1130 |
| CCPA/CPRA, Cal. Civ. Code § 1798.140 | Biometric information (subd. (c)) includes "imagery of the iris, retina, …" and "voice recordings, from which an identifier template, such as a faceprint, a minutiae template, or a voiceprint, can be extracted". Sensitive personal information (subd. (ae)) includes "the processing of biometric information for the purpose of uniquely identifying a consumer". Applicability thresholds are in subd. (d). | https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.140 |
| CPRA, Cal. Civ. Code § 1798.121 | Right to limit the use of sensitive personal information. | https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.121 |
| GDPR Art. 4(14), Art. 9(1) | Art. 4(14) defines biometric data. Art. 9(1) makes "biometric data for the purpose of uniquely identifying a natural person" special-category data. | https://eur-lex.europa.eu/eli/reg/2016/679/oj |
| GDPR Art. 2(2)(c), Recital 18 | Household exemption for purely personal activity. This likely covers a user processing their own data, but probably not recording and voiceprinting third parties in a work meeting (counsel). | same |
| GDPR Arts. 5(1)(c),(e), 13, 17, 25, 28, 35, 44-49 | Minimisation, storage limitation, transparency, erasure, privacy by design and default, processors, DPIA, international transfers. | same |
| UK GDPR / DPA 2018 | Mirrors the GDPR for UK users. | https://www.legislation.gov.uk/eur/2016/679/contents |
| Federal Wiretap Act, 18 U.S.C. § 2511(2)(d) | One-party consent baseline. | https://www.law.cornell.edu/uscode/text/18/2511 |
| California Penal Code § 632 | All-party consent for confidential communications. | https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PEN&sectionNum=632 |
| Illinois 720 ILCS 5/14-2 | All-party consent for private conversations. | https://www.ilga.gov/legislation/ilcs/fulltext.asp?DocName=072000050K14-2 |
| Florida Stat. § 934.03 | All-party consent. | http://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0900-0999/0934/Sections/0934.03.html |
| Washington RCW 9.73.030 | All-party consent. | https://app.leg.wa.gov/RCW/default.aspx?cite=9.73.030 |
| Massachusetts G.L. c. 272 § 99 | All-party consent for secret recording. | https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99 |
| Maryland Cts. & Jud. Proc. § 10-402 | All-party consent. | https://mgaleg.maryland.gov/mgawebsite/Laws/StatuteText?article=gcj&section=10-402 |
| Pennsylvania 18 Pa.C.S. § 5704 | All-party consent (with exceptions). | https://www.legis.state.pa.us/cfdocs/legis/LI/consCheck.cfm?txtType=HTM&ttl=18&div=0&chpt=57&sctn=4&subsctn=0 |
| Others commonly listed as all-party or partly all-party | Montana (MCA 45-8-213), New Hampshire (RSA 570-A:2), Connecticut (civil, phone), Delaware, Michigan, Nevada and Oregon (each nuanced). **Counsel must confirm the current list.** | — |
| COPPA, 16 CFR Part 312 (amended 2025) | The amended definition of personal information includes biometric identifiers (counsel to confirm effective and compliance dates). | https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312 |

**Threshold question for counsel:** in v1.0.0 the developer never receives any sensor data. Everything stays on the user's Mac, or goes to providers the user chose with their own keys. Most of these statutes regulate an entity that "collects, captures … or otherwise obtains" the data (BIPA 15(b)) or that is a "controller". Counsel needs to decide:
- whether shipping software that *creates and stores* voiceprints and face/eye geometry on the user's device makes the developer a collector or controller;
- whether the user is the collector instead, for example of their colleagues' voiceprints.

The engineering recommendations below are built to hold up either way.

---

## 2. Classification legend

- **RAW**: sensor output: pixels, audio samples or screen pixels.
- **DERIVED**: computed from raw data: landmarks, features, embeddings, transcripts.
- **BIOMETRIC**: may meet a statutory definition: voiceprint, face, hand or iris geometry or imagery, or a template that can be extracted from it.
- **SENSITIVE**: high harm if exposed, whether or not it is biometric: credentials, private conversations, screen contents, special categories.
- **PERSONAL**: relates to an identified or identifiable person (the user or **third parties**, marked "3P").
- **NON-PERSONAL**: settings, geometry or model files with no link to a person.

Several labels can apply at once.

---

## 3. Storage map (everything the code writes)

The apps are **not sandboxed**: `scripts/app.entitlements:5-10` declares only camera and audio input. So nothing is under `~/Library/Containers`. Every module, whether hosted by sentidoS or run as a standalone app, shares these paths.

| Path | Written by | Contents | Personal? |
|---|---|---|---|
| `~/Library/Application Support/ojoS/calibration.json` | `ojoS/Sources/OculOSUI/Engine/Persistence.swift:110-124` | Gaze model, calibration samples, up to 400 learned-click samples, display name and size | Yes, BIOMETRIC-adjacent |
| `~/Library/Application Support/ojoS/Recordings/<UUID>.json` | `ojoS/Sources/OculOSUI/Recording/RecordingStore.swift:84-89` | Gaze samples (t, x, y), name, date, duration, screen size | Yes |
| `~/Library/Application Support/ojoS/Recordings/<UUID>.png` | `RecordingStore.swift:56-58,90,93-98` | Full-display screenshot (optional) | Yes, SENSITIVE |
| `~/Library/Application Support/ojoS/Models/GazeCNN.mlmodelc`, `name.txt` | `Persistence.swift:87-108` | A Core ML model the user loaded | No |
| `~/Library/Application Support/VisionGaze/` (legacy) | Moved into `ojoS/` at first launch (`Persistence.swift:71-75`) | Old-name data | Yes |
| `~/Library/Application Support/bocaS/Recordings/<UUID>.json` | `bocaS/Sources/MurmurKit/RecordingStore.swift:13-16,27-33` | Transcript, cleaned text, summary, action items, target app, date, duration | Yes, SENSITIVE |
| `~/Library/Application Support/bocaS/Recordings/<UUID>.m4a` | `bocaS/Sources/MurmurUI/Engine/AudioRecorder.swift:28` via `AppModel.swift:168-170` | Mic audio of notes **and dictations** | Yes, SENSITIVE, BIOMETRIC-capable |
| `~/Library/Application Support/sentidoS/Meetings/<yyyy-MM-dd HH.mm.ss>/mic.m4a` | `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:17,81,86` | User's mic, mono AAC 48 kHz | Yes, SENSITIVE |
| `…/Meetings/<folder>/system.m4a` | `MeetingRecorder.swift:18,87` | Call app's (or all system) audio, stereo | Yes (3P), SENSITIVE |
| `…/Meetings/<folder>/recording.json` | `MeetingRecorder.swift:24-25,134` | Title ("<App> call"), start, duration, capture errors | Yes |
| `…/Meetings/<folder>/meeting.json` | `MeetingKit/Sources/MeetingKit/Meeting.swift:69-71,131`; `MeetingsView.swift:57,76` | Word-level timed transcript of both tracks, diarization segments, **per-speaker voice embeddings**, speaker names, profile IDs | Yes (3P), BIOMETRIC, SENSITIVE |
| `…/Meetings/<folder>/summary.json` | `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:101,119-121` | Summary, action items, per-speaker points | Yes (3P) |
| `~/Library/Application Support/sentidoS/VoiceProfiles/profiles.json` | `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:45-50,136-142` | Name, up to 20 voice embeddings each, last update | Yes (3P), BIOMETRIC |
| `~/Library/Application Support/sentidoS/license.json` | `LicenseKit/Sources/LicenseKit/License.swift:25-37` | License key (plaintext) and last verification time | Yes (pseudonymous) |
| `~/Library/Application Support/FluidAudio/Models/…` | FluidAudio `Sources/FluidAudio/Shared/MLModelConfigurationUtils.swift:37-42` | Diarization Core ML models downloaded from Hugging Face | No |
| `~/Library/Preferences/io.github.pikabrofar.humanity.plist` (standalone apps: `…humanity.ojoS`, `…humanity.manoS`, `…humanity.bocaS`) | `UserDefaults.standard` (§4.16) | Settings, hand profile, custom vocabulary, AI routing | Some |
| Login Keychain, generic password, service `io.github.pikabrofar.humanity.ai`, account `<providerID>` | `AIKit/Sources/AIKit/KeychainStore.swift:6-48` | AI provider API keys | Credential |
| Apple-managed speech assets (system location) | `bocaS/Sources/MurmurUI/Engine/Transcriber.swift:70-73`; `MeetingKit/Sources/MeetingKit/FileTranscriber.swift:46-49` | Apple speech model | No |
| Any location the user picks in a Save panel | `ojoS/Sources/OculOSUI/AppModel.swift:319-331`; `bocaS/Sources/MurmurUI/Views/LibraryView.swift:201-206`; `MeetingsView.swift:273-283` | CSV gaze samples, heatmap PNG (with screenshot), Markdown transcripts and summaries | Yes |
| `~/Library/Logs/DiagnosticReports/` | macOS, not app code | Crash reports | Low |

**Not written anywhere:** camera frames, the full 76-point face landmark set, hand landmarks, clipboard contents, AX element data, window lists, AI request and response bodies (`LLMClient.swift:32-40` uses an ephemeral session with `urlCache = nil`) and Gumroad response bodies. I found no temp-file use (`temporaryDirectory` doesn't appear in app sources).

---

## 4. Data inventory, category by category

Each entry lists: **Captured**, **Stored**, **Retention**, **Transmitted**, **Classification**, **Deletion control** and **Evidence**.

### 4.1 Camera frames

- **Captured.** 1080p video (falling back to 720p or `.high`) in 4:2:0 bi-planar luma/chroma, up to the camera's frame rate. Center Stage is forced off. Frames show the user's face, hands and surroundings, including bystanders.
- **Stored.** Nowhere. Each `CVPixelBuffer` goes to registered handlers, which run Vision (face rectangles and landmarks, hand pose) and, optionally, a user-loaded gaze CNN on the face crop. The buffers are then released. Live previews use `AVCaptureVideoPreviewLayer`, which draws to screen only. Late frames are dropped.
- **Retention.** Per frame, in memory only.
- **Transmitted.** No. There's no network code on this path.
- **Classification.** RAW · PERSONAL (user and 3P bystanders) · SENSITIVE · BIOMETRIC-capable (face and hand geometry can be extracted).
- **Deletion control.** Not applicable. Turning the camera off: in sentidoS it stops when no module needs it. The standalone ojoS starts the camera at launch.
- **Evidence.**
  - Frame handling: `ojoS/Sources/GazeKit/CameraCapture.swift:82-118` (configure), `:112-114` (format, discard late frames), `:192-202` (delegate passes the buffer to handlers and keeps nothing).
  - Analysis: `ojoS/Sources/GazeKit/FaceFeatureExtractor.swift:44-105`; `ojoS/Sources/GazeKit/GazeNetwork.swift:28-43`; `manoS/Sources/ManOSUI/Engine/HandEngine.swift:267-289`.
  - Previews: `ojoS/Sources/OculOSUI/Views/CameraPreview.swift:18`; `manoS/Sources/ManOSUI/Views/CameraView.swift:18`.
  - Camera on/off: `sentidoS/Sources/sentidoS/HumanityApp.swift:102-107` (pause); `ojoS/Sources/OculOSUI/AppModel.swift:88-90` (standalone starts at init).

### 4.2 Face and eye landmarks (and derived gaze features)

- **Captured.**
  - Vision 76-point face landmarks (revision 3) and face rectangles with yaw, pitch and roll.
  - Eye contours and pupils, with the pupil refined from luma gradients.
  - From those: per-eye pupil position relative to the eye corners, eye openness, blink state, face center and width (a proxy for distance), and CNN gaze angles if a model is loaded.
- **Stored.**
  - The full 76-point landmark set is **not** stored. `FaceLandmarksSnapshot` is UI-only and kept in memory.
  - The derived `GazeFeatures` (timestamp, both eyes' pupil and openness, yaw, pitch, roll, face center, face size, blink flag, eye-patch pixels, network gaze) **are stored**, inside every `CalibrationSample` in `calibration.json`:
    - explicit calibration samples: grid, smooth pursuit, head-motion and validation phases, typically hundreds to thousands;
    - **learned-click samples**: up to 400, rolling.
  - Learned-click samples come from a **global left-mouse-down monitor**, which is on by default (`learnFromClicks` defaults to `true`). Each click anywhere on the calibrated display stores the last ≤ 0.25 s of face features, tagged with the click position.
  - The fitted model (`GazeCalibration`) also stores feature means, an appearance model (mean eye patch plus weights), the display name, the screen size in points and `createdAt`.
- **Retention.** Indefinite. Recalibrating replaces the file and resets learned clicks. Learned clicks are capped at the newest 400.
- **Transmitted.** No.
- **Classification.** DERIVED · PERSONAL · BIOMETRIC-adjacent: head pose and eye geometry could be argued to be a "scan of face geometry" (BIPA) or used to uniquely identify a person (GDPR Art. 9); counsel to decide · SENSITIVE (gaze and blink can reveal health or attention traits).
- **Deletion control.** **Exists, partially.** ojoS → Calibrate → **Clear Calibration** deletes `calibration.json`, including the learned clicks. The button only appears when a calibration exists. There's no control for the legacy `VisionGaze` folder, because it is migrated rather than kept.
- **Evidence.**
  - Capture and features: `FaceFeatureExtractor.swift:36-41,51-104`; `ojoS/Sources/GazeKit/GazeFeatures.swift:20-37`; `ojoS/Sources/GazeKit/GazeCalibration.swift:5-8,70-80,421-425`.
  - Storage: `ojoS/Sources/OculOSUI/Engine/Persistence.swift:6-19` (fields and the 400 cap), `:110-124` (file); `ojoS/Sources/OculOSUI/Calibration/CalibrationController.swift:145-155` (the stored samples).
  - Learned clicks: `ojoS/Sources/OculOSUI/AppModel.swift:57-59` (default on), `:103-125` (global monitor); `ojoS/Sources/OculOSUI/Engine/GazeEngine.swift:226-227,277-298`.
  - Clear Calibration: `ojoS/Sources/OculOSUI/Views/CalibrationPage.swift:100` → `AppModel.swift:244-247` → `GazeEngine.swift:27-46` → `Persistence.swift:118-123`.

### 4.3 Eye patches

- **Captured.** For each eye, a 10 × 6 grid of luma (grayscale) samples, aligned to the eye corners, then rank-equalized to the range 0…1. That's 120 values per frame.
- **Stored.** Yes. They are the `appearance` field of every stored `GazeFeatures`, in both calibration samples and learned-click samples, plus the `AppearanceModel.mean` (an average patch) in `calibration.json`.
- **Retention.** Same as §4.2.
- **Transmitted.** No.
- **Classification.** DERIVED from RAW pixels; strictly, a tiny eye image · PERSONAL · BIOMETRIC-adjacent: CPRA "imagery of the iris" (§ 1798.140(c)). At 10 × 6 with rank equalization, iris recognition is implausible, but counsel should decide.
- **Deletion control.** Clear Calibration (as §4.2).
- **Evidence.** `ojoS/Sources/GazeKit/EyePatch.swift:7-9` (size), `:15-68` (sampling), `:71-77` (equalization); `FaceFeatureExtractor.swift:93`; `GazeCalibration.swift:421-425,439-451`.
- **Doc conflict.** `sentidoS/Resources/Info.plist:31-32` and `ojoS/Resources/Info.plist` say "Video is … never stored." PRIVACY.md is more accurate here: it mentions the patches.

### 4.4 Gaze coordinates and recordings

- **Captured.**
  - Live: the smoothed gaze point on the calibrated display, normalized 0…1, plus a 24-point trail, in memory.
  - Recording: started with ⌥⌘R, a global hotkey, or from the UI. Each sample is (t relative to the start, x, y). "Hide ojoS while recording" can hide the app.
- **Stored.** `ojoS/Recordings/<UUID>.json` holds the name (defaults to the date and time), date, duration, screen size and all samples. A recording is saved only if it has more than 10 samples.
- **Retention.** Indefinite.
- **Transmitted.** No. Export to CSV or PNG goes to a user-chosen file.
- **Classification.** DERIVED · PERSONAL · potentially SENSITIVE (attention patterns; some research links gaze dynamics to health conditions) · arguably behavioral-biometric (counsel).
- **Deletion control.** **Exists.** Recordings → Delete, per recording, removes the JSON and PNG. There's no bulk delete.
- **Evidence.**
  - Live gaze: `GazeEngine.swift:233-253`.
  - Recording: `ojoS/Sources/OculOSUI/AppModel.swift:91-93` (hotkey), `:255-290` (start and stop); `RecordingStore.swift:6-16,54-61,84-90`.
  - Delete: `ojoS/Sources/OculOSUI/Views/RecordingsPage.swift:16` → `RecordingStore.swift:69-74`.
  - Export: `AppModel.swift:319-331`.

### 4.5 Screenshots

- **Captured.** One still of the whole calibrated display at native pixel resolution, taken at the start of a gaze recording. It uses ScreenCaptureKit, leaves the cursor out and excludes only sentidoS's own windows. Everything else on screen is included: messages, documents, notifications, video-call participants' faces, and passwords if they're visible.
- **Stored.** `ojoS/Recordings/<UUID>.png`. The heatmap export composites it into a user-chosen PNG.
- **Retention.** Indefinite, until the recording is deleted.
- **Transmitted.** No.
- **Classification.** RAW · PERSONAL (user and 3P) · SENSITIVE · BIOMETRIC-capable if faces are on screen.
- **Deletion control.** **Exists**, with the recording (`RecordingStore.swift:73`). The setting is **off by default** (`AppModel.swift:54-56`) and needs Screen Recording permission.
- **Evidence.** `ojoS/Sources/OculOSUI/Recording/ScreenshotCapture.swift:8-19`; `AppModel.swift:265-268`; `RecordingStore.swift:54-61`; `ojoS/Sources/OculOSUI/Views/SettingsView.swift:111-114` (setting text: "Screenshots stay on this Mac").

### 4.6 Hand landmarks and hand calibration

- **Captured.** Vision hand pose for up to 2 hands per frame: 21 joints with chirality. These drive the pointer and gestures. During Quick Setup, about 45 frames of relaxed index-pinch distance and 3 pinch minima are collected.
- **Stored.**
  - Landmarks: not stored.
  - Hand profile (`HandProfile`: pinch enter and exit thresholds in palm units, sensitivity, scroll speed, invert, flick settings): stored as JSON in **UserDefaults** key `manoS.profile`. The handedness flag is stored as `manoS.leftHanded`.
  - **No `manoS/` folder is ever created**, contrary to PRIVACY.md.
- **Retention.** Indefinite. Recalibrating overwrites it.
- **Transmitted.** No.
- **Classification.** Landmarks: RAW/DERIVED, BIOMETRIC-capable ("scan of hand geometry"), but transient. Profile: DERIVED, PERSONAL, low sensitivity (a few scalars, though derived from hand geometry; counsel).
- **Deletion control.** **None in the app.** There's no reset; only `defaults delete` removes it.
- **Evidence.** `manoS/Sources/ManOSUI/Engine/HandEngine.swift:20-22,45-53,178,267-289`; `manoS/Sources/ManOSUI/Views/SetupView.swift:159-201`; `manoS/Sources/HandKit/HandProfile.swift:4-33,58-64`; `manoS/Sources/ManOSUI/Engine/Persistence.swift:5-29`.

### 4.7 Mic audio (dictation)

- **Captured.**
  - When it runs: only while dictating, by holding or tapping ⌃⌥⌘D. Esc cancels; it's registered as a global hotkey only during recording.
  - What: `AVAudioEngine` input tap, in the device's format, converted to 48 kHz mono AAC. Buffers go to the on-device recognizer.
  - Which recognizer: SpeechAnalyzer on macOS 26, or `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, which **refuses to run** if on-device recognition is unavailable.
- **Stored.** **Yes, by default.**
  - `saveAudio = (keepHistory && !secure) || kind == .note`, and `keepHistory` defaults to `true`, so dictation audio is written to `bocaS/Recordings/<UUID>.m4a` while you speak.
  - Deleted when: the session is cancelled, the transcript comes back empty, an error occurs, the app quits normally during a dictation, or secure input was detected at start **or** end.
- **Retention.** Indefinite while history is on. **A crash or force-quit mid-dictation leaves an orphan `.m4a` with no JSON.** `loadAll()` lists only `.json` files, so the orphan never appears in the Library, and "Delete All" iterates only listed recordings, so it never deletes it.
- **Transmitted.** No. There's no code path that uploads audio.
- **Classification.** RAW · PERSONAL · SENSITIVE · BIOMETRIC-capable (CPRA § 1798.140(c) counts voice recordings from which a voiceprint can be extracted) · may include 3P voices.
- **Deletion control.** **Exists.** Library → trash, per item, with confirmation; Settings → History → **Delete All Recordings…**; turning off "Keep dictations in the Library" stops future saves but doesn't purge existing ones.
- **Evidence.**
  - Recording and save logic: `bocaS/Sources/MurmurUI/Engine/AudioRecorder.swift:16-50,68-76`; `bocaS/Sources/MurmurUI/AppModel.swift:75-77,153-154,157-158,168-173,221-227,277-282,299-320,331-337`.
  - Recognizers: `bocaS/Sources/MurmurUI/Engine/Transcriber.swift:29-34,66-76,197-202`.
  - Store and delete: `bocaS/Sources/MurmurKit/RecordingStore.swift:36-48`; `AppModel.swift:396-406`; `bocaS/Sources/MurmurUI/MurmurModule.swift:126,134,142-145`.

### 4.8 Dictation text and history

- **Captured.**
  - Raw recognizer text, respelled with the user's "Custom words".
  - Cleaned text, if cleanup is on (the default):
    - a cloud provider, if one is set for "Dictation cleanup", with at most 2 s of waiting before falling back;
    - else Apple Intelligence on-device;
    - else built-in rules.
  - The frontmost app's **localized name** (for example "Notes").
  - Partial transcripts are shown live in a HUD panel on screen.
- **Stored.** `bocaS/Recordings/<UUID>.json` (pretty-printed) holds the id, `createdAt`, duration, kind, transcript, cleaned text, summary, action items and target app, if `keepHistory` is on. In **secure-input** sessions: no cleanup, no JSON, the audio deleted, and the text **typed** as synthetic keystrokes rather than pasted.
- **Retention.** Indefinite.
- **Transmitted.** Only if the user has set a cloud provider for "Dictation cleanup": the **raw text** goes to that provider. The 2 s timeout doesn't cancel a request already sent. Custom words go only to Apple's on-device recognizer as contextual strings.
- **Classification.** DERIVED · PERSONAL · SENSITIVE (anything dictated, including credentials whenever the secure-input heuristic misses).
- **Deletion control.** **Exists.** Per item, plus Delete All (§4.7).
- **Evidence.**
  - Data model: `bocaS/Sources/MurmurKit/Recording.swift:4-37`.
  - Flow: `AppModel.swift:153-154,159,165,246-282`; `AIKit/Sources/AIKit/Tasks.swift:77-85`; `bocaS/Sources/MurmurUI/Engine/Intelligence.swift:36-42`; `bocaS/Sources/MurmurUI/Engine/TextInserter.swift:45-62`; `bocaS/Sources/MurmurKit/PasteSequence.swift:25-27`.
  - HUD: `bocaS/Sources/MurmurUI/Views/HUD.swift:84`.

### 4.9 Notes audio

- **Captured.** Same pipeline as dictation, started from bocaS → Record a Note.
- **Stored.** **Always**: `bocaS/Recordings/<UUID>.m4a` plus `.json`. If transcription fails or returns nothing, the audio is kept with an empty transcript so it can be retried.
- **Retention.** Indefinite.
- **Transmitted.** The audio isn't. The note's **text** is summarized automatically after saving, and goes to a cloud provider if "Summaries" is set to one. "Summarize Again" re-sends it.
- **Classification.** RAW · PERSONAL · SENSITIVE · BIOMETRIC-capable · may include 3P (for example a recorded conversation).
- **Deletion control.** **Exists** (§4.7).
- **Evidence.** `AppModel.swift:168,279-287,299-311,355-375,378-394`; `LibraryView.swift:133,152,159`.

### 4.10 Meeting audio (mic + app audio)

- **Captured.** Two time-aligned tracks.
  - `mic.m4a`: the user's microphone ("You").
  - `system.m4a`: one of the following.
    - The **selected app's audio**, via a Core Audio process tap (macOS 14.4+).
    - **All system audio**: a global tap excluding only sentidoS, which picks up media, notifications and other apps.
    - The ScreenCaptureKit fallback. Its 2 × 2 video frames are received and ignored.
  - Default source: the first app currently playing audio; **otherwise All system audio, without a warning**.
- **Stored.**
  - Folder: `~/Library/Application Support/sentidoS/Meetings/<yyyy-MM-dd HH.mm.ss>/` holds `mic.m4a`, `system.m4a` and `recording.json`. `meeting.json` and `summary.json` are added after processing.
  - `recording.json` is written **only at stop**. A crash mid-meeting leaves a folder of audio with no JSON, which `unprocessed()` ignores. The UI never lists it, and it can't be deleted in the app.
  - Quitting normally stops and saves the recording, which is then offered for processing.
- **Retention.** Indefinite. Raw audio is kept after processing.
- **Transmitted.** The audio isn't. Processing may download models from Hugging Face (§5).
- **Classification.** RAW · PERSONAL (user and **3P**) · SENSITIVE (private conversations) · BIOMETRIC-capable · subject to wiretap/eavesdropping law.
- **Deletion control.** **Exists, per meeting**: a right-click context menu → Delete, without confirmation, removes the whole folder. There's **no bulk delete**.
- **Consent.** Only a caption, "Tell everyone on the call that you're recording before you start." There's no confirmation, no stored attestation and no menu-bar indicator. macOS shows its own microphone indicator.
- **Evidence.**
  - Recorder: `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:17-34,68-104,108-143,146-168,193-197`.
  - Capture paths: `MeetingKit/Sources/MeetingKit/Capture/ProcessTapCapture.swift:25-33`; `MeetingKit/Sources/MeetingKit/Capture/ScreenCaptureAudio.swift:12-41,47-48`; `MeetingKit/Sources/MeetingKit/Capture/TrackWriter.swift:31-50`.
  - UI: `MeetingKit/Sources/MeetingUI/MeetingRecorderControl.swift:22-28,66-70,78-82,93`; `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:104-112,161,170`; `sentidoS/Sources/sentidoS/HumanityApp.swift:548-550,565-573`.

### 4.11 Transcripts

- **Captured.**
  - Meetings: word-level transcripts with start and end times for both tracks, from on-device recognizers; the turns are aligned to diarization segments.
  - Notes and dictations: §4.8.
- **Stored.**
  - `meeting.json` holds `micWords`, `systemWords`, segments and speakers. The transcript itself is recomputed from these.
  - `summary.json` holds the summary text, action items and "Name: points" lines.
  - User exports: Markdown via the Save panel, or Copy to the clipboard.
- **Retention.** Indefinite.
- **Transmitted.** Each processed meeting's plain-text transcript, as "Name: text" lines including **names the user typed for other people**, is summarized automatically after processing. If "Summaries" is set to a cloud provider, it goes there in chunks (map-reduce). On-device fallback: Apple Intelligence, then extractive.
- **Classification.** DERIVED · PERSONAL (**3P**) · SENSITIVE.
- **Deletion control.** **Exists, per meeting** (the folder). bocaS items are covered by §4.7.
- **Evidence.**
  - Data: `MeetingKit/Sources/MeetingKit/Transcript.swift:4-14`; `Meeting.swift:5-25,104-133`.
  - Recognizers: `MeetingKit/Sources/MeetingKit/FileTranscriber.swift:44-49,86,116`.
  - Summaries: `MeetingsView.swift:56-60,81-102`; `AIKit/Sources/AIKit/Tasks.swift:39-73,99-114`.
  - Export and copy: `MeetingsView.swift:268-283`; `MeetingKit/Sources/MeetingUI/MeetingDetailView.swift:29-31`.

### 4.12 Diarization embeddings

- **Captured.** FluidAudio's offline pipeline (pyannote segmentation, WeSpeaker embeddings, VBx clustering) runs on `system.m4a` after the call. It produces segments and **one embedding (centroid) per speaker cluster**.
- **Stored.** `meeting.json` → `diarization.centroids`, for **every remote speaker cluster, whether named or not**. They are matched automatically against all saved voice profiles every time a meeting is processed (cosine ≥ 0.5, one-to-one).
- **Retention.** Indefinite. They are **not** removed when the matching voice profile is deleted, and `speakers[cluster].profileID` also stays.
- **Transmitted.** No.
- **Classification.** DERIVED · **BIOMETRIC** ("voiceprint", BIPA 14/10; used for unique identification, so GDPR Art. 9 and CPRA SPI) · PERSONAL (**3P**) · SENSITIVE.
- **Deletion control.** **Only by deleting the whole meeting.**
- **Evidence.** `MeetingKit/Sources/MeetingKit/Diarizer.swift:20-41`; `Transcript.swift:31-41`; `Meeting.swift:117-131`; `VoiceProfileStore.swift:82-94`.

### 4.13 Voice profiles

- **Captured.** When the user names a speaker cluster in a meeting, through the "Who is this?" popover or by picking a "Known voice":
  - an existing profile with that name gets the cluster's centroid added;
  - otherwise a new profile is created.
- **Stored.** `sentidoS/VoiceProfiles/profiles.json` holds id, **name**, up to 20 L2-normalized embeddings and `updatedAt`.
- **Retention.** Indefinite. The embeddings cap is 20, oldest dropped. There's no expiry.
- **Transmitted.** No.
- **Classification.** DERIVED · **BIOMETRIC** (voiceprint linked to a name) · PERSONAL (**3P**) · SENSITIVE.
- **Consent.** **None.** The help text says "Rename this speaker and remember their voice". Renaming always enrolls.
- **Deletion control.** **Exists.** Meetings → Voice Profiles → Delete, single or multiple. It doesn't scrub `meeting.json` (§4.12).
- **Evidence.**
  - Store: `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:4-19,39-50,97-127,136-142`.
  - Enrollment: `Meeting.swift:53-67`.
  - UI: `MeetingKit/Sources/MeetingUI/MeetingDetailView.swift:68-73,87-118`; `MeetingKit/Sources/MeetingUI/VoiceProfilesView.swift:25,41-42`.
- **Inaccurate comment.** `VoiceProfileStore.swift:4-5` says "the original audio can't be recovered from them, and none is kept." But the meeting audio *is* kept by default (§4.10).

### 4.14 AI provider keys and prompts

- **Captured.** API keys pasted by the user, and the routing settings (provider and model per task).
- **Stored.**
  - Keys: login Keychain, generic password; service `io.github.pikabrofar.humanity.ai`, account = provider id; `kSecAttrAccessibleWhenUnlocked`. There's no `kSecAttrSynchronizable`, so they aren't synced to iCloud Keychain (verify with `security find-generic-password -s io.github.pikabrofar.humanity.ai`).
  - Routing: UserDefaults `AIKit.settings`.
  - Prompts and replies: in memory only, over an ephemeral URLSession with no URL cache. Results are persisted as summaries and cleaned text (§4.8, §4.11).
- **Retention.** Keys until removed. Provider-side retention follows each provider's terms; the app can't control it.
- **Transmitted.**
  - **Key:** in the `Authorization: Bearer` or `x-api-key` header to the chosen provider's base URL. Providers and URLs:
    - Groq: `api.groq.com`
    - Gemini: `generativelanguage.googleapis.com`
    - OpenAI: `api.openai.com`
    - Anthropic: `api.anthropic.com`
    - OpenRouter: `openrouter.ai`
    - Mistral: `api.mistral.ai`
    - DeepSeek: `api.deepseek.com`
    - Together: `api.together.xyz`
    - xAI: `api.x.ai`
    - Ollama: `http://localhost:11434`, plain HTTP, local machine only
  - **Content**, only when a task is routed to a provider:
    - cleanup: the raw dictation text;
    - summaries: note text and meeting transcripts with speaker names, chunked;
    - "Other tasks" (`.general`): no caller found in v1.0.0.
  - **Model list** (`GET /models`, key only, no content): sent on Test, on Save, and **automatically when the AI Providers screen shows a task routed to that provider**.
  - Standard HTTPS metadata goes too: IP address and a User-Agent with the app name and OS version.
- **Classification.** Key: credential (SENSITIVE, tied to the user's provider account). Prompts: DERIVED · PERSONAL (user and **3P**) · SENSITIVE.
- **Deletion control.** **Exists.** Remove Key, per provider. Setting a task back to "On-device" stops sending. There's no control for provider-side data.
- **Evidence.**
  - Settings and keys: `AIKit/Sources/AIKit/AISettings.swift:23-44`; `AIKit/Sources/AIKit/KeychainStore.swift:6-48`.
  - Client: `AIKit/Sources/AIKit/LLMClient.swift:32-40` (session), `:57-62` (models), `:66-101` (request), `:106-125` (no logging, key redacted from errors); `AIKit/Sources/AIKit/Provider.swift:46-68`; `AIKit/Sources/AIKit/Tasks.swift:33-42,44-85`.
  - UI: `AIKit/Sources/AIKitUI/AIProvidersView.swift:23,28-31,60-63,128-141,169-192`.

### 4.15 License key file

- **Captured.** The Gumroad license key, from typing or pasting, or auto-filled from the clipboard (§4.18).
- **Stored.** `~/Library/Application Support/sentidoS/license.json` holds `{key, verifiedAt}` in **plaintext**. It is shared by all sentidoS apps.
- **Retention.**
  - Kept until Gumroad rejects it at a recheck: invalid, refunded, chargebacked or disputed. Then the file is deleted.
  - The app stays unlocked for 60 days after the last successful check.
- **Transmitted.**
  - `POST https://api.gumroad.com/v2/licenses/verify` with `product_id`, `license_key` and `increment_uses_count` (true on activation, false on recheck). Ephemeral session.
  - The response is decoded only for `success`, `message`, `purchase.refunded`, `chargebacked` and `disputed`, and is never stored.
  - **When:** on activation, and **at app launch if the last success is more than 7 days old**. It isn't periodic while the app runs.
- **Classification.** PERSONAL (a pseudonymous identifier that Gumroad links to the purchaser) · not sensitive.
- **Deletion control.** **None in the app.** There's no deactivate or remove action.
- **Evidence.** `LicenseKit/Sources/LicenseKit/License.swift:10-17,19-37,62-79,90-107,111-119`; `LicenseKit/Sources/LicenseKit/ActivationWindow.swift:8-11,69-72`.

### 4.16 UserDefaults

- **Stored** in `~/Library/Preferences/<bundle id>.plist`, via `cfprefsd`.

  | Key | Contents | Classification |
  |---|---|---|
  | `sentidoS.seenTutorial`, `sentidoS.gazeOn` | Flags (`HumanityApp.swift:75-82`) | NON-PERSONAL |
  | `sentidoS.start` | Dev launch argument (`:92`) | NON-PERSONAL |
  | `ojoS.cameraID` | AVCaptureDevice unique ID | Device identifier, low |
  | `ojoS.pupilRefinement`, `stability`, `responsiveness`, `showCursor`, `cursorStyle`, `cursorSize`, `completedSetup`, `hideWhileRecording`, `captureScreenshot`, `learnFromClicks`, `dwellClick`, `dwellTime`, `snapToTargets` | Settings (`ojoS/Sources/OculOSUI/Engine/Persistence.swift:129-147`) | NON-PERSONAL |
  | `manoS.leftHanded` | Handedness | PERSONAL, low |
  | `manoS.showHUD`, `completedSetup` | Settings | NON-PERSONAL |
  | `manoS.profile` | Hand profile JSON (§4.6) | DERIVED, PERSONAL, low |
  | `bocaS.completedSetup`, `cleanup`, `useIntelligence`, `keepHistory`, `restoreClipboard` | Settings (`bocaS/Sources/MurmurUI/Engine/Persistence.swift:6-19`) | NON-PERSONAL |
  | `bocaS.vocabulary` | Free-text custom words, often **people's names** | PERSONAL |
  | `AIKit.settings` | Which provider and model per task | PERSONAL, low (reveals provider use) |

- AppKit and SwiftUI may add framework-managed keys, such as window frames and the last Save-panel directory. Verify with `defaults read io.github.pikabrofar.humanity`.
- **Retention.** Indefinite.
- **Transmitted.** No.
- **Deletion control.** **None in the app.**

### 4.17 Logs (`os_log` / `Logger` / `print`)

- **App code.** There is exactly **one** logger: `Logger(subsystem: "bocaS", category: "latency")`. It logs `"Key release to text inserted: \(ms) ms"`, an integer. **No transcript text, keys, file paths, gaze or face data is logged by app code.** There are no `print` or `NSLog` calls.
- `LLMClient` deliberately doesn't log, and redacts the key from provider error text. That text, truncated to 300 characters, is **shown in the UI**, not logged.
- **FluidAudio** (dependency).
  - It uses its own `AppLogger`, subsystem `com.fluidinference`, at info and debug level, writing to the unified log.
  - In release builds, warnings and above also go to stderr (`mirrorsToConsole` defaults to `true`).
  - On the diarization path it logs model directory paths, which contain the macOS user's home directory and therefore the account name, plus timings and counts. I saw no transcript or audio content at these call sites.
  - sentidoS never configures `AppLogger.minimumLevel` or `mirrorsToConsole`.
- **Apple frameworks** (AVFoundation, Speech, ScreenCaptureKit, Core ML, Vision) write their own unified-log entries. **macOS crash reports** go to `~/Library/Logs/DiagnosticReports`, and to Apple only if the user enabled sharing.
- **Classification.** NON-PERSONAL, except paths that include the account name (PERSONAL, low).
- **Evidence.** `bocaS/Sources/MurmurUI/AppModel.swift:7,33,266-270`; `AIKit/Sources/AIKit/LLMClient.swift:106,116-117,165-176`. FluidAudio: `Sources/FluidAudio/Shared/AppLogger.swift:10,25-28,52-61`; `Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerModels.swift:81`; `Sources/FluidAudio/Diarizer/Offline/Core/OfflineDiarizerManager.swift:95`.

### 4.18 Clipboard use

- **Paste-and-restore** (dictation into non-terminal, non-secure targets).
  1. `snapshot()` reads **every item and every type** on the general pasteboard into memory. That can include anything the user copied, such as a password.
  2. The dictated text is written, marked `org.nspasteboard.TransientType` and `AutoGeneratedType`.
  3. ⌘V is posted.
  4. After 500 ms the old contents are restored, unless something else wrote to the pasteboard in the meantime.

  `restoreClipboard` defaults to `true`. Without Accessibility, the dictated text is **left on the clipboard**.
- **Copy buttons.** Library "Copy transcript", Meeting "Copy transcript" and "Copy Markdown" write plain strings with **no** transient or concealed markers.
- **Universal Clipboard.** No write uses `prepareForNewContents(with: .currentHostOnly)`. So dictated text and copied transcripts **may be synced to the user's other Apple devices** via Universal Clipboard (Apple: https://developer.apple.com/documentation/appkit/nspasteboard/contentsoptions/currenthostonly). Clipboard managers that ignore nspasteboard.org markers may also record them.
- **License window.** When the activation window appears, it reads the **whole clipboard string** and keeps only a regex match for a Gumroad-style key, which it puts in the text field. Nothing else is kept or sent.
- **Stored or transmitted by the app.** No.
- **Classification.** Clipboard contents: arbitrary, potentially SENSITIVE and PERSONAL, in memory only.
- **Deletion control.** Not applicable. "Restore the clipboard after pasting" is a toggle.
- **Evidence.** `bocaS/Sources/MurmurUI/Engine/TextInserter.swift:6-37,45-62`; `bocaS/Sources/MurmurKit/PasteSequence.swift:59-75`; `bocaS/Sources/MurmurUI/AppModel.swift:78-80,266`; `LibraryView.swift:196-199`; `MeetingsView.swift:268-271`; `MeetingDetailView.swift:29-31`; `LicenseKit/Sources/LicenseKit/ActivationWindow.swift:69-72`.

### 4.19 The Accessibility tree (snap-to-target)

- **What it reads.**
  - It runs only when a gaze click is committed, by the ⌃⌥⌘G hotkey or dwell click (dwell is off by default), with "Snap to buttons and links" on (the default).
  - It hit-tests at most 19 points within about 4° of the gaze point, using `AXUIElementCopyElementAtPosition` on the system-wide element with a 50 ms timeout.
  - For each hit, it reads **only** `kAXRoleAttribute` and climbs up to 4 levels of `kAXParentAttribute`. For elements with a clickable role, it reads `kAXPositionAttribute` and `kAXSizeAttribute`.
- **What it doesn't read.** **It never reads titles, values, descriptions, selected text or labels** (`kAXTitle`, `kAXValue` and the like aren't referenced anywhere in the repo).
- **Stored or transmitted.** No. The element references are discarded after picking the nearest frame center.
- **Other AX use.** `AXIsProcessTrusted` checks only. bocaS detects password fields through Carbon's `IsSecureEventInputEnabled()`, not through AX.
- **Classification.** NON-PERSONAL (UI geometry and roles). The **permission** itself is broad, so the policy should state the narrow use.
- **Evidence.** `ojoS/Sources/GazeKit/GazeClick.swift:50-53,61-68,80-101,113-124`; `ojoS/Sources/OculOSUI/AppModel.swift:68-70,94-96,136-170`.

### 4.20 Window info (manoS flick "auto")

- **What it reads.** On a V-sign flick with `flickAction == .auto` (the default), `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements])` returns every on-screen window's info dictionary. The code reads **only `kCGWindowLayer` and `kCGWindowBounds`**, to find the height of the frontmost normal window under the pointer. It ignores owner names, PIDs and window names; without Screen Recording permission, macOS withholds window names anyway.
- **Stored or transmitted.** No.
- **Classification.** NON-PERSONAL.
- **Evidence.** `manoS/Sources/ManOSUI/Engine/EventInjector.swift:61-67,78-87`; `manoS/Sources/HandKit/HandProfile.swift:20,24-33`.

### 4.21 CGEvent posting (and input observation)

- **Posted.** All posts go to `.cghidEventTap`, so they reach whatever app is frontmost.
  - **manoS:** mouse move, drag, left down/up with click count, right click, phased scroll, flick scroll and ↑/↓ keys. Tagged `eventSourceUserData = 0x0C01`.
  - **ojoS:** move plus left click at the gaze point. Tagged `0x6A2E`.
  - **bocaS:** ⌘V, or Unicode keystrokes for the dictated text (used in terminals and secure fields), in chunks of up to 20 UTF-16 units, with newlines turned into spaces.
- **Observed.**
  - The cursor position (`CGEvent(source: nil).location`) and modifier state (`CGEventSource.flagsState`, `NSEvent.modifierFlags`).
  - ojoS's **global left-mouse-down monitor**, which reads the click location for learn-from-clicks (§4.2).
  - Carbon hot keys for the suite's own shortcuts only (⌥⌘R, ⌃⌥⌘G, ⌃⌥⌘H, ⌃⌥⌘D, and Esc during dictation).
  - There's **no keystroke monitoring and no event tap**.
- **Stored or transmitted.** No.
- **Classification.** NON-PERSONAL control events. The dictated text inside typed events is PERSONAL in transit to the target app.
- **Evidence.**
  - Posting: `manoS/Sources/ManOSUI/Engine/EventInjector.swift:24-131`; `ojoS/Sources/GazeKit/GazeClick.swift:104-111`; `bocaS/Sources/MurmurUI/Engine/TextInserter.swift:64-95`.
  - Observing: `manoS/Sources/ManOSUI/Engine/HandEngine.swift:184,233`; `ojoS/Sources/OculOSUI/AppModel.swift:103-125,153-161`; `ojoS/Sources/GazeKit/HotKey.swift:18-44`; `bocaS/Sources/MurmurUI/Engine/HotKey.swift`; `bocaS/Sources/MurmurUI/AppModel.swift:106-108,157-158`.

---

## 5. Complete network egress inventory

| # | Destination | Trigger | Payload | Evidence |
|---|---|---|---|---|
| N1 | `api.gumroad.com/v2/licenses/verify` (HTTPS) | Activation; app launch if the last check is > 7 days old | `product_id`, `license_key`, `increment_uses_count`, plus IP and User-Agent | `License.swift:62-79,111-119`; `ActivationWindow.swift:9-11` |
| N2 | Chosen AI provider (HTTPS; Ollama is `http://localhost`) | Task routed to that provider: cleanup per dictation, summary per note or meeting; Test, Save and automatic model listing in AI Providers | Key header; for content calls, dictation text or transcripts with speaker names | `LLMClient.swift:50-101`; `Tasks.swift:33-85`; `AIProvidersView.swift:23,60-63,169-192` |
| N3 | Hugging Face (`https://huggingface.co` by default) via FluidAudio | Processing a meeting when the models are missing or their pinned revision changed | Model and file requests plus IP and User-Agent; `Authorization: Bearer $HF_TOKEN` **if that environment variable is set**. The host can be redirected by `REGISTRY_URL` or `MODEL_REGISTRY_URL` | `Diarizer.swift:24-30`; FluidAudio `ModelRegistry.swift:32-37`, `Shared/Download/HFClient.swift:26-41`, `Shared/Download/ModelHub.swift:344` |
| N4 | Apple (OS-managed) | First dictation or file transcription in a language on macOS 26 (`AssetInventory`) | Apple's asset request; audio is not sent | `Transcriber.swift:70-73`; `FileTranscriber.swift:46-49` |
| N5 | Browser opens a URL (not app networking) | "Buy a License" (`gumroad.com/l/hamkad`); "Get a key" links | Whatever the browser sends | `ActivationWindow.swift:59`; `AIProvidersView.swift:148` |
| N6 | GitHub, PyPI, github.com/yakhyo | User runs `make cnn-model` themselves | Script downloads | `ojoS/scripts/make-cnn-model.sh:16-24` |

**Not found:** analytics, telemetry, crash reporting, update checks, ad SDKs or device fingerprinting. I grepped the app sources, and FluidAudio's diarization and download paths (FluidAudio's TTS downloader isn't used). I also found no remote config.

---

## 6. Where PRIVACY.md, README, plist strings or in-app text claim more than the code guarantees

| ID | Claim (source) | Verdict | Code evidence and the fix |
|---|---|---|---|
| C1 | "Camera frames and audio are processed on your Mac and never uploaded." (PRIVACY.md:8) | **Supported** for app code | No upload path exists. Keep, but scope it to "this app". |
| C2 | "no analytics, telemetry, crash reporting or update checks" (PRIVACY.md:8-10) | **Supported** | Add that macOS's own crash and analytics sharing is controlled by the user in System Settings. |
| C3 | "They make network requests in only these cases" (PRIVACY.md:10-11) | **Incomplete** | Missing: automatic model-list requests (key only) from the AI Providers screen; the HF re-download conditions and environment overrides (N3); IP and User-Agent metadata. |
| C4 | "Only then is that task's text … sent" (PRIVACY.md:14-15) | **Supported, but understated** | Summaries are sent **automatically** for every note and every processed meeting, and meeting text includes **other people's words and names** (`MeetingsView.swift:60,90`; `AppModel.swift:287`). |
| C5 | "Keys live in your macOS Keychain." (PRIVACY.md:16) | **True for AI keys only** | The license key is plaintext in `license.json` (`License.swift:25-37`). |
| C6 | "Every task defaults to on-device." (PRIVACY.md:16-17) | **Supported** | `AISettings.swift:32-36`. |
| C7 | "Dictation into password fields is never sent." (PRIVACY.md:17) | **Not guaranteed** | It depends on `IsSecureEventInputEnabled()` at start or end (`AppModel.swift:153,248`). Fields that don't enable secure input are treated as normal text: cleaned (possibly in the cloud), saved with audio. The spoken text is also shown in the HUD (`HUD.swift:84`). Reword to "when macOS reports a secure input field". |
| C8 | "The first time you process a meeting, MeetingKit downloads … from Hugging Face." (PRIVACY.md:18-20) | **Mostly** | Also on a missing cache or a revision change; environment variables can redirect it or add a token (N3). |
| C9 | Apple speech model download (PRIVACY.md:21-22) | **Supported** | N4. |
| C10 | License check "about once a week … Nothing else is sent" (PRIVACY.md:23-25) | **Inaccurate** | It runs at launch when > 7 days have passed, not on a schedule (`ActivationWindow.swift:9-11`; `License.swift:111-114`). `increment_uses_count` is also sent. 60-day offline lockout. |
| C11 | "Everything is stored under `~/Library/Application Support/`, and you can delete it at any time." (PRIVACY.md:30-31) | **False / incomplete** | UserDefaults are in `~/Library/Preferences`; keys are in the Keychain; FluidAudio models; exports anywhere. There's no in-app delete-all; orphan audio is invisible (§4.7, §4.10); Time Machine and snapshots keep copies. |
| C12 | "Camera frames are never stored. Each frame is analyzed in memory and discarded." (PRIVACY.md:33-34); "Video is … never stored or transmitted" (Info.plist camera strings) | **True for frames; the plist wording overstates it** | Eye-region pixel patches from frames are stored (§4.3). Suggested plist text: "Video frames are processed on this Mac and never saved or sent. Calibration keeps small eye-feature measurements." |
| C13 | ojoS saves "eye-feature measurements, a few model parameters and small 10×6-pixel eye patches" (PRIVACY.md:35-37) | **Incomplete** | Also stores head pose, face position and size, timestamps, display name and size, and **up to 400 samples captured from your mouse clicks anywhere on screen** (global monitor, on by default). |
| C14 | Recordings: "gaze coordinates and an optional screenshot" (PRIVACY.md:36-37) | **Supported** | Say that the screenshot is the **whole display** and may contain other people's information. |
| C15 | "To delete it, use ojoS → Calibrate → Clear Calibration, or delete the folder." (PRIVACY.md:38) | **Partial** | Clear Calibration removes only `calibration.json`. Recordings, screenshots and the loaded CNN are deleted separately; settings remain. |
| C16 | "manoS (`manoS/`) saves your pinch thresholds and settings. Nothing else." (PRIVACY.md:39) | **Wrong location** | It's in UserDefaults (`manoS/Sources/ManOSUI/Engine/Persistence.swift:19-29`). "Nothing else" is supported. |
| C17 | bocaS saves "text, and audio for notes" (PRIVACY.md:40-41) | **False** | **Dictation audio is saved by default** (`AppModel.swift:75-77,168`). It also stores the target app name, cleaned text, summaries and action items. |
| C18 | Meetings save "mic and call audio, the transcript and its summary" (PRIVACY.md:42-43) | **Incomplete** | Also **voice embeddings of every remote speaker**, word timings and metadata. "Call audio" can be all system audio. No bulk delete; deletion is via the context menu. |
| C19 | Voice profiles "for each person you name … Delete profiles in Meetings → Voice Profiles" (PRIVACY.md:44-46) | **Partial** | Naming is the consent-less enrollment trigger, and recognition is automatic. Deleting a profile leaves the embeddings in `meeting.json`. |
| C20 | "Tell people when you record a meeting, and follow your local consent laws." (PRIVACY.md:48-49) | **Advice only** | The app doesn't enforce or record consent (`MeetingRecorderControl.swift:66-70`). |
| C21 | "All permissions are granted to sentidoS once." (PRIVACY.md:53) | **Partial** | Standalone apps have separate grants (`Permissions.swift:172`). |
| C22 | Accessibility use list (PRIVACY.md:59-60) | **Supported** | Also synthesized typing and arrow keys. Add "reads only on-screen element roles and positions, never their text". Disclose the global mouse-click monitor (needs no permission). |
| C23 | Screen Recording for heatmaps and "call audio on older macOS" (PRIVACY.md:61-62) | **Imprecise** | ScreenCaptureKit is also the fallback when a process tap fails on new macOS (`MeetingRecorder.swift:146-167`). |
| C24 | "all network code is in `AIKit/`, `LicenseKit/` and MeetingKit's `Diarizer.swift`" (PRIVACY.md:64-66) | **Imprecise** | The download code is in the FluidAudio dependency. Apple downloads are triggered from `Transcriber.swift` and `FileTranscriber.swift`. |
| C25 | "Camera and audio are processed on-device with Apple's frameworks … no account" (README.md:4-6) | **Imprecise** | Diarization uses third-party FluidAudio models. Activation requires a Gumroad purchase, and Gumroad holds the buyer's details. |
| C26 | "See PRIVACY.md for exactly what is stored" (README.md:29) | **Overstated** | See C11–C19. |
| C27 | `NSSpeechRecognitionUsageDescription`: "Nothing is sent to Apple or anyone else." (`sentidoS/Resources/Info.plist:39-40`; `bocaS/Resources/Info.plist:33-34`) | **Misleading when cloud AI is set** | Recognition is local, but the resulting text may go to the user's AI provider. Reword: "Speech is recognized on this Mac; audio is never sent." |
| C28 | bocaS Settings: "Everything is stored only in Application Support on this Mac." (`bocaS/Sources/MurmurUI/MurmurModule.swift:127`) | **Overstated** | Backups and cloud summaries; vocabulary is in Preferences. |
| C29 | `VoiceProfileStore.swift:4-5`: "none is kept" | **Inaccurate in context** | Meeting audio is kept (§4.10). |
| C30 | Tutorial: "Camera and audio stay on this Mac." (`HumanityApp.swift:416`) | **Supported** for app code | Backups copy them (§7). |
| C31 | SECURITY.md: "declare only the camera and microphone entitlements" | **True** | Consequence to disclose: no App Sandbox, so data isn't containerized and any process running as the user can read it. |

---

## 7. Gaps

### 7.1 Retention
- There's **no retention limit on any store.** The only caps are 400 learned-click samples and 20 embeddings per voice profile. Raw meeting audio, dictation audio, screenshots, diarization embeddings and voice profiles live forever unless deleted by hand.
- There's no published retention schedule. That matters for biometric data: BIPA 14/15(a), and Colorado C.R.S. 6-1-1314 if it applies (counsel).

### 7.2 Deletion
- There's **no suite-wide "delete all data"**. Existing controls:
  - bocaS: Delete All Recordings, which misses orphans, meetings and voice profiles.
  - ojoS: Clear Calibration and per-recording delete.
  - Meetings: per-meeting delete through the context menu, with no confirmation and no bulk option.
  - Voice Profiles: delete.
  - AI: Remove Key.
- **No control at all for:** UserDefaults (including `bocaS.vocabulary` and `manoS.profile`), `license.json`, FluidAudio models, orphaned dictation audio, orphaned meeting folders, or `meeting.json` embeddings without deleting the meeting.
- Turning off "Keep dictations in the Library" doesn't purge what's already saved.

### 7.3 Orphans (deletion controls can't reach them)
- **Dictation crash.** An `.m4a` is written live with no JSON, so it's invisible and never deleted (`RecordingStore.swift:36-43`; `AppModel.swift:402-406`).
- **Meeting crash.** The folder has audio but no `recording.json` (written only at stop, `MeetingRecorder.swift:134`), so it's invisible (`MeetingRecorder.swift:28-34`).

### 7.4 Backups, iCloud, sync and indexing
- **Time Machine** backs up `~/Library` by default. Nothing sets `URLResourceValues.isExcludedFromBackup` (https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup). So raw meeting audio, dictation audio, screenshots, voiceprints and calibration data are copied to every backup disk, and **APFS local snapshots** keep deleted files for a while. **Deleting in the app doesn't delete backups.** Third-party backup tools and Migration Assistant copy them too.
- **iCloud Drive "Desktop & Documents"** syncs only `~/Desktop` and `~/Documents`, not `~/Library/Application Support`, so app stores are **not** iCloud-synced. **User exports** saved to the Desktop or Documents, such as transcripts, CSVs and heatmap PNGs with screenshots, **will** sync when that feature is on.
- **Universal Clipboard** may carry dictated text and copied transcripts to other devices (§4.18).
- **Spotlight** indexing of `~/Library/Application Support` JSON should be checked (`mdfind -onlyin ~/Library/Application\ Support/bocaS "<word you dictated>"`). If they're indexed, consider `.noindex` directory names.
- Because the apps aren't sandboxed, nothing is containerized, and **any process running as the user can read these files** without a TCC prompt.

### 7.5 File permissions and encryption at rest
- No code sets POSIX permissions or file protection. Files get the umask default, typically 0644 for files and 0755 for directories.
- Protection from other local accounts rests on `~/Library` being 0700 (it is on the audit machine: `drwx------`).
- There's **no app-level encryption** for audio or biometric templates; at-rest protection depends on the user enabling FileVault.
- The license key is plaintext.

### 7.6 Consent and notice
- No meeting-recording consent step or attestation; an all-system-audio default fallback; no menu-bar indicator for meetings (§4.10).
- No consent before creating a third party's voiceprint, and automatic re-identification in every later meeting (§4.12, §4.13).
- No per-meeting confirmation before cloud summarization of third-party speech (§4.11).
- The learn-from-clicks global monitor is on by default and not disclosed in PRIVACY.md (§4.2).

### 7.7 Logging
- App code is clean.
- FluidAudio logs paths containing the account name and mirrors warnings to stderr (§4.17). Low risk, easy to fix.

---

## 8. Recommended privacy-preserving architecture

### 8.1 Principles
1. **Raw data is ephemeral by default.** Camera frames are already never stored. Apply the same rule to audio: stream it to the recognizer and keep it only when the user explicitly wants a recording.
2. **Derived data is minimal.** Keep the fitted model, not the inputs, wherever accuracy allows.
3. **Biometric templates need opt-in, consent, a retention period and a single delete path.**
4. **Every store goes through one `DataStore` registry**, which drives a data inventory screen, "Delete all", retention sweeps, backup exclusion and permissions.

### 8.2 Raw-data handling
| Data | Today | Target |
|---|---|---|
| Camera frames | In memory, per frame | Unchanged. Add a unit test asserting no file writes in the frame path (see P3-4). |
| Eye patches | Stored for every calibration and click sample | Store the `AppearanceModel` (mean and weights) plus the minimal features needed for refits. Drop per-sample `appearance` arrays, or quantize them to 4 bits and keep only the newest N. |
| Dictation audio | Saved by default | **Not saved by default.** A separate "Keep dictation audio" toggle, default off. |
| Notes audio | Kept forever | Keep until a transcript exists. Then default to deleting the audio after 30 days, with a "Keep audio" option per note. |
| Meeting audio | Kept forever | After successful processing, keep the raw audio 7 days (for re-processing), then delete it by default; transcripts remain. A per-meeting "Keep audio" pin. |
| Diarization centroids | Kept forever for everyone | Keep in memory, or in a separate `pending-voices.json`, only until the user finishes naming, with a hard limit of 30 days. Persist only for clusters enrolled with consent. |
| Screenshots | Full resolution, forever | Show a warning at enable. Offer downscale or blur, and default to 90-day retention. |

### 8.3 Retention defaults (proposal; the product owner and counsel set the final numbers)
| Store | Default |
|---|---|
| Dictation text history | 30 days |
| Dictation audio | Not kept |
| Notes (text) | Until deleted |
| Notes audio | 30 days after a transcript exists |
| Meeting audio | 7 days after processing |
| Meeting transcripts and summaries | 1 year |
| Diarization embeddings (unenrolled) | Until naming is done, at most 30 days |
| Voice profiles | Expire 12 months after the last match (BIPA allows at most 3 years after the last interaction), with a reminder |
| Gaze recordings and screenshots | 90 days |
| Calibration | Until cleared; learned clicks capped (as today) |

Run the retention sweep at launch and every 24 hours while the app runs. Show the next deletion date in the UI.

### 8.4 Consent before meeting recording (all-party-consent states)
- **Per recording**, before capture starts, show a sheet.
  - The source: the app name, or **"All system audio"** with a warning.
  - "Everyone on this call has been told it is being recorded and has agreed." This checkbox is **required** to start.
  - An optional **Copy announcement** button ("I'm recording this call to transcribe it on my Mac…").
  - A link to a help page listing all-party-consent jurisdictions (§1). The app shouldn't try to geolocate.
- Persist the attestation in `recording.json` (`consent: { confirmedAt, source, textVersion }`) so the user can later show that consent was obtained.
- Show a persistent **menu-bar recording indicator** while a meeting records, and a 30-minute reminder. Never fall back to all system audio silently.

### 8.5 Consent before creating someone else's voiceprint
- Split **Rename** (a label only, no biometrics) from **Remember this voice**, which is off by default.
- "Remember this voice" requires a checkbox: "*<Name>* agreed to have a voice profile stored on this Mac." Show a link explaining what a voiceprint is, where it's stored and its retention period.
- Store `consentedAt` and `consentNote` on `VoiceProfile`.
- Add a global **Voice recognition** switch, off by default. When it's off, there's no automatic matching (`profiles.assign`) and no enrollment.
- **Deleting a profile** must also remove its embeddings from all `meeting.json` files and clear `profileID` references.
- Answer the "who's speaking" need without biometrics where possible: "Speaker 1/2" labels per meeting don't need any persistent template.

### 8.6 Cloud AI
- The first time a task is routed to a cloud provider, show a one-time confirmation with the provider's name and a link to its privacy terms.
- **For meetings, confirm per meeting**: "This transcript includes other people's words. Send it to <Provider>?"
- Per-provider notes in the UI. For example: some free tiers may use content to improve models (check Google's Gemini API terms, https://ai.google.dev/gemini-api/terms); DeepSeek processes data in the PRC (its privacy policy); OpenRouter forwards to third-party model hosts.

### 8.7 Storage hardening
- Create every directory with mode 0700 and every file with 0600.
- Optionally encrypt audio, embeddings and transcripts with AES-GCM (CryptoKit), using a per-install key in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- Add a "Back up recordings with Time Machine" switch. Set `isExcludedFromBackup` on audio and voiceprint directories when it's off. Default **off** for raw audio and voiceprints, **on** for transcripts.
- Move the license key into the Keychain.
- Use `.currentHostOnly` and `org.nspasteboard.ConcealedType` for transient clipboard writes.

### 8.8 One "Data & Privacy" screen in every app
- An inventory with paths, sizes and counts, and "Show in Finder" for each store.
- "Delete all sentidoS data on this Mac". It covers every path in §3, Keychain items, UserDefaults domains and, optionally, the license and FluidAudio models. It should also offer to open Time Machine settings, because backups aren't touched.
- "Export my data" as a zip.

---

## 9. Prioritized engineering changes

P0 means legal exposure or a public claim that's false today. P1 means a significant privacy gap. P2 is hardening. P3 is cleanup.

### P0

**P0-1. Make every public statement match the code.**
- *Files:* `PRIVACY.md`; `README.md:4-6,29`; `sentidoS/Resources/Info.plist:28,32,36,40`; `ojoS/Resources/Info.plist`; `manoS/Resources/Info.plist:28`; `bocaS/Resources/Info.plist:26,30,34`; `sentidoS/Sources/sentidoS/Permissions.swift:37-45` (add the ojoS gaze click to the Accessibility reason); `bocaS/Sources/MurmurUI/MurmurModule.swift:127`; `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:4-5`.
- *Fix:* Apply every correction in §6, C3–C29. At minimum:
  - dictation audio is stored;
  - every remote speaker's voiceprint is stored per meeting;
  - learned clicks;
  - the manoS location;
  - the license recheck timing;
  - the password-field heuristic;
  - backups.
- *Test:* Add `scripts/check-privacy-claims.sh` to CI (`.github/workflows/ci.yml`). It greps the plist usage strings against an approved list and fails on "never stored" or "Nothing is sent to Apple or anyone else". Also keep a manual review checklist mapping each PRIVACY.md bullet to a §4 entry.

**P0-2. Consent gate before meeting recording, with an attestation.**
- *Files:* `MeetingKit/Sources/MeetingUI/MeetingRecorderControl.swift:84-100` (`toggle()`), `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:5-22,68` (`MeetingRecording` and `start`).
- *Fix:*
  - Add `struct RecordingConsent: Codable { confirmedAt: Date; source: String; textVersion: Int }`.
  - Change the signature to `start(_ source:, consent: RecordingConsent)`, and save it in `recording.json`.
  - Show a confirmation sheet with a required checkbox and a "Copy announcement" button.
  - Remove the silent `.allSystemAudio` fallback at `MeetingRecorderControl.swift:93`: if the chosen app is gone, show an error.
  - Write `recording.json` at start (see P1-3).
- *Test:* A Swift Testing case in `MeetingKit/Tests/MeetingKitTests/ReliabilityTests.swift`: start with a consent value, stop, then decode `recording.json` and assert `consent.confirmedAt` is set. A UI check: Record is disabled until the box is ticked; with no playing app, starting shows an error rather than recording all system audio.

**P0-3. No voiceprint without explicit "Remember this voice" and consent.**
- *Files:* `MeetingKit/Sources/MeetingKit/Meeting.swift:53-67`; `MeetingKit/Sources/MeetingUI/MeetingDetailView.swift:87-118`; `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:6-19,97-113`.
- *Fix:*
  - Change to `name(speaker:as:in:remember: Bool = false)`. When `remember == false`, only set `speakers[cluster] = Speaker(name:, profileID: nil)`.
  - Add a "Remember this voice" toggle (default off) with the consent checkbox.
  - Add `consentedAt: Date?` to `VoiceProfile`, required by `enroll` and `refine`.
  - Add a global "Voice recognition" setting, default off. When it's off, `MeetingProcessor.process` (`Meeting.swift:128`) skips `profiles.assign`.
- *Test:* In `MeetingKit/Tests/MeetingKitTests/VoiceProfileTests.swift`:
  - `naming without remember leaves store empty`;
  - `remember with consent enrolls and sets consentedAt`;
  - `processor does not match profiles when recognition is off`.

**P0-4. Stop keeping unenrolled speakers' embeddings, and scrub embeddings on profile delete.**
- *Files:* `MeetingKit/Sources/MeetingKit/Meeting.swift:104-133`; `MeetingKit/Sources/MeetingKit/Transcript.swift:31-41`; `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:124-127`; `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:35-47`.
- *Fix:*
  - Move `centroids` out of `meeting.json` into `pending-voices.json` with `expiresAt = processedAt + 30 days`. Delete that file when it expires or when every cluster is named or dismissed.
  - Add a one-time migration in `MeetingsModel.reload()` that strips `centroids` from existing `meeting.json` files, or moves them to pending files with expiry.
  - On `VoiceProfileStore.delete`, clear matching `profileID` references in every meeting.
- *Test:* Process a fixture meeting with a stub `SpeakerDiarizer` and check that `meeting.json` has no `centroids` key. Advance a fake clock 31 days, run the sweep, and check that `pending-voices.json` is gone. Delete a profile, and check that no meeting still references its `profileID`.

### P1

**P1-1. Dictation audio off by default.**
- *Files:* `bocaS/Sources/MurmurUI/AppModel.swift:75-77,168`; `bocaS/Sources/MurmurUI/Engine/Persistence.swift:8`; `bocaS/Sources/MurmurUI/MurmurModule.swift:124-128`.
- *Fix:* Add a new key `keepDictationAudio` (default `false`), and use `saveAudio = kind == .note || (keepHistory && keepDictationAudio && !secure)`.
- *Test:* Extract the decision into `MurmurKit` (`static func shouldSaveAudio(kind:keepHistory:keepAudio:secure:)`) and unit-test it. Manually: dictate with default settings and check that no `<id>.m4a` exists.

**P1-2. Suite-wide "Delete all sentidoS data" and a data inventory.**
- *Files:* new `sentidoS/Sources/sentidoS/DataControls.swift`, added to the `Settings` TabView (`HumanityApp.swift:46-53`) and the sidebar; the same view in the standalone apps.
- *Fix:* Delete every path in §3, call `KeychainStore.delete` for each `Provider.all`, and call `UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)`. Offer the license file and FluidAudio models as options, show sizes and paths, and say that Time Machine copies aren't removed.
- *Test:* An integration test with an injectable base directory: populate fixtures, run, and assert the directory is empty. Manually:
  - `ls ~/Library/Application\ Support/{ojoS,bocaS,sentidoS}` shows nothing;
  - `defaults read io.github.pikabrofar.humanity` reports that the domain doesn't exist;
  - `security find-generic-password -s io.github.pikabrofar.humanity.ai` finds nothing.

**P1-3. Orphan recovery and cleanup.**
- *Files:* `bocaS/Sources/MurmurKit/RecordingStore.swift:36-48`; `bocaS/Sources/MurmurUI/AppModel.swift:103-104,402-406`; `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:24-34,82,134`.
- *Fix:*
  - Add `RecordingStore.orphanedAudio()`, which finds `.m4a` files with no matching `.json`. At launch, delete orphaned dictation audio, or list it as "Recovered audio". `deleteAll()` also removes every file in the directory.
  - Write `recording.json` at `start` (duration 0) and update it at stop. Make `unprocessed()` also list folders that contain `.m4a` files but no JSON.
- *Test:* Put a stray `.m4a` in a temp store directory, and check that `orphanedAudio()` returns it and `deleteAll` removes it. Kill the app with `kill -9` mid-meeting, relaunch, and check that the meeting appears under Recent.

**P1-4. Retention engine with defaults.**
- *Files:* new `bocaS/Sources/MurmurKit/Retention.swift` and `MeetingKit/Sources/MeetingKit/Retention.swift`; called from `bocaS/Sources/MurmurUI/AppModel.swift:103` and `MeetingsView.swift:33`; settings in `MurmurModule.swift`; ojoS `RecordingStore.swift:45-52`.
- *Fix:* Apply the §8.3 defaults, injecting the clock for tests.
- *Test:* Fixtures with `createdAt` 31, 8 and 91 days old: after the sweep, only the expected files remain. Also test that "Keep audio" pins survive.

**P1-5. Confirm before sending meeting transcripts and notes to a cloud provider.**
- *Files:* `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:60,81-102`; `bocaS/Sources/MurmurUI/AppModel.swift:287,355-375`; `AIKit/Sources/AIKit/Tasks.swift:39-42` (expose `isCloud(for:)`).
- *Fix:* If the summaries route is a cloud provider, don't auto-summarize. Show "Summarize with <Provider>" (with a third-party notice for meetings) and an "On this Mac" option.
- *Test:* Register a `URLProtocol` stub that records requests, process a fixture meeting with a provider configured, and assert zero requests until the user confirms.

**P1-6. Password-field protection beyond the heuristic, and no HUD echo.**
- *Files:* `bocaS/Sources/MurmurUI/AppModel.swift:153,248`; `bocaS/Sources/MurmurUI/Views/HUD.swift:84`.
- *Fix:*
  - Also treat input as secure when the focused element's AX subrole is `kAXSecureTextFieldSubrole`. This reads one attribute of the focused element only; disclose it.
  - In secure sessions, show "•••" in the HUD instead of `partial`.
  - Change the PRIVACY wording (C7).
- *Test:* A small test app with an `NSSecureTextField`: dictate into it, then assert no JSON or m4a for the session, no request recorded by the `URLProtocol` stub, and that the HUD shows the masked string.

**P1-7. File permissions and backup exclusion.**
- *Files:* `ojoS/Sources/OculOSUI/Engine/Persistence.swift:67-85`; `bocaS/Sources/MurmurKit/RecordingStore.swift:23-25`; `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:82`; `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:136-137`; `LicenseKit/Sources/LicenseKit/License.swift:33-37`.
- *Fix:* Add a shared helper `SecureStore.makeDirectory(_:)` that creates directories with `[.posixPermissions: 0o700]` and sets files to 0600 after writing. Add a "Back up recordings with Time Machine" setting; when it's off, set `isExcludedFromBackup = true` on `bocaS/Recordings`, `sentidoS/Meetings` and `sentidoS/VoiceProfiles`.
- *Test:* `stat -f %Lp` returns `700` for directories and `600` for files. `tmutil isexcluded ~/Library/Application\ Support/sentidoS/Meetings` reports `[Excluded]`.

**P1-8. Meeting recording indicator.**
- *Files:* `sentidoS/Sources/sentidoS/HumanityApp.swift:548-550`; `bocaS/Sources/MurmurUI/MurmurModule.swift:23` (expose `isRecordingMeeting`).
- *Fix:* Show a distinct menu-bar symbol while `MeetingRecorder.isRecording` is true, and add a Stop item to the quick panel.
- *Test:* Start a recording, close the window, and check that the menu-bar icon has changed and Stop works.

**P1-9. Voice profile retention.**
- *Files:* `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift`.
- *Fix:* Add `lastMatchedAt`, updated in `assign`. Expire profiles after the configured period (default 12 months, maximum 36), with a notice 14 days ahead.
- *Test:* A profile with `lastMatchedAt` 13 months ago is removed by the sweep. A profile matched yesterday stays.

### P2

**P2-1. Minimize the stored eye patches.**
- *Files:* `ojoS/Sources/OculOSUI/Calibration/CalibrationController.swift:145-155`; `ojoS/Sources/OculOSUI/Engine/GazeEngine.swift:283-284`; `ojoS/Sources/OculOSUI/Engine/Persistence.swift:6-19`.
- *Fix:* Persist samples with `appearance = []`, except a capped, quantized subset needed for refits, or keep only the `AppearanceModel`.
- *Test:* `calibration.json` has no `appearance` arrays longer than the cap. The existing `GazeKitTests` calibration accuracy stays within tolerance.

**P2-2. Learn-from-clicks: disclosure and choice.**
- *Files:* `ojoS/Sources/OculOSUI/Views/SettingsView.swift:59-66`; `ojoS/Sources/OculOSUI/AppModel.swift:57-59`.
- *Fix:* Change the caption to "Records your face and eye measurements at each mouse click on this display." Ask during setup instead of defaulting to on.
- *Test:* On a fresh defaults domain the setting reads false, or a prompt appears before the first click is learned.

**P2-3. Screenshot safeguards.**
- *Files:* `ojoS/Sources/OculOSUI/Views/SettingsView.swift:110-114`; `ojoS/Sources/OculOSUI/Recording/ScreenshotCapture.swift:8-19`.
- *Fix:* Warn that the screenshot captures the entire display, including other people's information, when the setting is enabled. Add downscale and blur options and 90-day retention (P1-4).
- *Test:* Enabling shows the warning. The saved PNG matches the chosen scale.

**P2-4. License key: Keychain storage, a remove control, and no automatic clipboard read.**
- *Files:* `LicenseKit/Sources/LicenseKit/License.swift:24-37`; `LicenseKit/Sources/LicenseKit/ActivationWindow.swift:69-72`.
- *Fix:*
  - Store the key in the Keychain (service `io.github.pikabrofar.humanity.license`) and migrate `license.json`.
  - Add "Remove License from This Mac".
  - Replace the `onAppear` clipboard read with a "Paste from Clipboard" button. This also avoids paste-access prompts on newer macOS; verify the behavior on macOS 26.
- *Test:* Extend `LicenseKitTests` to check that `license.json` is migrated and deleted and the key reads back from the Keychain. Opening the window shouldn't touch `NSPasteboard`; test with a pasteboard spy behind a protocol.

**P2-5. Provider disclosures.**
- *Files:* `AIKit/Sources/AIKit/Provider.swift:15-68`; `AIKit/Sources/AIKitUI/AIProvidersView.swift:115-165`.
- *Fix:* Add `privacyURL` and `dataNote` per provider, show them in each provider's row, and show a first-use confirmation (§8.6). Stop the automatic `listModels` at `AIProvidersView.swift:23`; fetch on demand instead.
- *Test:* Opening AI Providers makes no request (`URLProtocol` stub). Each provider row shows its privacy link.

**P2-6. Clipboard hardening.**
- *Files:* `bocaS/Sources/MurmurUI/Engine/TextInserter.swift:18-36`; `bocaS/Sources/MurmurUI/Views/LibraryView.swift:196-199`; `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:268-271`; `MeetingKit/Sources/MeetingUI/MeetingDetailView.swift:29-31`.
- *Fix:* Call `board.prepareForNewContents(with: .currentHostOnly)` before writing. Add `org.nspasteboard.ConcealedType` for dictation writes.
- *Test:* A unit test through the `Clipboard` protocol asserting the types written. Manually, with Handoff on, check that dictated text doesn't appear on a second device.

**P2-7. manoS reset and per-module "Delete data".**
- *Files:* `manoS/Sources/ManOSUI/Views/SetupView.swift`; `manoS/Sources/ManOSUI/Engine/Persistence.swift`; `ojoS/Sources/OculOSUI/Views/SettingsView.swift`.
- *Fix:* "Reset hand profile" removes `manoS.profile` and `manoS.leftHanded`. "Delete all ojoS data" removes calibration, recordings and models.
- *Test:* After a reset, `defaults read io.github.pikabrofar.humanity manoS.profile` fails.

**P2-8. Meeting delete UX.**
- *Files:* `bocaS/Sources/MurmurUI/Views/MeetingsView.swift:160-171`.
- *Fix:* Add a confirmation dialog, a Delete button on the meeting page, and "Delete all meetings".
- *Test:* A UI check that deleting removes the folder (`ls` it afterwards).

### P3

**P3-1. Quiet FluidAudio logging.**
- *Files:* `MeetingKit/Sources/MeetingKit/Diarizer.swift:20-22`.
- *Fix:* Before creating the manager, set `AppLogger.minimumLevel = .warning; AppLogger.mirrorsToConsole = false`.
- *Test:* `log stream --predicate 'subsystem == "com.fluidinference"' --info` shows no info lines while processing a meeting.

**P3-2. Pin the model registry.**
- *Files:* `MeetingKit/Sources/MeetingKit/Diarizer.swift`.
- *Fix:* Set FluidAudio's `ModelRegistry.baseURL = "https://huggingface.co"` explicitly, so `REGISTRY_URL` and `MODEL_REGISTRY_URL` can't redirect downloads, and document the `HF_TOKEN` behavior.
- *Test:* Run with `REGISTRY_URL=http://127.0.0.1:9` and confirm requests still go to huggingface.co (proxy log).

**P3-3. CI guard on network and logging surface.**
- *Files:* `.github/workflows/ci.yml`.
- *Fix:* Fail the build if `URLSession`, `Logger(`, `os_log`, `print(` or `NSLog` appear outside an allowlist (`AIKit/Sources/AIKit/LLMClient.swift`, `LicenseKit/Sources/LicenseKit/License.swift`, `bocaS/Sources/MurmurUI/AppModel.swift:33`).
- *Test:* Add a dummy `URLSession` call on a test branch and confirm CI fails.

**P3-4. No-write test for the camera path.**
- *Files:* `ojoS/Tests/GazeKitTests/GazeKitTests.swift`.
- *Fix:* Run `FaceFeatureExtractor.analyze` on a synthetic pixel buffer in a sandboxed temp HOME and assert no files were created.
- *Test:* The test itself.

**P3-5. Standalone ojoS camera-on-launch.**
- *Files:* `ojoS/Sources/OculOSUI/AppModel.swift:88-90`.
- *Fix:* Start the camera only when the user opens Live or Calibrate, or turns tracking on, matching sentidoS's behavior.
- *Test:* Launch standalone ojoS; the camera indicator stays off until tracking is enabled.

**P3-6. Spotlight check.**
- *Fix:* Run `mdfind` against a known dictated word. If it's indexed, rename the stores to `*.noindex`, with a migration.
- *Test:* The `mdfind` query returns nothing.

**P3-7. Signing note.**
- *Files:* `sentidoS/scripts/build-app.sh:46-52`; `SECURITY.md`.
- *Fix:* Keep the warning that local builds pin the designated requirement to the bundle ID, so a different binary with the same ID could inherit camera, mic and Accessibility grants. Consider refusing to run a local build from `/Applications`.
- *Test:* Documentation review.

---

## 10. Open questions for counsel

1. Is the developer a "collector" (BIPA, CUBI), a "controller" (GDPR, CPA) or a "business" (CCPA) for data that only ever exists on the user's Mac? Does that change for voiceprints of third parties that the software creates automatically?
2. Do eye-feature vectors, head pose and 10 × 6 equalized eye patches count as a "scan of face geometry" or "imagery of the iris" in any target jurisdiction?
3. Do pinch-distance thresholds (scalars derived from hand landmarks) count as a "record of hand geometry" (Texas CUBI)?
4. Is a consent checkbox plus a stored attestation enough to shift wiretap and eavesdropping compliance to the user? Or should the app also block recording until an announcement is played?
5. Does the household exemption (GDPR Art. 2(2)(c)) cover a user voiceprinting colleagues on work calls? (Probably not.)
6. Under GDPR Art. 28, how should the policy characterize BYOK AI providers (the user's own contract with them) and Gumroad?
7. Does Colorado's biometric amendment apply to a developer that never receives the data? Does Washington's MHMDA apply to gaze and voice data?
