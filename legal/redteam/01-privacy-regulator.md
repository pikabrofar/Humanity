# Red team 01: State privacy regulator / FTC privacy staff

Persona: state AG or FTC privacy staff looking for claims the code does not guarantee.
Not a lawyer; nothing here says the product is safe or compliant. Read-only review of the tree at /Users/taylorpan/Cloud/Humanity (commit 1f611aa per brief; no git metadata in the working copy, so verified against files on disk). "Attorney" marks items that need counsel.

Verified OK (no finding): Speech is forced on-device (`Transcriber.swift:199-202`, `FileTranscriber.swift:86,116`; macOS 26 SpeechAnalyzer path). The only app network code is `License.swift:84`, `AIKit/LLMClient.swift` and FluidAudio's model download (`Diarizer.swift:24-30`). Cloud AI defaults to on-device (`AISettings.swift:34`). Secure-input dictation skips cleanup, history and cloud (`AppModel.swift:262-270`). Per-meeting cloud-summary prompt exists (`MeetingsView.swift:107`). Recording consent checkbox is asked every time (`MeetingRecorderControl.swift:171`). Voice-profile enrollment cannot happen without a consent date (`VoiceProfileStore.swift enroll`).

## Ranked findings

### 1. PRIVACY.md promises automatic deletion of meeting audio and transcripts that no code performs
- Scenario: PRIVACY.md:64 says meeting audio and transcripts are deleted "optionally automatically after 30, 90 or 365 days". A user picks "30 days" and believes meetings are purged. An examiner greps for the enforcement.
- Likelihood H (it is a checkable fact). Impact H (an express retention promise about recordings of third parties is the textbook FTC Act s.5 deception pattern).
- Mitigation: the setting exists only for Murmur Library items. `AppModel.swift:118` calls `RecordingStore.expired` on `recordings` only, and the picker label is "Delete recordings older than" (`MurmurModule.swift:140`). `retentionDays` is referenced nowhere in MeetingKit or `MeetingsView`. Meetings have manual delete only (`MeetingsView.swift:130`).
- Remaining risk: a false affirmative claim in the privacy page, which the Gumroad "privacy" copy and Terms s.4 point to.
- Fix: either delete the parenthetical in PRIVACY.md:64 now, or make `MeetingsView.reload()` (`MeetingsView.swift:~40`) delete meeting folders older than `retentionDays` and relabel the picker "recordings and meetings". The edit is one sentence if you choose the first path. Attorney: none.

### 2. Every meeting stores a voiceprint of every remote speaker, but PRIVACY.md says voiceprints are saved "for each person you name"
- Scenario: `meeting.json` keeps `diarization.centroids` (256-float WeSpeaker embeddings, `Transcript.swift:35`) for all unnamed speakers "so they can be remembered later" (`Meeting.swift:72-80`). A regulator or a person whose voice was captured reads PRIVACY.md:47 and the retention table and finds an undisclosed biometric store, with no consent step for those speakers.
- Likelihood M. Impact H (BIPA s.15 notice, retention schedule and written-release claims; CUBI; GDPR Art. 9).
- Mitigation: 12-month drop of unremembered centroids (`Meeting.swift:76`). That drop only runs when `MeetingsView` loads (`MeetingsView.swift:44`), not at app launch for users who never open Meetings. Meeting audio itself, which is a stronger identifier, is never auto-deleted (finding 1).
- Remaining risk: PRIVACY.md, the retention table and the UI caption (`VoiceProfilesView.swift:54`) all describe only named profiles. A Settings "Delete all voice profiles" does not clear centroids in meeting.json.
- Fix: add a table row to PRIVACY.md ("Unnamed speaker voiceprints inside each meeting, deleted 12 months after the meeting or when you delete the meeting"). Run `dropExpiredVoiceprints` from a launch-time sweep, not view load. Make "Delete All Voice Profiles" also zero centroids. Attorney: yes (BIPA/CUBI exposure for a software seller that never receives the data is contested; counsel should decide whether the "developer never receives it" framing is the position to take).

### 3. Eye biometrics and screenshots have no retention limit, and the table says "until you clear"
- Scenario: PRIVACY.md:63 lists calibration with eye crops as kept "until you clear or redo". The code has no age limit, no unused limit and no BIPA-style 3-year outer bound. The same page gives voiceprints a 3-year cap, which invites the question of why eye data has none.
- Likelihood M. Impact M.
- Mitigation: "Clear Calibration" button (`CalibrationPage.swift:100`) removes the file via `CalibrationStore.save(nil)` when the engine's calibration is set to nil (`AppModel.swift:282`; I did not trace that the setter persists nil, so verify). "Learn from clicks" is ON by default (`AppModel.swift:57`) and appends eye-patch samples (up to 400) silently, which the retention table does not mention.
- Related: OculOS recordings include an optional full-screen PNG (`RecordingStore.swift:94`), which can capture other people's content on screen. It is kept forever, is absent from the retention table, and is named only in passing at PRIVACY.md:38-40. Murmur Home says "no screenshots" (`HomeView.swift:69`); that is true for Murmur alone but reads as suite-wide in the all-in-one app.
- Fix: add the screenshot and learned-click samples to the PRIVACY.md table; add an age cap (for example a 3-year purge on load in `CalibrationStore.load`); reword HomeView.swift:69 to "Murmur takes no screenshots". Attorney: yes for the BIPA retention-schedule requirement (740 ILCS 14/15(a)) if the seller is ever treated as "possessing" the data.

### 4. "Delete All Humanity Data" is described as erasing "everything the apps stored", but it swallows errors and misses stores
- Scenario: user (or a deletion request from a person whose voice was recorded) runs Delete All; a file fails to delete or a store remains; the app quits reporting success.
- Likelihood M. Impact M.
- Evidence: every removal uses `try?` (`AppModel.swift:426-440`, `HumanityApp.swift:601-606`) and the app then calls `NSApp.terminate`. Not removed: API keys in Keychain (`KeychainStore.swift`), license.json (disclosed in the dialog), FluidAudio model cache, and standalone-app defaults domains (only the Humanity bundle ID domain is cleared). Deletion is plain file removal; Time Machine and APFS snapshots keep copies, which PRIVACY.md never says (`PRIVACY-REQUIREMENTS.md:22` flagged this earlier).
- Fix: PRIVACY.md:67, change to "erases the recordings, meetings, voice profiles, calibration and settings stored by the apps (not your Keychain keys, license or downloaded models, and not Time Machine backups)". In code, check results and show "Couldn't delete N items" before quitting. Attorney: none.

### 5. Third-party data-handling statements in the AI Providers UI are the developer's own claims and will go stale
- Scenario: `Provider.swift:52-80` hard-codes statements such as "not used for training", "kept about 30 days", "Deleted within about 30 days". A provider changes policy; the app still asserts the old one next to the user's decision to send other people's transcripts.
- Likelihood M. Impact M (FTC treats a seller's affirmative statements about a third party's practices as its own claim).
- Mitigation: one provider says "Data use not reviewed" and another is flagged for China storage.
- Fix: prefix each with "As of 2026-10, per the provider's published terms (link)" and show the link at `AIProvidersView.swift:81,131`; add a review date constant. Attorney: no.

### 6. UI and plist strings say more than the code guarantees in absolute terms
- "Everything runs on this Mac; your voice never leaves it" (`Murmur/SetupView.swift:14`): voice is true; "everything" is false once a cloud key is added (text leaves).
- Camera plist strings (`OculOS/ManOS/Humanity Info.plist`): "never uploaded or saved as video" is accurate but silent that eye patches and feature measurements are saved (disclosed only in PRIVACY.md).
- Microphone plist: "listens only while you dictate or record" is accurate for the hotkey flow, but the Murmur permission poll runs every second (`AppModel.swift:~128`); that polls status, not audio, so no finding beyond wording.
- Gumroad draft: "camera video and audio are processed on your Mac and never uploaded" is accurate. "download speaker-separation models once" is accurate only until the FluidAudio cache is cleared or a model version changes; no code pins that it happens once, and it starts automatically at first use with no prompt (`Diarizer.swift:30`), which discloses the user's IP to Hugging Face.
- Likelihood L-M. Impact M.
- Fix: change SetupView to "Speech and video are processed on this Mac"; add "and saves eye measurements" to the camera strings; Gumroad: "download speaker-separation models from Hugging Face the first time you process a meeting".

### 7. Gumroad "refunded key stops working" and "30-day no questions" are not guaranteed by code or by TERMS.md
- Scenario: refunded buyer keeps using the app; or a buyer is refused because TERMS.md still has "[14 / 30] days" and "[CONTACT EMAIL]" placeholders (`TERMS.md:97,106,160,173,175`).
- Likelihood H (placeholders are visible). Impact M.
- Evidence: the weekly check runs only when the app launches with network (`License.swift:117-124`); offline grace is 60 days (`License.swift:20`), so a refunded key can work up to about 60 days offline. Terms s.9.3 admits "next weekly check" but the listing says the key "stops working".
- Fix: replace placeholders before listing; Gumroad copy: "A refunded key stops working the next time the app checks with Gumroad". Attorney: yes (MA consumer-protection refund and EU withdrawal wording, Terms s.9.4).

### 8. License check disclosure understates what leaves the Mac
- PRIVACY.md says "Nothing else is sent". The request carries the key, product ID and an `increment_uses_count` flag (`License.swift:84-88`), and Gumroad sees IP address and timing. The recheck at every app launch after 7 days gives Gumroad a rough usage signal. The reply includes the buyer's email, which the app discards in memory (accurate).
- Likelihood L. Impact L-M.
- Fix: PRIVACY.md: "the key, the product ID, and, as with any web request, your IP address, which Gumroad receives". Attorney: none.

### 9. Consent records are self-attestation checkboxes held only on the user's Mac
- Scenario: a person says they never agreed to a voiceprint or recording. The seller has nothing; the user's record is a timestamp.
- Evidence: recording consent is a timestamp in `recording.json` (`MeetingRecorder.swift:18`) with no who or how, and is deleted with the meeting. Voice-profile consent is a checkbox date (`MeetingDetailView.swift:113-131`, `VoiceProfile.consentAt`) that shows "No consent recorded" for legacy profiles (`VoiceProfilesView.swift:82`). The UI itself says Illinois needs written consent (`MeetingDetailView.swift:110`), but a checkbox is not a written release, the subject never sees the retention policy, and the checkbox is the user's statement about someone else.
- Terms assent to the Terms of Sale is local (`License.swift:26-27`); the privacy-policy link goes to the mutable `main` branch (`License.swift:15`) and `termsVersion` bumps only for Terms changes, so a privacy-policy change gets no new assent.
- Mitigation: the first-run intro sheet (`MeetingRecorderControl.swift:200-219`) and "Copy to Chat" announcement help show good faith.
- Fix: add "Privacy" to the `termsVersion` bump rule; word the voice-profile checkbox "I have this person's written permission" where required, and offer an exportable text of the retention notice to show them. Attorney: yes (BIPA written release; GDPR basis for named-speaker profiles).

### 10. No contact route for access and deletion requests
- PRIVACY.md names no contact; TERMS placeholders for seller name and email are unfilled (`TERMS.md:173-175`). Several state laws (and the "anyone can ask you to delete theirs" UI copy) assume a way to ask. The honest answer is "the app's owner holds the data, not us", but nothing states that.
- Likelihood M. Impact M.
- Fix: add one PRIVACY.md section: "We hold none of this data; ask the person who recorded you. Questions: <email>". Attorney: yes (whether the seller is a "controller" under any state law given purely local processing).

### 11. Data at rest is unencrypted plain files, with no backup exclusion
- Voiceprints, calibration, transcripts and call audio are plain JSON/audio in Application Support (`VoiceProfileStore.swift:192`, `Meeting.swift:96`). Biometric statutes use a "reasonable care" standard for storage. Nothing sets file protection or `isExcludedFromBackup`. PRIVACY.md says "you can delete it at any time" but says nothing about backups or other users on the Mac.
- Likelihood L-M. Impact M.
- Fix: set `isExcludedFromBackup` on the `Humanity/` and `OculOS/` support folders; add one sentence to PRIVACY.md. Attorney: low priority.

### 12. Children and GDPR/UK boundary statements are broader than the controls
- PRIVACY.md "collects no personal information from users of any age" is true for the developer's servers but ignores Gumroad (buyer data) and Hugging Face downloads. Gumroad is covered by Terms s.8; PRIVACY.md should say "other than what Gumroad collects when you buy".
- Likelihood L. Impact L-M.
- Fix: add that exception to the Children paragraph. Attorney: yes for COPPA and EU/UK consumer scope if sales to those regions are allowed (Terms s.9.4 already assumes they are).

## Attorney list
1 (retention-claim wording), 2 and 3 (BIPA/CUBI position for a local-only seller), 7 (refund terms and EU withdrawal text), 9 (written release, assent evidence), 10 (controller status), 12 (COPPA/EU scope).

## Fastest wins before listing (copy-only, under an hour)
Delete or implement the meeting auto-delete sentence (1); add unnamed-speaker voiceprints and screenshots to the retention table (2, 3); soften "erases everything" (4); fill TERMS placeholders (7); fix SetupView "Everything runs on this Mac" (6).
