# Recording-consent and voice-profile UX

Research-engineering note, not legal advice. 2026-10-01. Scope: Murmur → Meetings (MeetingKit) and voice profiles.

## 1. Why this matters for this app specifically

- **Other participants see no indicator.**
  - MeetingKit captures the call app's audio with a Core Audio process tap or ScreenCaptureKit, plus the local mic (`MeetingKit/Sources/MeetingKit/Capture/*`).
  - Zoom, Teams and Meet show recording notices only for *their own* recording feature.
  - Other people on the call get **no signal** that Humanity is recording. The user's announcement is the only notice they will ever get.
- **"All system audio" captures everything.** That includes media and other calls.
- **Naming a speaker silently creates a biometric profile.**
  - In `MeetingDetailView.swift`, clicking a speaker name and choosing **Save** calls `Meeting.name(speaker:as:in:)`.
  - That function **enrolls a voiceprint** (`VoiceProfileStore.enroll`) of a third party. There is no separate choice.
- **Transcripts can leave the Mac.**
  - Summaries can go to a cloud provider (`AIKit/Tasks.summarize`).
  - That discloses the *contents* of other people's speech to a third party.
  - Some wiretap statutes separately punish **use or disclosure** of an unlawfully recorded conversation: [720 ILCS 5/14-2(a)(5)](https://www.ilga.gov/documents/legislation/ilcs/documents/072000050K14-2.htm) and [18 U.S.C. §2511(1)(c)–(d)](https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title18-section2511&num=0&edition=prelim).
- **Current safeguard.** A grey caption under the recorder: "Tell everyone on the call that you're recording before you start." It has no gate, no persistent banner and no record that consent was given.
- **The developer's own exposure depends on design, not on EULA words.**
  - [M.G.L. c. 272 §99](https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99) B.4 defines interception to include "aid another to secretly … record". §99 C.6 adds accessory liability.
  - Illinois [14-2(a)(4)](https://www.ilga.gov/documents/legislation/ilcs/documents/072000050K14-2.htm) and [18 U.S.C. §2512](https://www.law.cornell.edu/uscode/text/18/2512) target devices "primarily useful" for *surreptitious* recording.
  - The FTC banned the stalkerware maker SpyFone from the surveillance business ([2021](https://www.ftc.gov/news-events/news/press-releases/2021/09/ftc-bans-spyfone-ceo-surveillance-business-orders-company-delete-all-secretly-stolen-data)).
  - A visible, non-hideable recording state is the strongest evidence that Humanity is *not* a covert tool.

## 2. U.S. law

**Federal.** One-party consent: a participant may record ([18 U.S.C. §2511(2)(d)](https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title18-section2511&num=0&edition=prelim)), unless the purpose is criminal or tortious. States may be stricter.

**All-party (two-party) consent states.** The table follows the RCFP classification ([Reporter's Recording Guide](https://www.rcfp.org/introduction-to-reporters-recording-guide/)). Statutes linked to official sources.

| State | Statute | Scope / notes | Example exposure |
|---|---|---|---|
| **Massachusetts** (seller's home) | [G.L. c. 272 §99](https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99) | Bans *secret* recording of any wire or oral communication without "prior authority by all parties". No expectation-of-privacy limit (*Commonwealth v. Hyde*, 434 Mass. 594 (2001)). Recording is not "secret" if the parties have **actual knowledge** (*Commonwealth v. Jackson*, 370 Mass. 502 (1976)). So a clear announcement plus continued participation is the practical standard | Felony, up to 5 yrs / $10k. Civil: actual damages, but at least $100/day or $1,000, plus punitive damages and attorney's fees (§99 Q) |
| California | [Penal Code §632](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=632.&lawCode=PEN) (confidential communications); §632.7 (cellular/cordless) | CA law applies to out-of-state recorders of calls with CA residents (*Kearney v. Salomon Smith Barney*, 39 Cal. 4th 95 (2006)) | $5,000 per violation civil ([§637.2](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=637.2.&lawCode=PEN)) |
| Delaware | [11 Del. C. §1335(a)(4)](https://delcode.delaware.gov/title11/c005/sc07/index.html) vs. [§2402(c)(4)](https://delcode.delaware.gov/title11/c024/index.html) | The two statutes conflict (privacy statute vs. one-party wiretap exception). Treat as all-party | Misdemeanor / felony |
| Florida | [§934.03](http://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0900-0999/0934/Sections/0934.03.html) | Oral communications with an expectation of privacy; all wire communications | 3rd-degree felony |
| Illinois | [720 ILCS 5/14-2](https://www.ilga.gov/documents/legislation/ilcs/documents/072000050K14-2.htm) | *Surreptitious* recording of *private* conversations (2014 amendment) | Felony; civil (14-6) |
| Maryland | [Cts. & Jud. Proc. §10-402](https://mgaleg.maryland.gov/mgawebsite/Laws/StatuteText?article=gcj&section=10-402) | All parties must consent | Felony, up to 5 yrs |
| Michigan | [MCL 750.539c](https://www.legislature.mi.gov/Laws/MCL?objectName=mcl-750-539c) | "Without the consent of all parties". *Sullivan v. Gray* (Mich. App. 1982) let participants record, so the law is contested. Treat as all-party | Felony, up to 2 yrs |
| Montana | [MCA 45-8-213](https://leg.mt.gov/bills/mca/title_0450/chapter_0080/part_0020/section_0130/0450-0080-0020-0130.html) | Without the knowledge of all parties | Misdemeanor |
| New Hampshire | [RSA 570-A:2](https://www.gencourt.state.nh.us/rsa/html/LVIII/570-A/570-A-2.htm) | All parties | Felony |
| Pennsylvania | [18 Pa.C.S. §5703](https://www.legis.state.pa.us/cfdocs/legis/LI/consCheck.cfm?txtType=HTM&ttl=18&div=0&chpt=57&sctn=3&subsctn=0) (exceptions in §5704(4)) | All parties | 3rd-degree felony |
| Washington | [RCW 9.73.030](https://app.leg.wa.gov/RCW/default.aspx?cite=9.73.030) | Private communications. Consent is satisfied if the announcement is **itself recorded** (9.73.030(3)) | Gross misdemeanor; civil |
| *Partial:* Connecticut | Civil [§52-570d](https://www.cga.ct.gov/current/pub/chap_925.htm) | Telephone calls: all-party consent, or a verbal notice that is recorded, or a beep tone. Criminal law is one-party | Civil damages |
| *Partial:* Nevada | [NRS 200.620](https://www.leg.state.nv.us/nrs/nrs-200.html) | Telephone: all-party (*Lane v. Allstate*, 114 Nev. 1176 (1998)). In person (NRS 200.650): one-party | Felony |
| *Partial:* Oregon | [ORS 165.540](https://www.oregonlegislature.gov/bills_laws/ors/ors165.html) | In-person conversations: all participants must be "specifically informed". Telephone: one-party | Misdemeanor |
| *Partial:* Missouri | [RSMo 542.402](https://revisor.mo.gov/main/OneSection.aspx?section=542.402) | RCFP reads in-person private conversations as all-party and wire as one-party. Contested | Felony |
| *Partial:* Hawaii | HRS 711-1111 | Recording devices in private places need all-party consent; otherwise one-party | Misdemeanor |

**Practical rule for the product.** Users can't know where every participant is, and the strictest applicable law tends to govern (see *Kearney*). So **design for all-party consent everywhere**: announce, then record.

**Workplace overlays for business users.** Employer electronic-monitoring notice laws:
- New York [Civ. Rights Law §52-c](https://www.nysenate.gov/legislation/laws/CVR/52-C*2)
- Connecticut [§31-48d](https://www.cga.ct.gov/current/pub/chap_557.htm)
- Delaware 19 Del. C. §705

**Outside the U.S. (brief).**
- Canada: one-party ([Criminal Code s.184(2)(a)](https://laws-lois.justice.gc.ca/eng/acts/C-46/section-184.html)).
- Germany: recording non-public speech without consent is a crime ([StGB §201](https://www.gesetze-im-internet.de/stgb/__201.html)).
- EU: [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj) applies to business use. The household exemption in Art. 2(2)(c) covers only purely personal use.

## 3. Voiceprint (biometric) law

| Law | Who it binds | Requirement | Exposure |
|---|---|---|---|
| Illinois BIPA [740 ILCS 14](https://www.ilga.gov/Legislation/ILCS/Articles?ActID=3004&ChapterID=57) | "Private entity" means **"any individual**, partnership, corporation…" (14/10), so a *user* can be liable | Before collecting a **voiceprint**: written notice of purpose and retention term, and a **written release** (an e-signature counts, per P.A. 103-769). A public retention policy; destroy within 3 yrs of last interaction (14/15) | $1,000 negligent / $5,000 intentional per person (14/20; 2024 amendment: one recovery per person) |
| Texas [Bus. & Com. Code §503.001](https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm) | Anyone capturing "for a commercial purpose" | Inform and get consent first. Destroy within 1 yr after the purpose expires | AG, up to $25,000 per violation |
| Washington [RCW 19.375](https://app.leg.wa.gov/RCW/default.aspx?cite=19.375) | Enrollment "for a commercial purpose" | Notice and consent | AG (CPA) |
| Colorado [C.R.S. §6-1-1314 (HB24-1130)](https://leg.colorado.gov/bills/hb24-1130) | Controllers of biometric identifiers | Consent, a retention policy, deletion | AG |
| GDPR Art. 9 | Non-household use | Explicit consent (Art. 9(2)(a)) | Regulators |
| EU AI Act ([Reg. 2024/1689](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)) | **Provider** (developer) | Matching meeting voices to stored profiles may be "remote biometric identification" (Art. 3(41); Annex III 1(a) high-risk). The Art. 2(10) personal-use carve-out covers deployers only | Counsel to assess before EU sales |
| FTC [Biometric Policy Statement (2023)](https://www.ftc.gov/legal-library/browse/policy-statement-federal-trade-commission-biometric-information-section-5-federal-trade-commission-act) | Developer | No misrepresentation. Assess foreseeable harms, including covert use | §5 |

**Developer position.** Voiceprints never leave the Mac, so the developer does not "collect" them. The product should still make the *user's* compliance easy, and default to not enrolling third parties.

## 4. Recommended minimal flow

The aim is the least friction that still produces **knowledge or consent by everyone**, a **visible state**, and **evidence**. Five touchpoints:

### 4.1 One-time Meetings intro (first open of Meetings, and again whenever the wording version changes)

Show it as a sheet. **Start Recording** is disabled until the checkbox is ticked.

> **Recording other people requires their consent**
>
> Murmur records your microphone and the call's audio on this Mac. People on the call **won't see any recording indicator** from their meeting app.
>
> In Massachusetts, California and many other places, recording a conversation without the consent of **everyone** in it is a crime. Participants may be in different states or countries.
>
> ☐ I'll tell everyone I'm recording before I start, and I'll stop if anyone objects.
>
> [Learn more] [Cancel] [Continue]

- Store `consentIntroVersion` and its date in `UserDefaults`.
- Don't geolocate the user to tailor this text. It would be inaccurate, because participants are elsewhere, and it would be a privacy cost.

### 4.2 Before each recording: a pre-start popover, shown when the user clicks Record or presses ⌘⇧R

> **Tell everyone you're recording**
> "Heads up, I'm recording this call for my notes. The audio stays on my computer. Let me know if you'd rather I didn't."
> [Copy to chat]  [Start recording] (Return)
> ☐ Don't show this before every recording (you must still tell people)

- Return starts recording, so this adds one keystroke.
- When the box is ticked, skip the popover but keep §4.3. Re-enable the popover automatically after 30 days, or whenever the "All system audio" source is selected.
- In `MeetingRecorderControl.toggle()`, set `meeting.consent = .init(announcedAt: nil, promptShownAt: Date())`.

### 4.3 While recording: a persistent banner, which is required

- A floating, non-activating `NSPanel`, above other windows and on all Spaces:
  `● Recording · 12:03 · [Announced ✓ / Mark announced] · [Stop]`.
- It can be dragged or collapsed to a red dot. It **cannot be hidden while recording**.
- The menu bar icon turns red.
- There is **no "stealth" or "hide indicator" setting**, now or later. This is the key design fact for the c. 272 §99, 720 ILCS 14-2(a)(4) and 18 U.S.C. §2512 analysis.
- **Mark announced** (or ⌘⇧A) timestamps `consent.announcedAt`. The announcement is in the recording, which is evidence; WA RCW 9.73.030(3) and CT §52-570d accept a recorded announcement.
- If no announcement is marked after 2 minutes, pulse the banner once: "Did you tell everyone?" Never block or auto-stop.
- macOS also shows its own orange mic indicator and the audio-capture indicator. Don't rely on those: other participants can't see them.

### 4.4 "Announce recording" helper: offer it, but keep it simple

| Option | Verdict |
|---|---|
| **Copy announcement to clipboard** for the meeting chat | **Ship.** Cheap. It leaves a written trace in the call's chat log |
| **Script shown in the banner** for the user to say aloud | **Ship.** Spoken notice is the norm, and it lands in the recording as evidence |
| Spoken TTS played into the call | **Don't build.** It needs a virtual audio device or depends on speaker-to-mic bleed, which echo cancellation often removes. It is unreliable, and it looks robotic, which reduces actual notice |
| Auto-post to Zoom/Teams chat through their APIs | Not now. OAuth scopes and maintenance burden |

### 4.5 Voice profiles of other people: separate *naming* from *remembering*

Change `MeetingDetailView.renameForm` and `Meeting.name(speaker:as:in:)`:

- **Naming a speaker only labels the transcript by default.**
- New checkbox, **off by default**: ☐ *Remember {Name}'s voice for future meetings*.
- The first time it is ticked, show this:

> **Save a voiceprint of {Name}?**
> Murmur will store a numeric voice fingerprint (no audio) on this Mac so it can recognize {Name} in future meetings. Voiceprints are biometric data. In some places (for example Illinois) you need {Name}'s **written** consent first.
> ☐ {Name} agreed to have their voice remembered.
> [Copy consent request] [Cancel] [Save voice]

- **Copy consent request** text: "Can I save a voice profile of you in my meeting-notes app? It stays on my Mac, is used only to label who said what in my notes, and I'll delete it when we stop meeting or whenever you ask. Reply 'yes' to agree." An emailed "yes" is a plausible BIPA e-signature written release. Counsel to confirm.
- Store `consentAttestedAt` and `lastMatchedAt` on `VoiceProfile`.
- **Retention:**
  - Auto-delete profiles not matched for **12 months**, after a warning. That is under Texas's 1-yr rule and BIPA's 3-yr rule.
  - Add a **Delete all voice profiles** button.
  - Add a one-line retention notice in VoiceProfilesView.
- Matching against *existing* profiles during diarization is fine. It only applies profiles the user already created with attestation.
- **Exception:** the local mic speaker is the user, and no prompt is needed for their own voice.

### 4.6 Cloud summaries of meetings

- The first time a meeting transcript is routed to a cloud provider, show this once per provider:
  > "This sends the meeting transcript, including what other people said, to {Provider}. Only do this if participants are OK with it." [Use on-device] [Send to {Provider}]
- In the meeting detail view, add a per-meeting "Summarize on-device only" toggle.

## 5. Copy fixes elsewhere (FTC §5 / 93A accuracy)

- `Info.plist` `NSSpeechRecognitionUsageDescription` says "Nothing is sent to Apple or anyone else." Change it to: "Speech is transcribed on this Mac. Transcripts leave it only if you turn on a cloud AI provider."
- `NSAudioCaptureUsageDescription`: append "Tell everyone on the call before you record."
- README and PRIVACY.md: keep the "Tell people when you record a meeting" line, and link to this flow.

## 6. Don'ts

- No auto-start recording on call detection.
- No hidden or minimized-to-nothing indicator.
- No silent enrollment of third-party voiceprints.
- No in-app statements that a recording is "legal" or "compliant".
- No sharing or export of voiceprints.

## 7. Implementation map

| Change | File |
|---|---|
| Intro sheet, pre-start popover, consent fields | `MeetingKit/Sources/MeetingUI/MeetingRecorderControl.swift`, `MeetingKit/Sources/MeetingKit/Meeting.swift` (add `consent`) |
| Persistent banner panel | new `MeetingUI/RecordingBanner.swift`; reuse `RecordingIndicator` in `MeetingUI/Components.swift` |
| Name ≠ enroll; attestation sheet | `MeetingUI/MeetingDetailView.swift`, `Meeting.name(speaker:as:in:)` (add `remember: Bool`) |
| Retention, attestation and match dates; Delete all | `MeetingKit/VoiceProfileStore.swift`, `MeetingUI/VoiceProfilesView.swift` |
| Cloud-summary notice | `Murmur/Sources/MurmurUI/Views/MeetingsView.swift`, `AIKit/Tasks.swift` caller |
| Tests | `MeetingKitTests/VoiceProfileTests.swift`: renaming without `remember` must not enroll, and expired profiles must be purged |
