# Red team 04: the malicious user

Not legal advice and not a lawyer's work. Nothing here says the product is "safe" or "compliant". Attorney items are marked **[ATTORNEY]**. Read-only review of commit 1f611aa; claims were checked against current code, not the older audits. Line numbers are current as of that commit.

Persona: a buyer who wants to secretly record calls, build voiceprints of colleagues without consent, or watch someone through ManOS, OculOS or Murmur.

## Bottom line
1. **The consent safeguards are speed bumps, not locks.** That is fine for a local MIT tool. No client-side gate stops a determined bad actor, and the product cannot be made to. The goal is to deny the developer the "built for covert use" label, not to stop misuse.
2. **The code is weaker than the legal docs say.**
   - `RECORDING-CONSENT-UX.md` 4.3, `LEGAL-COMPLIANCE.md` 2.5 and `EULA-DRAFT.md:96` all describe a persistent, non-hideable recording banner.
   - `PRIVACY-REQUIREMENTS.md:592` also asks for a 30-minute reminder.
   - Neither is built. The only in-app indicator is a dot inside the Meetings pane.
   - In discovery, the developer's own documents would show the risk was identified and the stated fix was not shipped. This is the largest developer-side exposure in this report.
3. **Voiceprints of everyone on a call are stored by default.** Only "remember" is gated by the attestation. See finding 3.
4. **Positive design facts, to preserve:**
   - nothing is uploaded;
   - recording starts only from a user click (`MeetingRecorder.swift:71-74`);
   - there is no stealth setting, no scheduler, no URL scheme and no AppleScript;
   - the per-recording confirmation is asked every time and never remembered (`MeetingRecorderControl.swift:171`);
   - "Stop & Delete" exists (`:67`);
   - `consentConfirmedAt` is saved with each recording;
   - Terms section 5 bans covert use (`TERMS.md:58-62`).

## Bypass summary (the three safeguards you asked about)
| Safeguard | How a malicious user gets past it | Effort |
|---|---|---|
| Intro consent checkbox | Tick it. Or `defaults write` the `MeetingKit.consentIntroVersion` key (`MeetingRecorderControl.swift:21-22`). Or build from source. | Seconds |
| Per-recording "everyone agreed" toggle (`:142`) | Tick it. It is self-attestation with no verification and no announcement step. | One click |
| Remember-voice attestation (`MeetingDetailView.swift:113`, `VoiceProfileStore.enroll`) | Tick it. `profiles.json` is plain JSON, so `consentAt` can also be edited by hand. | One click |
| Recording indicator | Only the in-pane dot (`:71-85`) plus the menu bar glyph (`Murmur MurmurApp.swift:36`, `HumanityApp.swift:551`). Close the window, switch Spaces, or hide the menu bar item. | Trivial |
| Terms section 5 | Only binds buyers who assent. MIT source builds are outside it (`TERMS.md:18`). | n/a |

Only the macOS orange mic dot and purple audio-capture dot are non-bypassable, and other participants cannot see them.

## Findings (ranked)

### 1. No persistent or floating recording banner; the legal docs promise one (Likelihood H, Impact H)
- **Scenario:**
  - The user starts a Meetings recording, then closes or hides the window, which is easy in the menu-bar app. Humanity is `LSUIElement` (`Humanity/Resources/Info.plist:25`), so there is no Dock icon.
  - Recording continues, because the recorder lives in the app model. Nothing re-surfaces it.
  - The only remaining cues are a menu-bar glyph and an item reading "● Recording a Meeting…" (`MurmurModule.swift:69-70`). Both are visible only to the person at the Mac.
  - The same `record.circle.fill` symbol is reused for OculOS gaze recording (`HumanityApp.swift:551-554`), so it is ambiguous.
  - This is also the "forgotten recording" case: nothing nags during a 3-hour recording.
- **Existing mitigation:**
  - the in-pane dot and timer (`MeetingRecorderControl.swift:71-85`);
  - the menu bar glyph.
- **Remaining risk:**
  - No tool can show other participants anything, but the local indicator is the only evidence that the product is not covert. A buried one weakens the MA c.272 section 99 "aid another to secretly record", 18 U.S.C. 2512 and FTC "unfair design" arguments. **[ATTORNEY]**
  - Apple App Store guideline 3.3.3 is cited in `RELEASE-CHECKLIST.md:315`. It is not directly applicable to a direct download, but it states the same norm.
- **Fix, a minimal version of `RECORDING-CONSENT-UX.md` 4.3:**
  - Add one small non-activating `NSPanel` at `.floating` level on all Spaces, in MeetingKit's UI target.
  - Content: red dot, elapsed time, "Recording", Stop.
  - Collapsible to a dot but not closable while recording.
  - Show it from `MeetingRecorder.isRecording`.
  - Add a distinct menu bar symbol (for example `waveform.badge.mic` or a red tint) for meetings, not shared with gaze.
  - Add a gentle reminder notification at 30 minutes and every 30 minutes after. Never auto-stop.
  - Do not add a "hide indicator" preference, ever.

### 2. Consent toggles are unverifiable self-attestation with no record of the announcement (L H, I M)
- **Scenario:** the user ticks "Everyone on this call knows it's being recorded and agrees" without telling anyone, then records.
  - `consentConfirmedAt` is written whether or not the announcement happened.
  - It can read as proof of consent when it is only proof of a click. In a dispute it could cut either way.
  - The wording "and agrees" asserts something the user cannot know about silent participants.
  - Note `MeetingRecorder.start(consentConfirmedAt:)` is a public API that takes any `Date`, so any caller can supply one (`MeetingRecorder.swift:74`).
- **Existing mitigation:**
  - The toggle disables Start (`MeetingRecorderControl.swift:151`).
  - The Copy to Chat button (`:122-130`).
  - The caption (`:97`).
- **Remaining risk:** the designed evidence trail (the 4.3 "Mark announced" timestamp) was not built. Nothing records that the chat message was copied.
- **Fix:**
  - Record `announcementCopiedAt` when "Copy to Chat" is clicked, in addition to `consentConfirmedAt`. Two timestamps, same file, tiny change.
  - Soften the toggle to "I've told everyone on this call that I'm recording." That is what the user can truthfully attest.
  - Do not add friction beyond this. A malicious user ignores it anyway; the honest user gets accurate wording.

### 3. Every call speaker's voiceprint is created and stored by default (L H, I H) [ATTORNEY]
- **Scenario:** the user records a call with 5 colleagues.
  - `MeetingProcessor.process` runs diarization, which yields a 256-float embedding per speaker. The meeting stores them in `meeting.json` under `diarization.centroids` (`Meeting.swift:60`, `:73-80`, `:131`).
  - They are kept 12 months "so they can be remembered later".
  - No attestation is asked for this. The attestation gates only `enroll`.
  - The embeddings are the biometric data, so BIPA, Texas CUBI and GDPR Art. 9 questions arise at collection, before any "Remember".
  - Matching against saved profiles also runs on every new meeting (`profiles.assign`, `Meeting.swift:142`), so a stored profile silently identifies a person in a recording they never knew about.
- **Existing mitigation:**
  - on-device only;
  - 12-month expiry of unremembered centroids (`Meeting.dropExpiredVoiceprints`);
  - voice profile expiry and delete-all;
  - the BIPA warning text (`MeetingDetailView.swift:110`).
- **Remaining risk:** the docs describe the stored centroids as a convenience. A plaintiff would describe them as unconsented biometric collection by a tool built to do it. Whether a purely local, user-run process is "collection" by the developer is a counsel question, but the user is plainly collecting.
- **Fix, minimal:**
  - Keep centroids in memory during processing only. Persist a centroid only when the user ticks "Remember this voice" (it is already available at that moment if the user names the speaker in the same session).
  - Fallback if re-naming later is a must-have: keep the centroids but shorten retention to 30 days, and say so in the intro sheet.
  - Delete `diarization.centroids` on "Stop & Delete" and on meeting delete. Verify `MeetingsModel.delete` already removes the folder (`MeetingsView.swift:131-134`); it does.

### 4. Planted audio files bypass recording consent and enrol voiceprints from any source (L M, I H)
- **Scenario:** the user did not record with this tool at all.
  - They drop `mic.m4a`/`system.m4a` and a `recording.json` into `~/Library/Application Support/Humanity/Meetings/<folder>/`. The audio could be a covert phone recording, a leaked call or a podcast.
  - On next launch it appears under Recent as "Not processed" (`MeetingRecording.unprocessed`, `MeetingRecorder.swift:31-37`).
  - "Process Again" (`MeetingsView.swift:184`) transcribes it, diarizes it, matches against saved profiles, and allows naming and remembering.
  - `consentConfirmedAt` can simply be forged in `recording.json`, or absent. `process` never checks it (`MeetingRecorder.swift:118-148`).
  - The tool becomes a covert-recording transcription and voice-identification engine for audio it did not capture. The profiles also let the user identify "who is this voice?" across clips.
- **Existing mitigation:** none specific to this path. The attestation still gates "remember".
- **Remaining risk:**
  - Needs filesystem skill, so Likelihood is M, not H.
  - Because it is the user's own Mac and the user's own file, a legal argument exists that this is just a transcriber like any other.
  - But the app does voice-matching on it, which a generic transcriber does not.
- **Fix:**
  - In `MeetingsModel.process` (Murmur `MeetingsView.swift:58`), skip voice-profile matching when `recording.consentConfirmedAt == nil`. Label speakers "Speaker N" in that case.
  - Do not add signing or tamper-proofing. It is local data; the point is that the app never auto-identifies people in audio it did not witness being consented.

### 5. Marketing and documentation can still feed a "designed for covert use" argument (L M, I H) [ATTORNEY]
- **Scenario:** a plaintiff or journalist builds the case from the developer's own materials.
  - "Never marketed as covert" is true of the README, which says recording "may require their consent" (`README.md:66`). But the following were found:
    - the Gumroad copy says audio "never leaves your Mac" next to a consent note. A reader could take that as a reassurance for secret recording;
    - the product name "Humanity" and the tutorial give no consent framing at first launch (`HumanityApp.swift:564-571`);
    - the internal docs call the missing safeguards "required" (finding 1).
  - Sold pseudonymously for $5+ with a 30-day "no questions asked" refund, so the developer cannot know who buys, and a bad actor can refund after misuse.
  - The EULA is "pending review" (`TERMS.md:1`) with seller-name placeholders (`:10`), so Terms section 5 is not yet in effect.
- **Existing mitigation:** Terms section 5; the in-app caption; the intro sheet.
- **Fix:**
  - Put one line near the top of the Gumroad description: "Meetings can't hide the fact that it's recording; tell people before you record." Lead with the visible-by-design point.
  - Never use the words "discreet", "background" or "silent".
  - Resolve the doc-vs-code gap in finding 1 before launch, or edit the docs to say what is shipped.
  - Show the Terms at activation with a click-through (`LicenseKit/ActivationWindow.swift`, per `EULA-DRAFT.md:10`).

### 6. Room and in-person capture through the mic track (L M, I M) [ATTORNEY]
- **Scenario:** the user chooses any running app (or a quiet one) as the "call" source and places the Mac in a meeting room. The mic track records the room as "You" (`MeetingRecorder.swift:93-98`).
  - The picker requires only that some app is chosen (`MeetingRecorderControl.swift:64`).
  - The consent text refers to "this call". In-person conversations fall under the oral-communication rules (c.272 section 99, 720 ILCS 14-2).
  - The transcript labels every voice as "You", but the audio is still captured, and the audio files persist.
- **Existing mitigation:** the dots and the macOS mic indicator (visible to people in the room only if they see the screen).
- **Fix:**
  - Cheap: when the call track is silent for the whole recording and the mic track has speech, add a post-hoc notice on the meeting detail. The existing silence warning (`MeetingRecorder.swift:131`) is a start.
  - Add a pre-start line in the confirmation: "Includes your microphone, which also picks up people in the room."
  - Do not try to detect in-room speakers.

### 7. "All system audio" and open-ended recording (L M, I M)
The all-audio option (`MeetingRecorderControl.swift:47`) captures every app, and there is no length limit or reminder. The silent fallback is gone (`:160-161`, `:187`). Fix: one-line inline warning on selection, plus the 30-minute reminder from finding 1.

### 8. OculOS "Hide OculOS while recording" and full-screen screenshots (L L-M, I M) [ATTORNEY]
- **Scenario:** at a shared or work computer, the user calibrates for another person (a coworker or a partner), turns on "Hide OculOS while recording" (`OculOS/.../SettingsView.swift:107`, `AppModel.swift:299-302`) and "Capture screenshot" (`:111`). The app hides, a whole-display screenshot is taken, and a gaze trace is saved.
- **Existing mitigation:**
  - recording needs an active calibration (`AppModel.swift:294`), which needs the subject to take part;
  - the menu bar glyph and the macOS camera indicator stay on;
  - Terms section 5.3 names capturing another person's gaze;
  - recording stops with ⌥⌘R.
- **Remaining risk:** the setting is literally a hide-the-tool toggle. The only reason for it is the user's own work. It is the one place where the code has a "hide" option.
- **Fix:**
  - Keep the menu bar glyph visible (it already is) and give OculOS recording its own symbol so it differs from the meeting glyph.
  - Reword the toggle to "Hide windows while recording (menu bar stays visible)". Change the text only.
  - Mention the screenshot caveat in the same row.
  - ManOS and Murmur dictation have no equivalent hide option, and the dictation HUD shows on all Spaces.

### 9. Voice profile store is editable plain JSON; the attestation can be forged (L M, I L)
`profiles.json` (`VoiceProfileStore.swift:7-17`) can be hand-edited, so `consentAt` is not proof. Fix: change the label "Agreed <date>" (`VoiceProfilesView.swift:85`) to "You confirmed <date>". No signing.

### 10. Refine path can mix a second person's voice into an existing profile (L L, I L)
Naming with the same name and ticking the attestation adds samples to that profile (`Meeting.swift:63-64`). It degrades accuracy only. No fix needed; optionally show "Adds a sample to <Name>'s profile".

### 11. Transcript to cloud AI is the only egress for others' speech (L L, I M) [ATTORNEY]
Use or disclosure statutes (720 ILCS 14-2(a)(5), 18 U.S.C. 2511(1)(c)-(d)) could reach a user who sends a covert transcript to a provider. Existing gate: per-meeting "OK to send?" (`MeetingsView.swift:100-103`), on-device default, own key. Check the visible gate text says it contains other people's words.

### 12. Pseudonymous sale plus no-questions refund (L M, I L)
A bad actor can buy, misuse and refund; a revoked key does not stop an installed or source build. Fix: no identity checks or telemetry (would breach the privacy promise). Add an abuse-report contact in About and a policy to revoke on credible report. **[ATTORNEY]** on Gumroad refund interaction.

## Could the developer be accused of designing for covert use?

**Facts against the accusation (strong):**
- no hide, stealth or scheduled recording for Meetings, and no deep links or scripting;
- a mandatory two-step consent flow, every time;
- visible timer and dot, menu bar glyph, "Stop & Delete" for objections;
- Terms section 5 forbids covert use, and the docs repeatedly say "never build stealth";
- everything is local, which separates this from `Luis v. Zang` (spyware routing to vendor servers) and from cloud note-takers.

**Facts for the accusation (what a plaintiff would use):**
- The legal docs say a persistent banner is required and it is not shipped (finding 1).
- Voiceprints of everyone on a call are stored by default (finding 3).
- The OculOS hide-while-recording toggle (finding 8).
- Consent toggles phrased as assertions the user cannot know (finding 2).
- The consent evidence is a self-set timestamp.
- The `LSUIElement` menu-bar-only design keeps no visible app on screen after the window closes.

**Assessment:** none of these is stalkerware-grade on its own; together with the doc-vs-code gap, they are the easiest part of the file to attack. Fixing findings 1, 2 and 3 removes most of it. Whether sale of the Meetings feature could raise 18 U.S.C. 2512 or MA c.272 section 99 "aid" questions is a counsel decision. **[ATTORNEY]**
## Proportionate hardening list (smallest set that matters)

Do these; they do not annoy normal users:
1. Floating, non-closable recording panel and a distinct meeting glyph (finding 1).
2. 30-minute "still recording" reminder, no auto-stop (findings 1 and 7).
3. Do not persist diarization centroids unless "Remember" is ticked (finding 3).
4. Skip voice matching when `consentConfirmedAt` is nil (finding 4).
5. Store `announcementCopiedAt`; reword the toggle to what the user can truthfully attest (finding 2).
6. Reword "Agreed <date>" to "You confirmed <date>" (finding 9).
7. Reword the OculOS hide toggle (finding 8).
8. Tighten marketing copy and put the "can't hide" line first (finding 5). Add an abuse contact (finding 12).

Do not do these: identity checks or telemetry; signing local files; per-launch dialogs; geolocated consent text; any "covert use detector" (easy to defeat, invites false positives).
## Attorney list
- Finding 1 and "could the developer be accused": c.272 section 99 "aid", 18 U.S.C. 2512, FTC unfairness, and whether doc-vs-code gap matters.
- Finding 3: whether local diarization embeddings are "collected" by the developer or only by the user, under BIPA, CUBI and GDPR Art. 9. Also the EU AI Act provider question in `RECORDING-CONSENT-UX.md` section 3.
- Findings 5 and 12: Terms effectiveness (still marked "not yet in effect"), the refund and revocation language, and the abuse-contact policy.
- Findings 6, 8 and 11: in-person recording rules and the use or disclosure statutes.
