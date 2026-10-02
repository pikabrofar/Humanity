# DRAFT — requires attorney review

> **Status:** working draft prepared from a code audit of Humanity v1.0.0 (git commit `e098368`) on 2026-10-01. It is not legal advice and must not be published until counsel has reviewed it. The working tree had uncommitted changes in progress during the audit; those aren't reflected here. Before publishing, re-verify every "Current behavior" and "[DEPENDS ON FIX]" statement against the code that actually ships.
>
> **Markers used:**
> - **[JURISDICTION-DEPENDENT]**: wording or obligations that vary by country or state; counsel decides.
> - **[DEPENDS ON FIX n]**: the sentence is true only after engineering change *n* in `legal/PRIVACY-REQUIREMENTS.md` §9 ships. Until then, use the "Current behavior" wording.
> - **[PLACEHOLDER]**: values to fill in.
>
> **Rule followed throughout:** no "we don't collect X" unless the code guarantees it. Where the developer never receives something, the draft says so and explains why (no code path sends it to us). It doesn't make claims about what the user's own Mac, backups or chosen providers do.

---

## Part A: The factual statements the final policy must contain, matched to the code

Evidence is `path:line` from the repo root. Full traces are in `legal/PRIVACY-REQUIREMENTS.md` (§4 and §5).

### A1. Who we are and what this covers
| # | Statement | Evidence |
|---|---|---|
| 1.1 | The policy covers the Humanity app and the standalone OculOS, ManOS and Murmur apps (modules OculOS, ManOS, Murmur, MeetingKit, AIKit, LicenseKit), version [PLACEHOLDER]. | `Humanity/Package.swift:8-14` |
| 1.2 | The source code is public under the MIT license, so anyone can verify these statements. | `LICENSE`; `README.md:62-64` |
| 1.3 | Operator: [LEGAL ENTITY NAME], [MAILING ADDRESS]; contact [CONTACT EMAIL]. | [PLACEHOLDER] |

### A2. Data the apps process on your Mac (and whether the developer receives any of it)
| # | Statement | Evidence |
|---|---|---|
| 2.1 | We operate no servers that receive app data. The app code sends data only to Gumroad (license checks), to an AI provider you choose with your own key, to Hugging Face (model downloads) and, through macOS, to Apple (speech model downloads). | `LicenseKit/Sources/LicenseKit/License.swift:12,62-79`; `AIKit/Sources/AIKit/Provider.swift:46-68`; `MeetingKit/Sources/MeetingKit/Diarizer.swift:24-30`; `Murmur/Sources/MurmurUI/Engine/Transcriber.swift:70-73` |
| 2.2 | Camera video is analyzed frame by frame in memory and isn't saved or sent by the app. | `OculOS/Sources/GazeKit/CameraCapture.swift:192-202`; `OculOS/Sources/GazeKit/FaceFeatureExtractor.swift:44-105`; `ManOS/Sources/ManOSUI/Engine/HandEngine.swift:267-289` |
| 2.3 | OculOS saves the following in `calibration.json`:<br>• eye and head measurements (pupil position, eye openness, head angles, face position and size);<br>• tiny 10 × 6-pixel grayscale eye patches;<br>• your display's name and size;<br>• up to 400 of these samples captured when you click the mouse ("Learn from clicks", on by default). | `OculOS/Sources/GazeKit/GazeFeatures.swift:20-37`; `OculOS/Sources/GazeKit/EyePatch.swift:7-9`; `OculOS/Sources/OculOSUI/Engine/Persistence.swift:6-19,110-124`; `OculOS/Sources/OculOSUI/AppModel.swift:57-59,103-125` |
| 2.4 | OculOS gaze recordings, which you start yourself, save gaze coordinates over time. If you turn on the optional setting, they also save a screenshot of the whole display, which can show anything that was on screen. | `OculOS/Sources/OculOSUI/Recording/RecordingStore.swift:6-16,54-61`; `OculOS/Sources/OculOSUI/Recording/ScreenshotCapture.swift:8-19`; `OculOS/Sources/OculOSUI/AppModel.swift:54-56,265-268` |
| 2.5 | ManOS tracks your hands in memory and saves only pinch thresholds, handedness and settings, in macOS preferences. | `ManOS/Sources/ManOSUI/Engine/Persistence.swift:5-29`; `ManOS/Sources/HandKit/HandProfile.swift:4-33` |
| 2.6 | Murmur uses the microphone only while you dictate or record a note. Speech is recognized on your Mac; on older macOS, recognition refuses to run unless it can stay on-device. | `Murmur/Sources/MurmurUI/AppModel.swift:135-191`; `Transcriber.swift:29-34,197-202` |
| 2.7 | **Current behavior:** with "Keep dictations in the Library" on (the default), Murmur saves each dictation's text, its audio, the name of the app you dictated into, and any cleaned-up text. **[DEPENDS ON FIX P1-1]:** audio is saved only if you turn on "Keep dictation audio". | `Murmur/Sources/MurmurUI/AppModel.swift:75-77,168-170,261-282`; `Murmur/Sources/MurmurKit/Recording.swift:4-37` |
| 2.8 | Notes are always saved with their audio and transcript, plus a summary and action items. | `AppModel.swift:168,279-287` |
| 2.9 | When macOS reports a secure (password) input field, Murmur doesn't clean up, save or send the dictation. It types the text into the field, and deletes the audio. This depends on macOS reporting secure input and may not detect every password field. | `AppModel.swift:153,246-249,277-278`; `Murmur/Sources/MurmurUI/Engine/TextInserter.swift:53` |
| 2.10 | Meetings (inside Murmur) record two audio tracks when you press Record: your microphone, and either the call app you pick or all system audio. After the call they create, on your Mac, a word-by-word transcript, a "who spoke when" analysis, and a numeric voice signature (voice embedding) for each remote speaker. All of this is stored with the meeting. | `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:68-104`; `MeetingKit/Sources/MeetingKit/Meeting.swift:5-25,104-133`; `MeetingKit/Sources/MeetingKit/Transcript.swift:31-41` |
| 2.11 | **Current behavior:** if you type a name for a speaker, Murmur saves a voice profile: the name plus up to 20 voice embeddings. It then recognizes that voice automatically in later meetings. **[DEPENDS ON FIX P0-3]:** this happens only if you turn on "Remember this voice" and confirm that the person agreed. | `Meeting.swift:53-67`; `MeetingKit/Sources/MeetingKit/VoiceProfileStore.swift:6-19,82-103` |
| 2.12 | Clipboard. To paste dictation, Murmur briefly saves your current clipboard in memory, pastes, then restores it after half a second (you can turn this off). The activation window checks the clipboard once for a license key when it opens. Neither saves nor sends clipboard contents. | `TextInserter.swift:11-36`; `Murmur/Sources/MurmurKit/PasteSequence.swift:59-75`; `LicenseKit/Sources/LicenseKit/ActivationWindow.swift:69-72` |
| 2.13 | Accessibility. To snap a gaze click to a button, OculOS reads the type and position of on-screen controls near the gaze point. It doesn't read their text or values. ManOS, OculOS and Murmur post synthetic mouse and keyboard events to control the Mac and insert text. | `OculOS/Sources/GazeKit/GazeClick.swift:80-124`; `ManOS/Sources/ManOSUI/Engine/EventInjector.swift:24-131`; `TextInserter.swift:64-84` |
| 2.14 | ManOS reads on-screen window sizes (not titles) to scroll by one screen when you flick. | `EventInjector.swift:78-87` |
| 2.15 | The apps don't monitor keystrokes. They register only their own keyboard shortcuts. OculOS watches mouse-click positions for "Learn from clicks". | `OculOS/Sources/GazeKit/HotKey.swift:18-44`; `OculOS/Sources/OculOSUI/AppModel.swift:103-112` |
| 2.16 | Settings, custom dictation words and AI routing choices are stored in macOS preferences. AI keys are stored in your login Keychain, not synced to iCloud Keychain. The license key is stored in a file (**[DEPENDS ON FIX P2-4]:** in the Keychain). | `AIKit/Sources/AIKit/KeychainStore.swift:9-19,42-47`; `License.swift:25-37`; `Murmur/Sources/MurmurUI/Engine/Persistence.swift:6-19` |

### A3. Data not collected (only what the code guarantees)
| # | Statement | Evidence |
|---|---|---|
| 3.1 | The apps contain no analytics, advertising, tracking or telemetry code and no third-party SDK that sends usage data. | grep of app sources and FluidAudio's diarization/download path (`legal/PRIVACY-REQUIREMENTS.md` §5) |
| 3.2 | The app never sends audio, camera images, screenshots, gaze data, hand data, calibration data, voice embeddings or voice profiles anywhere. | No network path for these (§5 of the requirements doc) |
| 3.3 | The apps don't create an account and don't ask for your name, email or phone number. Gumroad collects purchase details when you buy (see A6). | `ActivationWindow.swift:33-89` |
| 3.4 | No device identifier or hardware fingerprint is sent with license checks. | `License.swift:66-70` |

### A4. Local and cloud processing
| # | Statement | Evidence |
|---|---|---|
| 4.1 | Every AI task defaults to "On-device": Apple Intelligence where available, otherwise built-in rules. | `AIKit/Sources/AIKit/AISettings.swift:32-36`; `Murmur/Sources/MurmurUI/Engine/Intelligence.swift:36-42` |
| 4.2 | If you connect a provider with your own API key and choose it for a task, the app sends that task's text to that provider:<br>• dictation text (cleanup);<br>• note and meeting transcripts, including names you gave speakers (summaries).<br>Audio is never sent. | `AIKit/Sources/AIKit/Tasks.swift:33-85,99-114`; `Murmur/Sources/MurmurUI/Views/MeetingsView.swift:83-90` |
| 4.3 | **Current behavior:** once a provider is chosen for summaries, every new note and meeting is summarized by it automatically. **[DEPENDS ON FIX P1-5]:** the app asks before sending each meeting. | `MeetingsView.swift:60`; `Murmur/Sources/MurmurUI/AppModel.swift:287` |
| 4.4 | Supported providers: Groq, Google Gemini, OpenAI, Anthropic, OpenRouter, Mistral, DeepSeek, Together, xAI, and Ollama (runs locally on your Mac). | `AIKit/Sources/AIKit/Provider.swift:46-68` |
| 4.5 | The app sends your key to the provider to check it and to list its models. This happens when you press Test or Save and when the AI Providers screen loads models (no content is sent). | `AIKit/Sources/AIKitUI/AIProvidersView.swift:23,60-63,169-192`; `AIKit/Sources/AIKit/LLMClient.swift:57-62` |
| 4.6 | AI requests use HTTPS (except Ollama on `localhost`). They aren't cached to disk, and the app doesn't log them. | `LLMClient.swift:32-40,106` |

### A5. Processors, recipients and third parties
| # | Recipient | What they receive | When | Their policy |
|---|---|---|---|---|
| 5.1 | **Gumroad** (sales, payment, license keys) | Your license key, our product ID, and whether this is a new activation; plus your IP address and standard connection data | Activation, and at launch if 7+ days since the last check | https://gumroad.com/privacy [verify] |
| 5.2 | **AI provider you choose** (your own account and key) | §4.2 text, your key, IP address | Only for tasks you route to it | Each provider's terms (links in Part B) [verify] |
| 5.3 | **Hugging Face** (model hosting, via the open-source FluidAudio library) | Requests for model files; IP address; standard connection data | First meeting processed, or when models are missing or updated | https://huggingface.co/privacy |
| 5.4 | **Apple** (macOS) | Speech-model download requests made by macOS; crash and analytics data only if you turned on sharing in macOS | First dictation in a language (macOS 26); per your macOS settings | https://www.apple.com/legal/privacy/ |
| 5.5 | **GitHub** (download host, issue tracker) | Normal web-request data when you download releases or open issues | When you visit | https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement |
| 5.6 | We don't sell or share personal information for cross-context behavioral advertising, and the app has no code that could. **[JURISDICTION-DEPENDENT]** (CCPA "sell or share" disclosures) | — | — | — |

### A6. Payment and license verification
| # | Statement | Evidence |
|---|---|---|
| 6.1 | Purchases happen on Gumroad's website. Gumroad processes your payment and contact details under its own policy. We never see your full card number. Gumroad shares order details with us as the seller, such as [PLACEHOLDER: e.g. email, name, country, purchase date]. Counsel and the owner must confirm which fields from the Gumroad seller dashboard. | `License.swift:10`; `README.md:24-25` |
| 6.2 | The app checks your key with Gumroad's license API. It reads only whether the key is valid and whether the purchase was refunded, charged back or disputed. It ignores and doesn't store the rest of Gumroad's reply. | `License.swift:90-107` |
| 6.3 | The app works offline for up to 60 days after the last successful check. If Gumroad says a key is no longer valid, the app deletes it from your Mac. | `License.swift:14-17,111-119` |

### A7. Website and cookies
| # | Statement | Evidence |
|---|---|---|
| 7.1 | The apps don't use cookies. Network sessions are ephemeral (no on-disk cookie store). | `LLMClient.swift:34-40`; `License.swift:73` |
| 7.2 | The purchase page is Gumroad's, and Gumroad sets its own cookies. The download pages are on GitHub, which sets its own cookies. We don't run a separate website. [PLACEHOLDER if one is added] **[JURISDICTION-DEPENDENT]** (ePrivacy/cookie consent applies to the operator of those pages). | `README.md:22-25` |

### A8. Retention and deletion
| # | Statement | Evidence |
|---|---|---|
| 8.1 | **Current behavior:** data on your Mac is kept until you delete it. There are no automatic deletion periods, except:<br>• learned-click samples (newest 400 kept);<br>• voice profiles (newest 20 samples per person). | `legal/PRIVACY-REQUIREMENTS.md` §7.1 |
| 8.2 | **[DEPENDS ON FIX P1-4, P1-9, P0-4]:** these default periods apply:<br>• dictation history: 30 days;<br>• meeting audio: 7 days after processing;<br>• unnamed speakers' voice embeddings: 30 days;<br>• voice profiles: 12 months after last recognized;<br>• gaze recordings: 90 days.<br>You can change them in Settings. | — |
| 8.3 | In-app deletion that exists today:<br>• OculOS Clear Calibration;<br>• delete a gaze recording;<br>• Murmur delete a recording / Delete All Recordings;<br>• delete a meeting (right-click);<br>• delete voice profiles;<br>• remove an AI key. | `OculOS/Sources/OculOSUI/Views/CalibrationPage.swift:100`; `OculOS/Sources/OculOSUI/Views/RecordingsPage.swift:16`; `Murmur/Sources/MurmurUI/Views/LibraryView.swift:182-183`; `Murmur/Sources/MurmurUI/MurmurModule.swift:134,143`; `MeetingsView.swift:161,170`; `MeetingKit/Sources/MeetingUI/VoiceProfilesView.swift:25,41`; `AIProvidersView.swift:136-141` |
| 8.4 | **Current behavior:** no single "delete everything" button; settings, the hand profile and the license file are removed manually (paths in Part B). **[DEPENDS ON FIX P1-2]:** Settings → Data & Privacy → Delete All Humanity Data. | — |
| 8.5 | **Current behavior:** deleting a voice profile doesn't remove voice embeddings stored inside past meetings; deleting the meeting does. **[DEPENDS ON FIX P0-4]** | `VoiceProfileStore.swift:124-127`; `Transcript.swift:31-41` |
| 8.6 | Deleting in the app doesn't delete copies in Time Machine backups, APFS snapshots, other backups, or files you exported. **[DEPENDS ON FIX P1-7]:** you can exclude recordings from Time Machine. | No `isExcludedFromBackup` anywhere |
| 8.7 | We can't delete data you sent to an AI provider; the provider's own retention rules apply. | Provider terms |

### A9. Permissions
| # | macOS permission | Used for | Evidence |
|---|---|---|---|
| 9.1 | Camera | Eye tracking (OculOS) and hand tracking (ManOS) | `Humanity/Resources/Info.plist:31-32` |
| 9.2 | Microphone | Dictation, notes, your side of meetings | `Humanity/Resources/Info.plist:35-36` |
| 9.3 | Speech Recognition | On-device transcription (older macOS) | `Humanity/Resources/Info.plist:39-40` |
| 9.4 | System audio recording | The other side of a call | `Humanity/Resources/Info.plist:27-28` |
| 9.5 | Accessibility | Pointer and clicks, pasting and typing text, snapping gaze clicks | `Humanity/Sources/Humanity/Permissions.swift:42` |
| 9.6 | Screen Recording (optional) | Heatmap screenshots; call-audio fallback | `Permissions.swift:43`; `MeetingKit/Sources/MeetingKit/MeetingRecorder.swift:146-167` |

### A10. Analytics and crash reporting
| # | Statement | Evidence |
|---|---|---|
| 10.1 | No analytics or usage tracking. | §5 of the requirements doc |
| 10.2 | No crash-reporting service. macOS saves crash reports on your Mac and shares them with Apple only if you allow it in System Settings → Privacy & Security → Analytics & Improvements. We have no mechanism to receive them. If you choose to send us a crash report, we use it only to fix the bug. | No crash SDK in the sources |
| 10.3 | The only diagnostic the app writes to the macOS log is a dictation-latency number. The speaker-separation library logs technical messages, such as model folder paths, to the macOS log on your Mac. | `Murmur/Sources/MurmurUI/AppModel.swift:33,269`; FluidAudio `Shared/AppLogger.swift` |

### A11. Children
| # | Statement |
|---|---|
| 11.1 | The apps aren't directed to children under 13 **[JURISDICTION-DEPENDENT: 13 in the US (COPPA); up to 16 in parts of the EU (GDPR Art. 8)]**. We don't knowingly receive children's personal information. Gumroad's terms govern purchase eligibility. |
| 11.2 | Because the apps can create biometric-type data (voice embeddings, eye measurements), parents should not let children use the Meetings voice-recognition features. **[JURISDICTION-DEPENDENT]** (COPPA's amended rule counts biometric identifiers as personal information; counsel). |

### A12. Your rights
| # | Statement |
|---|---|
| 12.1 | Almost all data lives only on your Mac, under your control: you can view it (Show in Finder), export it and delete it yourself. |
| 12.2 | For data we or our processors hold (Gumroad purchase and license records), you can ask us for access, correction, deletion, portability, restriction or objection at [CONTACT EMAIL]. **[JURISDICTION-DEPENDENT]**: GDPR/UK GDPR Arts. 15–22; CCPA/CPRA rights to know, delete, correct and limit use of sensitive personal information (Cal. Civ. Code §§ 1798.100–1798.125); Colorado, Virginia, Connecticut, Texas, Oregon and other state laws; appeal processes where required. |
| 12.3 | We'll verify requests using the purchase email and respond within [30/45] days **[JURISDICTION-DEPENDENT]**. |
| 12.4 | No discrimination for exercising rights. **[JURISDICTION-DEPENDENT]** |
| 12.5 | EU/UK users may complain to their data protection authority. **[JURISDICTION-DEPENDENT]** |
| 12.6 | Biometric notice (Illinois, Texas, Washington, Colorado and others) **[JURISDICTION-DEPENDENT]**: describe the voice embeddings and eye measurements, their purpose and retention schedule, and that we don't receive, sell or disclose them. |

### A13. International users
| # | Statement |
|---|---|
| 13.1 | On-device data doesn't leave your Mac through the app. |
| 13.2 | Gumroad, AI providers and Hugging Face may process data in the United States or other countries; for example, DeepSeek states it stores data in the People's Republic of China (counsel to verify). The transfer basis is between you and the provider you chose, or under Gumroad's terms. **[JURISDICTION-DEPENDENT]** (GDPR Chapter V transfer mechanisms). |

### A14. Security
| # | Statement | Evidence |
|---|---|---|
| 14.1 | AI keys are stored in the Keychain and available only while your Mac is unlocked. They're sent only in request headers and removed from error messages. | `KeychainStore.swift:16`; `LLMClient.swift:90-97,117` |
| 14.2 | Network requests use HTTPS, except a local Ollama server. | `Provider.swift:47-66` |
| 14.3 | Apps are signed with the hardened runtime. They're **not sandboxed** and **not yet notarized**. | `Humanity/scripts/build-app.sh:45`; `scripts/app.entitlements`; `README.md:26` |
| 14.4 | **Current behavior:** files on your Mac aren't separately encrypted by the app. Turn on FileVault to encrypt them at rest. Any app running under your macOS account can read them. **[DEPENDS ON FIX P1-7]:** files are restricted to your account (0600/0700). | No `posixPermissions` or encryption anywhere |
| 14.5 | Report vulnerabilities through GitHub private vulnerability reporting. | `SECURITY.md:6-7` |

### A15. Your responsibilities when recording others
| # | Statement |
|---|---|
| 15.1 | Many places require **everyone's** consent to record a call (for example California, Florida, Illinois, Maryland, Massachusetts, Pennsylvania and Washington, and many countries outside the US). **[JURISDICTION-DEPENDENT; counsel to confirm the list]** |
| 15.2 | Saving someone's voice profile creates biometric-type data about them. Get their agreement first. **[JURISDICTION-DEPENDENT]** |
| 15.3 | **Current behavior:** the app reminds you to tell people but doesn't check. **[DEPENDS ON FIX P0-2]:** the app asks you to confirm consent before every recording and saves that confirmation with the meeting. |

### A16. Contact and changes
| # | Statement |
|---|---|
| 16.1 | Contact: [CONTACT EMAIL]; postal: [MAILING ADDRESS]; EU/UK representative: [PLACEHOLDER] **[JURISDICTION-DEPENDENT]** (GDPR Art. 27). |
| 16.2 | We'll post changes in the repository (`PRIVACY.md` and git history), update the effective date, and describe material changes in the release notes and in the app before they take effect. |

---

## Part B: Draft policy (plain language)

> **DRAFT — requires attorney review.** Bracketed items are placeholders or open questions.

# Humanity Privacy Policy

**Effective date:** [EFFECTIVE DATE]
**Applies to:** Humanity, OculOS, ManOS and Murmur for macOS, version [VERSION] and later
**Who we are:** [LEGAL ENTITY NAME] ("we", "us"). Contact: [CONTACT EMAIL]

## The short version

- Humanity watches your eyes and hands through your camera and listens through your microphone **so you can control your Mac**. That processing happens **on your Mac**.
- **We don't run servers that receive your camera images, audio, transcripts, gaze or hand data, or voice data.** The apps have no analytics, ads or tracking. The code is open source, so you can check this.
- The apps talk to the internet in only four situations:
  - checking your license with **Gumroad**;
  - an **AI provider you connect with your own key**, if you choose one;
  - downloading speaker-separation models from **Hugging Face**;
  - Apple downloading its speech model through **macOS**.
- Some things the apps save on your Mac are sensitive: recordings, transcripts, eye measurements, and voice signatures of people in your meetings. **You control them, and you're responsible for having permission to record other people.**

## 1. What the apps do on your Mac

### Camera (OculOS and ManOS)
The apps analyze camera video one frame at a time, in memory, to find your eyes, face position and hands. **Video frames aren't saved and aren't sent anywhere by the app.**

**OculOS (eye tracking) saves calibration data so it can work without recalibrating:**
- measurements of your eyes and head: where your pupils sit within your eyes, how open your eyes are, your head angle, and your face's position and size in the camera image;
- tiny, 10 × 6-pixel grayscale patches of each eye;
- your display's name and size.

**Learn from clicks** (on unless you turn it off): each time you click the mouse on the calibrated display, OculOS saves the last fraction of a second of these measurements with the click position. It keeps the newest 400. [DEPENDS ON FIX P2-2: off until you turn it on.]

**Gaze recordings** (only when you start one, with ⌥⌘R or the menu) save where you looked over time. If you turn on **Capture screenshot as heatmap background**, OculOS also saves one screenshot of your whole display at the start. **That screenshot can include anything on screen, including other people's messages or faces.** Use it with care.

**ManOS (hand control)** tracks your hands in memory and saves only your pinch sensitivity, handedness and settings.

### Microphone (Murmur)
Murmur listens **only while you dictate (⌃⌥⌘D) or record a note or meeting**. Speech is turned into text **on your Mac** using Apple's on-device speech recognition. On older macOS, Murmur refuses to transcribe rather than send audio to Apple's servers.

- **Dictations.** Murmur puts the text where you're typing. While "Keep dictations in the Library" is on (the default), it also saves:
  - the text, and a cleaned-up version;
  - the name of the app you dictated into;
  - **[current version:]** the audio recording. **[DEPENDS ON FIX P1-1:]** the audio only if you turn on "Keep dictation audio".
- **Password fields.** When macOS reports that you're typing into a password or other secure field, Murmur types the text there and **doesn't** clean it up, save it, keep its audio, or send it anywhere. This relies on macOS identifying the field as secure, which most password fields do, but not every app does. **Don't dictate passwords where you can't confirm the field is secure.**
- **Notes.** Murmur always keeps the audio, transcript, summary and action items, until you delete them.
- **Custom words** you add, such as names, are saved in your settings and used only by the on-device recognizer.

### Meetings (in Murmur)
When you press **Record**, Murmur records two audio tracks:
- your microphone;
- the audio of the call app you choose, or **all sound your Mac plays** if you pick "All system audio".

After the call, on your Mac, it:
- transcribes both tracks word by word;
- works out **who spoke when**. To do this it computes a **numeric voice signature (a "voice embedding") for each person on the call**, and stores it with the meeting.

**Voice profiles.**
- **[Current version:]** if you type a name for a speaker, Murmur saves a **voice profile**: that name plus voice embeddings. It then **recognizes that person automatically** in later meetings.
- **[DEPENDS ON FIX P0-3:]** a voice profile is saved only if you choose **Remember this voice** and confirm the person agreed. Renaming a speaker without that option saves only the label.
- Voice embeddings can't be turned back into audio, but they **can identify a person**. Many laws treat them as **biometric data**.

**Recording other people is your responsibility.** In many places, including several U.S. states and many countries, it is illegal to record a conversation unless **everyone** agrees. [JURISDICTION-DEPENDENT; counsel to confirm the examples: California, Florida, Illinois, Maryland, Massachusetts, Pennsylvania, Washington.] Always tell everyone before you record, and get their permission before saving their voice profile. **[Current version:]** the app shows a reminder. **[DEPENDS ON FIX P0-2:]** the app asks you to confirm consent before each recording and saves that confirmation with the meeting.

### Clipboard, Accessibility and window information
- **Clipboard.** To paste dictation, Murmur briefly keeps a copy of your clipboard in memory, pastes your text, then puts your clipboard back after half a second. You can turn this off. When the activation window opens, it checks the clipboard once for a license key. Clipboard contents are never saved or sent.
- If you use Apple's Universal Clipboard, text Murmur places on the clipboard may appear on your other Apple devices. **[DEPENDS ON FIX P2-6:]** Murmur marks it "this Mac only".
- **Accessibility.** The apps use this permission to move the pointer, click, scroll, press keys and insert text for you. To snap a gaze click to the nearest button, OculOS reads the **type and position** of on-screen controls near where you're looking. **It doesn't read their text or contents.**
- **Window sizes.** When you flick to the next video or page, ManOS reads the size of the window under the pointer. It doesn't read window titles.
- **Keyboard.** The apps don't record your keystrokes. They respond only to their own shortcuts.

## 2. When data leaves your Mac

| Who | What they get | When |
|---|---|---|
| **Gumroad** (our sales and license platform) | Your license key, our product ID, and whether it's a new activation, plus your IP address and standard connection details | When you activate, and when the app starts if 7 or more days have passed since the last check. The app keeps working offline for up to 60 days. |
| **An AI provider you choose** | The text of the task you sent it: dictation text for cleanup, or note and meeting transcripts (including names you gave speakers) for summaries. Also your API key and IP address. **Never audio.** | Only if you add your own key and select that provider for a task. **[Current version:]** new notes and meetings are then summarized by it automatically. [DEPENDS ON FIX P1-5: the app asks first for meetings.] |
| **Hugging Face** | Requests to download speaker-separation model files, your IP address and standard connection details | The first time you process a meeting, or when the models need updating |
| **Apple** | macOS may download Apple's speech model. Apple may receive crash and analytics data **only if you allow it** in macOS settings. | First dictation in a language (macOS 26); per your macOS settings |

**AI providers** are your choice and your account. They process your text under **their** terms, which may include storing it or, on some free plans, using it to improve their models. Read them before connecting a provider: [Groq](https://groq.com/privacy-policy/), [Google Gemini API](https://ai.google.dev/gemini-api/terms), [OpenAI](https://openai.com/policies/privacy-policy), [Anthropic](https://www.anthropic.com/legal/privacy), [OpenRouter](https://openrouter.ai/privacy), [Mistral](https://mistral.ai/terms), [DeepSeek](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html), [Together](https://www.together.ai/privacy), [xAI](https://x.ai/legal/privacy-policy). [Counsel/owner: verify every link before publishing.] **Ollama** runs on your own Mac.

**Everything else stays on your Mac.** That covers camera images, audio, screenshots, gaze and hand data, calibration, voice embeddings and voice profiles: the app has no code that sends them anywhere. We don't sell personal information or share it for advertising. [JURISDICTION-DEPENDENT: CCPA "sell/share" wording.]

**No analytics, ads or crash reporting.** The apps contain no analytics, advertising or tracking code and no crash-reporting service. macOS keeps crash reports on your Mac and sends them to Apple only if you allow it. We have no way to receive them unless you send one to us.

## 3. Buying and licensing

- You buy Humanity on **Gumroad's** website. Gumroad handles your payment and contact details under the [Gumroad Privacy Policy](https://gumroad.com/privacy). We never see your full card number.
- As the seller, we receive the order details Gumroad provides to sellers: [PLACEHOLDER: e.g. email address, name, country, purchase date]. We use them to provide licenses, support and refunds, and for legally required records.
- The app stores your license key on your Mac, in `~/Library/Application Support/Humanity/license.json` [DEPENDS ON FIX P2-4: in your Keychain]. It reads only the "valid / refunded / disputed" part of Gumroad's reply.
- **Cookies:** the apps don't use cookies. Gumroad's purchase pages and GitHub's download pages set their own cookies under their own policies. We don't operate another website. [Update if one is added.] [JURISDICTION-DEPENDENT: cookie consent.]

## 4. Where your data is stored, and for how long

The apps aren't sandboxed, so their data is in your user Library:

| Data | Location |
|---|---|
| OculOS calibration, gaze recordings, screenshots | `~/Library/Application Support/OculOS/` |
| Murmur dictations and notes (text and audio) | `~/Library/Application Support/Murmur/Recordings/` |
| Meetings (audio, transcripts, speaker analysis, summaries) | `~/Library/Application Support/Humanity/Meetings/` |
| Voice profiles | `~/Library/Application Support/Humanity/VoiceProfiles/profiles.json` |
| License key | `~/Library/Application Support/Humanity/license.json` |
| Speaker-separation models (not personal) | `~/Library/Application Support/FluidAudio/Models/` |
| Settings, ManOS hand profile, custom words, AI choices | `~/Library/Preferences/io.github.pikabrofar.humanity.plist` (standalone apps use `…humanity.OculOS`, `…humanity.ManOS`, `…humanity.Murmur`) |
| AI provider keys | Your login Keychain ("io.github.pikabrofar.humanity.ai") |

**How long:**
- **[Current version:]** the apps keep data until you delete it. The only automatic limits: OculOS keeps the newest 400 learned clicks, and each voice profile keeps its newest 20 samples.
- **[DEPENDS ON FIX P1-4 / P1-9 / P0-4:]** default periods:
  - dictation history: 30 days;
  - dictation audio: not kept;
  - meeting audio: 7 days after processing;
  - voice embeddings of unnamed speakers: 30 days;
  - voice profiles: 12 months after the person was last recognized;
  - gaze recordings: 90 days.

  You can change them in Settings.
- [JURISDICTION-DEPENDENT: a published biometric retention schedule, e.g. Illinois BIPA §15(a), Colorado C.R.S. 6-1-1314.]

**Backups.** macOS Time Machine and other backup tools copy these folders by default, and Migration Assistant copies them to a new Mac. **Deleting something in the app doesn't remove it from your backups.** iCloud Drive's "Desktop & Documents" doesn't sync these folders, but it does sync files you **export** to your Desktop or Documents. [DEPENDS ON FIX P1-7: you can exclude recordings and voice profiles from Time Machine.]

## 5. Deleting your data

**You can delete in the app:**
- OculOS → Calibrate → **Clear Calibration** (calibration and learned clicks);
- OculOS → Recordings → **Delete** (each recording and its screenshot);
- Murmur → Library → trash icon, or Settings → **Delete All Recordings…** (dictations and notes);
- Murmur → Meetings → right-click a meeting → **Delete** (its audio, transcript, speaker analysis and summary);
- Meetings → **Voice Profiles** → Delete;
- Settings → AI Providers → **Remove Key**.

**[Current version:]**
- Deleting a voice profile doesn't remove the voice embeddings stored inside past meetings; delete those meetings to remove them.
- There's no single "delete everything" button. To remove everything, quit the apps and delete the folders listed above and the preferences file. In Terminal: `defaults delete io.github.pikabrofar.humanity`. Remove the Keychain items in Keychain Access.
- **[DEPENDS ON FIX P1-2 / P0-4:]** Settings → Data & Privacy → **Delete All Humanity Data**, which also removes voice data from past meetings.

**Data you sent to an AI provider** is governed by that provider. Delete it through your account with them.

## 6. Permissions

macOS asks you to grant these to Humanity (standalone apps ask separately):

| Permission | Why |
|---|---|
| **Camera** | Eye tracking (OculOS) and hand tracking (ManOS) |
| **Microphone** | Dictation, notes and your side of meetings |
| **Speech Recognition** | Apple's on-device transcription |
| **System audio recording** | The other side of a call, for meetings |
| **Accessibility** | Moving the pointer, clicking, scrolling, pasting or typing your dictation, and snapping gaze clicks to buttons |
| **Screen Recording** (optional) | Heatmap screenshots, and a fallback way to capture call audio |

You can turn any permission off in System Settings → Privacy & Security. The features that need it will stop working.

## 7. Security

- AI keys are stored in your Keychain, available only while your Mac is unlocked, and sent only to the provider you chose, over HTTPS (except a local Ollama server).
- The apps are signed with Apple's hardened runtime. They aren't yet notarized by Apple, and they don't use the App Sandbox. That means other software running under your macOS account could read the files listed in section 4.
- **Turn on FileVault** to encrypt your disk. [DEPENDS ON FIX P1-7: the app restricts its files to your user account.]
- Please report security problems privately through GitHub's "Report a vulnerability" feature on our repository.

No system is perfectly secure. [JURISDICTION-DEPENDENT: breach-notification commitments for data we hold, which is Gumroad order data.]

## 8. Children

Humanity isn't directed to children under 13 [JURISDICTION-DEPENDENT: or under 16 where local law sets a higher age], and we don't knowingly receive personal information from children. If you believe a child has sent us personal information, contact [CONTACT EMAIL] and we'll delete it. Parents should not allow children to use meeting recording or voice profiles.

## 9. Your rights

Almost everything Humanity stores is **on your own Mac**. You can see it (Show in Finder), export it and delete it at any time, without asking us.

For the limited data we hold about you, mainly the order and license details Gumroad provides, you can ask us to:
- give you access or a copy;
- correct it;
- delete it;
- restrict or object to its use.

Email [CONTACT EMAIL]. We'll verify your request using your purchase email and reply within [30] days [JURISDICTION-DEPENDENT].

[JURISDICTION-DEPENDENT. Counsel to complete:]
- **EU/UK (GDPR / UK GDPR).** Our legal bases:
  - contract, for licensing;
  - legal obligation, for tax records;
  - legitimate interests, for fraud and refund checks.

  You can complain to your local data protection authority. [EU/UK representative, if required.]
- **California (CCPA/CPRA)** and **other U.S. states with privacy laws** (e.g. Colorado, Connecticut, Virginia, Texas, Oregon):
  - you can know, delete, correct, and limit use of sensitive personal information;
  - you can appeal a refusal at [CONTACT EMAIL];
  - we don't sell or share personal information;
  - we won't treat you differently for exercising your rights.
- **Biometric notice (e.g. Illinois, Texas, Washington, Colorado).** Murmur's meeting feature creates voice embeddings, and OculOS creates eye and head measurements. They're created and stored only on your Mac to separate speakers, recognize people you choose to name, and track your gaze. We don't receive, sell, lease, trade or otherwise profit from them. Retention: [schedule in section 4]. [Counsel: whether written-release or consent language is needed, and from whom.]

## 10. International users

The app sends nothing about your camera, audio or recordings across borders. Gumroad, AI providers and Hugging Face may process data in the United States or other countries. For example, check where your chosen AI provider stores data; DeepSeek states it uses servers in the People's Republic of China. Those transfers happen under your agreement with that provider, or under Gumroad's terms. [JURISDICTION-DEPENDENT: GDPR Chapter V transfer mechanism for any data we hold.]

## 11. Changes to this policy

We'll publish any change in our GitHub repository (`PRIVACY.md`, with full history) and update the effective date. For material changes, such as new data leaving your Mac or a new recipient, we'll say so in the release notes and in the app **before** the change takes effect.

## 12. Contact

[LEGAL ENTITY NAME]
[MAILING ADDRESS]
Email: [CONTACT EMAIL]
[EU/UK representative, if required: PLACEHOLDER]

---

### Notes for counsel (not part of the published policy)

1. Sections tagged **[Current version]** describe v1.0.0 as audited. Publish them only if the corresponding fix hasn't shipped. Never publish both versions.
2. Confirm with the owner which order fields the Gumroad seller dashboard exposes, and whether Gumroad acts as merchant of record (this affects whether it's our processor or an independent controller).
3. Key open questions are listed in `legal/PRIVACY-REQUIREMENTS.md` §10, in particular whether the developer is a "collector" or "controller" of on-device biometric data.
4. Verify every third-party URL before publishing. Provider policies change often.
