# 01 - Massachusetts Wiretap Act (G.L. c. 272, s. 99) and the Humanity Meetings feature

Prepared 2026-10-01. Research analyst notes, not legal advice. Nothing here says the product is "compliant" or "safe". Items marked **[UNVERIFIED]** were not confirmed against a primary source in this pass. Where I could only read a secondary summary of an opinion, I say so.

## 0. Bottom line

1. **Who is the primary target.** The Meetings user, not the developer. The user starts a recording of a Zoom or other call that includes people who may not know. Massachusetts treats a *participant* who secretly records as an "interceptor". The statute is all-party consent in effect, but its text turns on "secretly" and "prior authority by all parties" (see s. 2).
2. **Highest-risk fact pattern.** Meetings captures a remote app's audio locally, so the platform's own "this meeting is being recorded" banner never fires. The only visible cue is on the user's own screen. After *Commonwealth v. Du* (2024), "they could have seen it" is not enough; actual knowledge is required.
3. **Vendor exposure is real but second-order.** The statute reaches anyone who "aid[s] another to secretly record" (s. 99B(4)), "procures" an interception (C(1)), or is an accessory or conspirator (C(6)). It also gives a civil action against "any person who so intercepts" (Q). Exposure rises sharply with covert-use marketing or features, and falls with real notice and consent design. I found no Massachusetts decision holding a general-purpose recorder vendor liable under these clauses **[UNVERIFIED: search was not exhaustive]**.
4. **Premise correction.** s. 99 as currently published does **not** contain a manufacture or sale ban on "intercepting devices". I searched the full statute text for "manufacture" and found nothing. C(5) bans only possession, and permitting use of a device, in the circumstances described in s. 5. The manufacture and sale ban is **federal**: 18 U.S.C. 2512 (see s. 5).
5. **Individual developer, no entity.** Any liability would fall on the developer personally. Statutory damages are per aggrieved person and class-action-shaped (see s. 4). Attorney review is warranted before wide release of Meetings.

## 1. Statute: what it actually says (read in full on malegislature.gov, 2026-10-01)

Source: https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99

| Provision | Text / effect | Product relevance |
|---|---|---|
| B(1) wire communication | Any communication made "in whole or in part through the use of facilities for the transmission of communications by the aid of wire, cable, or other like connection between the point of origin and the point of reception." | A Zoom, Teams or Meet call travels over cable and internet facilities. Likely a wire communication. *Moody* (below) read the term broadly (cell calls and texts). |
| B(2) oral communication | "speech, except such speech as is transmitted over the public air waves by radio." | Covers the user's mic capture of in-room speech. Note there is **no reasonable-expectation-of-privacy requirement** in the text. |
| B(3) intercepting device | "any device or apparatus which is capable of transmitting, receiving, amplifying, or recording a wire or oral communication", with carve-outs for hearing aids and carrier equipment. | A Mac running Murmur is a recording-capable device. Whether *software* is itself a "device or apparatus" is unlitigated as far as I found **[UNVERIFIED]**. |
| B(4) interception | "to secretly hear, secretly record, or **aid another to secretly hear or secretly record** the contents of any wire or oral communication through the use of any intercepting device by any person **other than a person given prior authority by all parties** to such communication." | Core element. "Secretly" plus "prior authority by all parties". The aid-another language is what puts a vendor in play. |
| B(5) contents | Includes "the identity of the parties to such communication" and "the existence, contents, substance, purport, or meaning". | Speaker labels and voice-profile names are arguably "contents". Relevant to disclosure and use (C(3)). |
| B(6) aggrieved person | A party to the communication, or anyone with "standing to complain that his personal or property interest or privacy was invaded". | Every non-consenting participant has standing. |
| C(1) | Whoever "willfully commits an interception, attempts to commit an interception, or **procures any other person** to commit an interception": fine up to $10,000 and/or state prison up to 5 years, or jail up to 2.5 years. "Proof of the installation of any intercepting device ... under circumstances evincing an intent to commit an interception ... shall be prima facie evidence." | Felony. "Procures" is the vendor hook. Willfulness is required for the criminal count. |
| C(3) | Willful disclosure or use of contents "knowing that the information was obtained through interception": misdemeanor, up to 2 years or $5,000. | A user who shares a transcript (or sends it through AIKit to an LLM) after an unlawful capture is exposed here. |
| C(5) | Possession of an intercepting device "under circumstances evincing an intent to commit an interception not permitted", or **permitting** a device "to be used or employed" for a non-permitted interception, or possessing it "knowing that the same is intended to be used" for one: misdemeanor, up to 2 years or $5,000. | This is the only "device" offense. It has no manufacture or sale element. It requires intent or knowledge about unlawful use. |
| C(6) | One who "permits or on behalf of any other person commits", a conspirator, or "any accessory" to C(1)-(5) is punished the same way. | Second vendor hook. Needs real participation or knowledge, not mere product availability. |
| D | Exemptions: carriers, office intercom systems, law enforcement under warrant, etc. | None apply to a consumer app. The "office intercommunication system" exemption (D(1)(b)) is **not** a safe harbor for a recorder. |
| Q | Civil action by any aggrieved person against "any person who so intercepts, discloses or uses such communications". Recovery: (1) actual damages, but not less than liquidated damages "computed at the rate of $100 per day for each day of violation or $1000, whichever is higher"; (2) punitive damages; (3) reasonable attorney's fee and litigation disbursements. Only listed defense: good-faith reliance on a warrant. | No express consent or good-faith defense for private actors. Fee-shifting plus a $1,000 floor per plaintiff gives plaintiff-side incentive. |

No s. 99 text found on: criminal or civil limitations period, express exclusion of unlawfully recorded material from civil cases, or sale or manufacture. A civil limitations period is not stated in s. 99; courts may borrow a general tort period **[UNVERIFIED]**.

## 2. All-party consent and the "secretly" element

**Textual rule.** An interception requires (a) secret recording, (b) by someone not given "prior authority by all parties". Massachusetts courts have read "secretly" as the operative filter, so that a recording made with actual knowledge of the speaker is not an interception even if no one said "yes".

| Authority | What it holds (as I understand it) | Verification status |
|---|---|---|
| *Commonwealth v. Jackson*, 370 Mass. 502 (1976) | A recording is "secret" when made without the **actual knowledge** of the person recorded. Actual knowledge may be shown by "clear and unequivocal objective manifestations of knowledge". Not limited to situations with a reasonable expectation of privacy. | Secondary summaries only (e.g. https://law.justia.com/cases/massachusetts/supreme-court/1976/370-mass-502-2.html, page blocked to my fetcher). |
| *Commonwealth v. Hyde*, 434 Mass. 594 (2001) | Private citizen who tape-recorded police at a traffic stop violated s. 99. No exception for a private party or for recording officials. Legislature intended to bar secret recording by the public, not only by the government. A participant who records secretly is an interceptor. | Secondary summaries; opinion at https://law.justia.com/cases/massachusetts/supreme-court/volumes/434/434mass594.html (403 to fetcher). |
| *Commonwealth v. Moody*, 466 Mass. 196 (2013) | Reads "wire communication" broadly: covers cell-phone calls and text messages. Supports treating VoIP or app-mediated audio as wire communication. (Application to VoIP is my inference.) | Secondary summaries; https://law.justia.com/cases/massachusetts/supreme-court/2013/sjc-11277.html. **Treat the VoIP point as [UNVERIFIED].** |
| *Project Veritas Action Fund v. Rollins*, 982 F.3d 813 (1st Cir. 2020) | s. 99 violates the First Amendment **only as applied** to secret audio recording of government officials performing duties in public spaces. Court left in place the ban as applied to private conversations and where privacy expectations exist. Vacated on ripeness a broader challenge for people without privacy expectations. | Read via FindLaw summary: https://caselaw.findlaw.com/court/us-1st-circuit/2101863.html. Not read in full. **Gives no cover to private meetings.** Whether the vacated claim was later litigated: **[UNVERIFIED]**. |
| *Commonwealth v. Du*, 495 Mass. 103 (SJC Nov. 27, 2024), affirming 103 Mass. App. Ct. 469 (2023) | Undercover officer used the Callyo app to record drug buys (audio plus video). "Secretly" means lack of actual knowledge. SJC rejected the Commonwealth's attempt to redefine it as "could have known"; a visible phone did not make the recording non-secret. Suppressed the audio **and** the video. | Via Commonwealth Beacon summary https://commonwealthbeacon.org/courts/sjc-tosses-warrantless-secret-video-recording/ and Boston Bar summary https://bostonbar.org/journal/privacy-and-federalism-the-supreme-judicial-court-clarifies-the-scope-of-the-wiretap-act/. Opinion text not read (403). |
| *Vita v. New England Baptist Hospital*, SJC-13542 (Oct. 24, 2024), cite believed 494 Mass. 824 **[cite UNVERIFIED]** | Website browsing and tracking is not clearly a "communication" under s. 99 (rule of lenity). The Act protects **person-to-person** conversations and messages. | FindLaw summary https://caselaw.findlaw.com/court/ma-supreme-judicial-court/116650802.html. Helps vendors of analytics tools. **Does not help here**: a live call between people is exactly the core case. |
| *Commonwealth v. Grimaldi*, SJC-13842 (June 2, 2026) | Suppression under s. 99 needs a **willful** interception. Willfulness "requires not merely an intent to record, but rather an intent to secretly record." Open body-cam use with a large warning sign, lights and a visible camera was not willful even if the defendant never saw the sign. Court did **not** decide whether the recording was actually secret, and did not disturb *Du*. | Only secondary sources (Justia listing https://law.justia.com/cases/massachusetts/supreme-court/2026/sjc-13842.html; SerpaLaw https://www.serpalaw.com/boston-criminal-law-updates/commonwealth-v-grimaldi-sjc-checkpoint-bodycam-recordings/). Opinion not read. **Newest and most useful case**: documented notice efforts defeat the *willful* element for the criminal and suppression side. Whether willfulness is required for a s. 99Q civil claim is **not addressed in anything I read** (Q's text has no "willful"). Flag for counsel. |

**Practical reading of "prior authority" versus "actual knowledge".** Express prior agreement of all parties is clean. Actual knowledge without objection has been accepted, but only on "clear and unequivocal objective manifestations" (*Jackson*). The user's on-screen "recording" icon does not show others' knowledge (*Du*). An announcement at the start of the call, heard by everyone, followed by continued participation, is the strongest non-express form. It is still fact-dependent (late joiners, people on mute or listening only, people dialed in by phone, transcription bots).

**What counts as "recording".** Real-time transcription that discards audio is probably still "record" in the ordinary sense, but I did not verify case law on ephemeral or streaming capture **[UNVERIFIED]**. Do not rely on "we don't keep audio" (and Meetings does keep audio per PRIVACY.md).

## 3. 2024-2026 developments (checked 2026-10-01)

| Date | Item | Why it matters | Source |
|---|---|---|---|
| 2024-10-24 | *Vita* | Narrows scope to person-to-person communications. Calls remain covered. | link above |
| 2024-11-27 | *Du* | Actual knowledge required; no "could have known" test; audio and video both suppressed. | links above |
| 2025-2026 | Legislature: S.1215 (194th General Court) would add a defense for recording threats, harassment or crimes in some family-law contexts. Reported favorably and sent to Senate Ways and Means (Oct. 9, 2025). | Narrow. Would not change the meeting-recording analysis. Status after that date **[UNVERIFIED]**. | https://malegislature.gov/Bills/194/S1215 |
| 2025 | *Belkounis v. Fardy* (Mass. App. Ct. oral argument, secretly recorded audio in a civil trial) | Commentary says s. 99 is silent on civil-case exclusion. Outcome unknown. | via citizenportal.ai summary; **[UNVERIFIED]**; low priority |
| 2026-06-02 | *Grimaldi* | See table above. | links above |
| 2025-08 to 2026-08 | *In re Otter.AI Privacy Litigation*, No. 5:25-cv-06911 (N.D. Cal.) (consolidated Oct. 22, 2025; Judge Lee). Reported Aug. 13, 2026 order: federal wiretap, CIPA and Illinois BIPA voiceprint claims survive dismissal; Otter plausibly a "third-party eavesdropper" because it "independently collects, retains, and uses communications for its own commercial purposes". Computer hacking counts dismissed. | Closest real-world analog to a meeting-recording vendor. The "own commercial purposes" reasoning is the distinguishing factor: Humanity runs no servers and receives no data. Not a Massachusetts case. | Reported by https://thelittlebinger.com/ai-notetaker-lawsuits-otter-granola-employer-consent-risk/ (single secondary source, **[UNVERIFIED]**; pull the docket) |
| 2026-07-30 | *Chamberlain v. Granola, Inc.*, 3:26-cv-07926 (N.D. Cal.), filed | Another notetaker suit; allegations incl. silent capture of non-consenting participants. | same article; **[UNVERIFIED]** |

I found **no** 2025-2026 Massachusetts appellate decision applying s. 99Q to a software vendor, and no amendment to s. 99's text. Statute page showed no recent amendment notation, but I did not check the session-laws history **[UNVERIFIED]**.

## 4. Civil remedy (s. 99Q) and exposure math

- **Plaintiffs.** Any "aggrieved person": a party to the call or anyone whose privacy was invaded. In Meetings, each non-informed participant is a separate plaintiff.
- **Damages.** The greater of actual damages or liquidated damages of $100/day of violation or $1,000, plus punitive damages and fees. The $1,000 floor applies per aggrieved person per violation. "Each day of violation" for a single call is unsettled **[UNVERIFIED]**. A weekly recurring meeting with 8 uninformed participants is 8 plaintiffs, many recordings.
- **Fee shifting** makes small claims economically viable, and class counsel are active against notetakers (Otter, Granola).
- **Defendants.** Q says "any person who so intercepts, discloses or uses". Because B(4) defines interception to include "aid another to secretly record", a plaintiff can plead vendor liability. Elements a plaintiff would need: (i) the underlying interception was secret, (ii) vendor "aided" it, and likely (iii) knowledge or purpose, given C(6) "accessory" language and the criminal willfulness requirement (*Grimaldi*). Whether (iii) is required in a civil claim against an aider is **unresolved in anything I found**.
- **Individual developer.** No entity, so personal assets are exposed. An LLC does not shield a person from liability for their own conduct, but it helps for contracts, insurance and optics. Counsel should advise.

## 5. Can a software vendor be liable?

### 5a. Massachusetts: "aid", "procure", accessory

| Fact | Pushes toward liability | Pushes away |
|---|---|---|
| Developer does not hear, record, store or receive anything. | | Strongly helpful. No operator role, unlike a hosted notetaker. |
| Software is general-purpose, works for dictation, notes and consenting meetings. | | Helpful (dual use). |
| In-app text already says to tell everyone (MeetingRecorderControl.swift, PRIVACY.md). | | Evidence of intent not to enable secret recording. |
| Source and binaries are public (MIT). | | Open, not hidden. But MIT disclaimer does not bind third-party plaintiffs. |
| No consent gate, no prompt per meeting, indicator only inside the user's own UI. | Yes: product makes covert capture easy and friction-free. | |
| Capture bypasses platform recording banners (process tap / ScreenCaptureKit on a remote app). | Yes: plaintiff will argue the feature set is the means of avoiding disclosure. | |
| Any marketing for "invisible", "undetectable", "no one will know", "bot-free so nobody notices". | Yes, very strong. Cf. *Luis v. Zang* below. | |
| Support replies that coach users on avoiding detection. | Yes. | |
| Voice profiles of named non-users stored. | Adds identity-of-party "contents" and biometric issues. | Local only. |

**Assessment.** On current facts, an aiding claim against the developer is a *plausible-to-plead, hard-to-win* theory, mostly because the vendor lacks the "secret" intent *Grimaldi* now emphasizes for willfulness. The theory gets materially stronger if features or marketing are oriented toward covert use. Treat as **medium-low** today, **high** with stealth features or covert marketing. This is a judgment call for counsel, not a finding.

### 5b. "Device manufacture/sale" (the brief's s. 99C question)

- **s. 99 has no manufacture or sale offense.** I read C(1)-(6): only interception, edit or tamper, disclosure or use, disclosure of warrant materials, **possession or permitting use**, and accessory.
- **C(5) possession** requires (i) possession "under circumstances evincing an intent to commit an interception not permitted", (ii) permitting a device to be used for a non-permitted interception, or (iii) possession knowing it is intended for one. A vendor distributing a free DMG to unknown users does not "possess" users' devices. Clause (ii) ("permits an intercepting device to be used") is aimed at the person with control of the device. Stretching it to a remote vendor looks unlikely but is untested **[UNVERIFIED]**.
- **Federal analog: 18 U.S.C. 2512(1)** bans knowingly sending through mail or interstate commerce, manufacturing, assembling, possessing, or selling a device where the person "knows or has reason to know that the design of such device renders it primarily useful for the purpose of the surreptitious interception" of communications, and advertising such devices. Up to 5 years. Source: https://www.law.cornell.edu/uscode/text/18/2512 (summary read; quote the exact text before relying).
- *Luis v. Zang*, 833 F.3d 619 (6th Cir. 2016): Court let a 2512 and civil-liability theory proceed against the maker of WebWatcher, spyware marketed for covert monitoring; marketing materials weighed heavily. Not binding in the 1st Circuit. See https://www.courtlistener.com/opinion/4248169/javier-luis-v-joseph-zang/ (secondary summary read; opinion not read).
- **Application.** A general meeting recorder that visibly announces itself is not "primarily useful" for *surreptitious* interception. The product moves toward that line only if it adds stealth modes, hides indicators, or advertises covert use. Also note possible fit for the 2512(2) service-provider exemption is irrelevant to Humanity.

### 5c. Federal civil exposure

18 U.S.C. 2520 gives a civil action to "any person whose wire, oral, or electronic communication is intercepted, disclosed, or intentionally used in violation of this chapter": greater of actual damages plus profits, or the greater of $100/day or $10,000; punitive damages; fees. 2-year limitation from reasonable opportunity to discover. Source: https://www.law.cornell.edu/uscode/text/18/2520. This is where *Otter*-style claims sit. Federal exposure requires that the interception be unlawful under federal law (see s. 6).

## 6. Federal baseline and remote participants

- **Federal one-party rule.** 18 U.S.C. 2511(2)(d): not unlawful for a person not acting under color of law to intercept where "such person is a party to the communication or where one of the parties ... has given prior consent", **unless** intercepted "for the purpose of committing any criminal or tortious act". 2511(1)(a) also reaches one who "procures any other person to intercept". Source: https://www.law.cornell.edu/uscode/text/18/2511.
- **Does not preempt stricter state law** (ECPA sets a floor). Massachusetts, California, Florida, Illinois, Maryland, Washington and others impose all-party rules **[UNVERIFIED as a list; see companion research files]**. A user who is a party to the call is *federally* fine unless an exception applies, but the state claim is where the damages are.
- **Tortious-purpose exception.** Recording to commit a tort (e.g. harassment, or later using content in violation of law) can defeat one-party consent federally. Not the core risk here.
- **Remote participants in other states.** The calls Meetings records are often multi-state. No single rule: courts in one-party/all-party conflicts commonly apply a functional or interest-based choice-of-law analysis. A Massachusetts Appeals Court case (*Christensen v. Cox*, 2018-P-0567, via Mass. SJC docket SJC-12647) reportedly addressed this for s. 99 and criticized a trial court for assuming the Act could not apply to out-of-state conduct, citing the Massachusetts functional test (*Bushkin Assocs. v. Raytheon Co.*, 393 Mass. 622 (1985) **[cite UNVERIFIED]**). I could not read it; the only access was a blocked mass.gov PDF. **[UNVERIFIED]**.
- **Practical rule for the product:** the user is in Massachusetts or elsewhere, and the *other* participants may be in any state. Treat the **strictest** regime among all participants as controlling. Do not build jurisdiction-sniffing into the product; it cannot know where participants are. A universal "everyone must know" posture is simpler and cheaper than any state-specific carve-out.
- **California** (outside this file's scope but the largest class-action venue): *Otter* claims plead Penal Code 631 and 637.2 **[UNVERIFIED]**; see companion file for CIPA.

## 7. Applicability to THIS product (summary)

| Product feature | s. 99 relevance |
|---|---|
| Murmur dictation (user's own voice) | No third-party communication. Low relevance. |
| Voice notes (user's own voice, audio saved) | Same, except when others' speech is audible in the room; user's responsibility, low vendor exposure. |
| **Meetings: mic + other app's audio** | Core. Wire communication plus oral communication. Captures both sides, bypasses platform banner. |
| **Voice profiles (voiceprints of named people, including non-users)** | Identity of parties = "contents" (B(5)). Separate biometric statutes apply; see companion file(s). Do not store a voiceprint for someone who did not agree (or at minimum surface a warning). |
| **AIKit (user's own key sends transcript text to third-party LLM)** | A "disclosure" of contents by the user (C(3)) if the capture was unlawful. Vendor never receives the text. Warn users. |
| LicenseKit and Gumroad | Not related. |
| Developer servers | None. Strongly differentiates from *Otter* ("independent collection and use" for commercial purposes). |
| OculOS, ManOS | Not communications. Out of scope here. |

## 8. Recommended safeguards (concrete)

**Principle:** make an open, noticed recording the path of least resistance and a covert one impossible to do accidentally. Document that design. Under *Grimaldi*, documented notice efforts are the strongest evidence of no intent to record secretly.

### 8a. Consent UX (Meetings)

1. **Pre-start gate every time** (not just first run). Before the first recording of each meeting: modal with checkbox "I have told everyone on this call that it will be recorded, and they have agreed or stayed on the call after being told" plus a button "Copy notice to clipboard". **Block Start** until checked. Do not allow "don't ask again" in v1.
2. **Notice script** supplied in-app (user pastes into meeting chat or says aloud), e.g.: "I'm recording and transcribing this meeting on my computer so I can take notes. Please say now if you object." Include a short variant for audio-only calls and one for later joiners.
3. **Late joiner prompt.** If the selected call app's audio activity suggests a new participant (not reliably detectable), show a timed reminder every N minutes: "Anyone new? Tell them you're recording." Minimum: a reminder at 10 minutes and on any pause and resume.
4. **Persistent, visible indicator** while recording: menu-bar item (red) and an always-on-top mini badge, not only the popover in `MeetingRecorderControl.swift`. No setting that hides it.
5. **No auto-start.** Do not add calendar-triggered or app-triggered auto-record. If ever added, require a per-event confirmation. No "stealth" or "silent" mode.
6. **Consent log.** Write to meeting metadata: timestamp of attestation, notice text version shown. Show it in the transcript header ("Recording notice confirmed 10:02"). Helps the user and shows vendor intent.
7. **Objection path.** One-click "Someone objected: stop and delete" that stops capture and deletes audio and transcript for that meeting, with a confirmation.
8. **Recording-law explainer sheet.** Neutral text: "Massachusetts and about a dozen other states require every participant to know about a recording. Federal law alone would only require you to be a party. When participants are in different states, assume the strictest rule." Do not give state lists you have not verified.

### 8b. Defaults

- Meetings off until the user enables it in Settings and accepts the attestation terms.
- Voice-profile enrollment **off by default** for non-users. Creating a profile requires "this person has agreed that I may store their voiceprint" plus a way to delete. (Biometric statutes may demand more; see companion file.)
- AIKit transcript send **off** for meetings by default; first send requires re-attestation and shows which provider receives the text.
- Retention: default to deleting call audio after transcription unless the user opts to keep it; shorter default retention reduces exposure on any later disclosure.
- No analytics, no cloud sync, keep current no-server design. Keep saying so; it is a key distinguishing fact from *Otter*.

### 8c. Notice and docs

- `PRIVACY.md` line "Tell people when you record a meeting, and follow your local consent laws" should become a clear rule: **recording without telling and getting agreement from every participant may be a crime and expose you to civil damages in Massachusetts and other states**. Link the in-app explainer.
- README and Gumroad page: add a short "Responsible use" paragraph near Meetings. **Do not** use "invisible", "undetectable", "bot-free so nobody knows", "record any call". Acceptable: "records your meetings locally; you tell participants".
- Support macros: refuse to coach on hiding recording; point to the notice script.

### 8d. Terms language (for counsel to review)

Sketch only:
- **Use covenant:** "You may use Meetings only to record communications where every participant has been informed and has consented or the recording is otherwise lawful. You are solely responsible for determining and obeying the recording, wiretap, biometric and privacy laws that apply to you and to each participant. You must not use the software to secretly record anyone."
- **Prohibited use:** secret or covert recording; recording where any participant has objected; creating voiceprints without consent.
- **Warranty and indemnity:** user represents they will give notice and obtain consent; indemnifies developer for claims arising from user's recordings (enforceability against an individual consumer is limited; counsel to advise).
- **No legal advice, no state-law guarantee.**
- **Termination** right for misuse.
- **Acknowledgement click** at purchase or first launch (Gumroad license screen is not enough; use in-app clickwrap). Note: Terms do not bind third-party plaintiffs and are not a defense. Their value is evidence of intent and a basis for revoking keys.

## 9. Attorney-review flags

1. Massachusetts counsel: whether a s. 99Q civil claim requires willfulness (post-*Grimaldi*) and whether "aid another" liability requires knowledge or purpose.
2. Whether software (rather than hardware) is an "intercepting device" or "apparatus", and the reach of C(5) "permits".
3. Whether VoIP or Zoom audio is a "wire communication" under *Moody* (likely yes; confirm).
4. Whether continued participation after an announcement is "actual knowledge" under *Jackson*, *Hyde*, *Du* for late-joiners and muted participants.
5. Federal 2512: "primarily useful for surreptitious interception" analysis of the product plus marketing; *Luis v. Zang* is out-of-circuit.
6. Choice of law for multi-state calls: confirm *Christensen v. Cox* holding and Massachusetts functional test.
7. Entity formation, insurance (cyber or media liability), and indemnity enforceability for an individual developer.
8. Biometric laws for voiceprints of non-users (Illinois BIPA appears in *Otter*). Coordinate with the biometric research file.
9. Whether the MIT license and public source change vendor analysis (no change expected, but ask).

## 10. Sources verified (2026-10-01)

Status key: **READ** = primary text read in full by me; **SUMMARY** = secondary/summarized access only; **BLOCKED** = primary opinion page returned 403 or empty to my fetcher.

| Source | URL | Status |
|---|---|---|
| G.L. c. 272, s. 99 (full text) | https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99 | **READ** (full text downloaded, searched for "manufacture" and "sale": none) |
| 18 U.S.C. 2511 | https://www.law.cornell.edu/uscode/text/18/2511 | SUMMARY |
| 18 U.S.C. 2512 | https://www.law.cornell.edu/uscode/text/18/2512 | SUMMARY |
| 18 U.S.C. 2520 | https://www.law.cornell.edu/uscode/text/18/2520 | SUMMARY |
| *Project Veritas v. Rollins* | https://caselaw.findlaw.com/court/us-1st-circuit/2101863.html | SUMMARY (CourtListener copy empty) |
| *Vita v. NEBH* | https://caselaw.findlaw.com/court/ma-supreme-judicial-court/116650802.html ; https://law.justia.com/cases/massachusetts/supreme-court/2024/sjc-13542.html | SUMMARY / BLOCKED |
| *Commonwealth v. Du* | https://commonwealthbeacon.org/courts/sjc-tosses-warrantless-secret-video-recording/ ; https://law.justia.com/cases/massachusetts/supreme-court/2024/sjc-13557.html | SUMMARY / BLOCKED |
| *Commonwealth v. Grimaldi* | https://law.justia.com/cases/massachusetts/supreme-court/2026/sjc-13842.html ; https://www.serpalaw.com/boston-criminal-law-updates/commonwealth-v-grimaldi-sjc-checkpoint-bodycam-recordings/ | SUMMARY only |
| *Hyde*, *Moody*, *Jackson* | Justia pages listed in s. 2 | BLOCKED; relied on search summaries |
| *Luis v. Zang* | https://www.courtlistener.com/opinion/4248169/javier-luis-v-joseph-zang/ | SUMMARY |
| *In re Otter.AI*, *Chamberlain v. Granola* | https://thelittlebinger.com/ai-notetaker-lawsuits-otter-granola-employer-consent-risk/ | SUMMARY, single source |
| S.1215 (194th GC) | https://malegislature.gov/Bills/194/S1215 | search listing only |
| *Christensen v. Cox* choice of law | https://www.mass.gov/doc/matthew-q-christensen-et-al-v-shawn-e-cox-sjc-12647/download | BLOCKED |

**Not done:** read any opinion in full (blocked sites); verify reporter cites for *Vita*, *Bushkin*; check session-laws for 2025-2026 amendments; confirm all-party-state list; search for vendor-liability cases exhaustively. Local product facts: README.md, PRIVACY.md and `MeetingKit/Sources/MeetingUI/MeetingRecorderControl.swift` (current on-screen reminder only, no consent gate, in-popover indicator).
