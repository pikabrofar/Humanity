# 03 - Illinois Biometric Information Privacy Act (740 ILCS 14) and Humanity

Research analyst notes, not legal advice. Prepared 2026-10-01. Nothing here says the product is "compliant" or "safe". Every claim has a source in the list at the end. Items tagged **[UNVERIFIED]** rest only on secondary sources or my memory.

## 0. Bottom line

1. **Strongest point for the developer.** On 2026-08-07 the Seventh Circuit decided *G.T. v. Samsung* (No. 25-1120). It held that a company does not "possess", "collect" or "capture" biometric data merely by shipping software that creates it on the user's device. The company must have some control over the data. This follows *Barnett v. Apple* (Ill. App. 2022) and *Bhavilai v. Microsoft* (N.D. Ill. 2024). It binds federal courts in IL, IN and WI, and is persuasive in Illinois state court. It is not an Illinois Supreme Court ruling. [S9, S10, S11]
2. **It is a pleading-stage holding with stated limits.** Liability is still possible if the developer transmits the data, keeps remote access, or modifies or uses it. A summary says the opinion expressly does not hold that on-device templates fall outside BIPA **[UNVERIFIED: secondary only; I could not read the opinion, see section 9]**. *Hazlitt v. Apple* (S.D. Ill.) found possession adequately alleged where users could not delete the data or turn the feature off and only Apple controlled it. [S12, S13]
3. **Humanity's architecture is close to the Samsung and Barnett fact pattern.** The developer runs no servers, receives no data, and the only network calls are Gumroad license checks and the user's own AI-provider calls, which carry text only. My read is that BIPA's duties are unlikely to attach to the developer as author of the software. That conclusion depends on the facts staying true and on no court extending *Hazlitt*'s logic to a developer who controls the feature.
4. **Residual risk is highest in Meetings voice profiles.** They are the one feature where the product's user (not the developer) creates a named, identifying voiceprint of non-consenting third parties. Section 5 covers this. Recent suits against AI meeting-note vendors (Otter.ai, Fireflies) show plaintiffs are actively targeting this. Those vendors do hold the data on their servers, so they differ from Humanity on the key fact. [S14-S17]
5. **BIPA is a private-right-of-action statute with fee shifting.** Defense costs matter even if the merits are favorable. Statutory damages are $1,000 negligent and $5,000 intentional or reckless per violation, plus attorneys' fees. [S3]

## 1. Statute: key definitions (740 ILCS 14/10, as amended by P.A. 103-769)

| Term | Text (verbatim, quoted from ILGA) | Notes |
|---|---|---|
| Biometric identifier | "a retina or iris scan, fingerprint, voiceprint, or scan of hand or face geometry" | Excludes writing samples, signatures, **photographs**, demographic data, physical descriptions "such as height, weight, hair color, or eye color"; also health-care/HIPAA and medical-imaging carve-outs. [S1] |
| Biometric information | "any information, regardless of how it is captured, converted, stored, or shared, based on an individual's biometric identifier used to identify an individual" | The "used to identify" clause is in the text. Derived data (embeddings) is covered if used to identify. [S1] |
| Private entity | "any individual, partnership, corporation, limited liability company, association, or other group, however organized" | Includes **individuals**. A sole proprietor with no LLC is a "private entity", so there is no shell protection. Excludes state and local government. [S1] |
| Written release | "informed written consent, electronic signature, or, in the context of employment, a release executed by an employee as a condition of employment" | Electronic signature added 2024. [S1] |
| Electronic signature | "an electronic sound, symbol, or process attached to or logically associated with a record and executed or adopted by a person with the intent to sign the record" | A click-through can qualify if designed to show intent to sign. [S1] |

### 1.1 Voiceprint

- The statute does not define "voiceprint". Courts apply the ordinary meaning of a speaker-specific acoustic signature that can identify a person.
- *Carpenter v. McDonald's Corp.*, 580 F. Supp. 3d 881 (N.D. Ill. 2022): voice-assistant technology that "could be used for identification" was plausibly a voiceprint **[UNVERIFIED cite; per FPF summary]**. [S18]
- *Gunderson v. Amazon.com* (N.D. Ill., No. 1:19-cv-05061): on 2025-11-06 the court certified a class of Illinois persons for whom Amazon "created a voiceprint". It treated Alexa voice-ID profiles as at-issue voiceprints. [S19]
- **Identification requirement.** *Martell v. X Corp.* (N.D. Ill. June 13, 2024) held a scan must be capable of identifying an individual to be a biometric identifier. *Zellmer v. Meta*, 104 F.4th 1117 (9th Cir. 2024), held Meta's "face signature" was not a biometric identifier or information because it could not identify anyone. [S20, S21]
  - **Application:** Humanity's voice profile is the opposite of Zellmer's facts. It stores a name plus up to 20 WeSpeaker 256-d embeddings per person, compared by cosine similarity so that the app can label "Alice" in later meetings (MeetingKit/README.md; `VoiceProfileStore`). That is purpose-built to identify. The "cannot identify" defense is weak here. PRIVACY.md and MeetingKit/README.md already call these "biometric" or "biometric-like".
  - The README argument that embeddings "can't be turned back into audio" mirrors Meta's argument in Zellmer, but there it succeeded because the embedding could not identify. Here identification is the feature.

### 1.2 Face geometry, eye tracking, iris data (OculOS, ManOS)

- No Illinois court has decided whether eye tracking or gaze data alone is a biometric identifier. FPF reports that Illinois courts "have not analyzed" whether eye tracking without facial analysis qualifies. [S22]
- Statutory text: "retina or iris scan" is covered. "Eye color" is expressly excluded as a physical description. Gaze coordinates (where on screen the user looks) are neither a scan of the iris, a scan of the retina, nor face geometry in any ordinary reading **[my analysis, no authority found]**.
- OculOS's inputs per its README: Vision's 76-point face landmarks, a dark-blob pupil centroid, eye-corner-relative features, and 10x6 grayscale eye patches stored in calibration. Risk points:
  - Face landmarks could be argued to be "scan of face geometry". Defenses: not used to identify anyone (*Martell*, *Zellmer*), and processing is on-device (*G.T.*, *Barnett*).
  - A 10x6 grayscale patch is not an iris scan in any technical sense (too low resolution to match an iris) **[my analysis]**. A plaintiff could still call it a "scan of the eye region". It is stored in OculOS/ on the user's Mac only.
  - Optional heatmap **screenshots** could contain third-party faces or screens. Photographs are excluded from "biometric identifier", so this is low risk under BIPA, but other laws may apply.
- ManOS hand tracking: it stores only pinch thresholds and settings, not hand geometry templates (PRIVACY.md). "Scan of hand geometry" is covered text, but nothing identifying is kept. Low risk.
- **Conclusion:** the OculOS and ManOS modules look materially less exposed than voice profiles, mostly because nothing is used to identify a person and everything stays local.

## 2. Section 15 duties (740 ILCS 14/15, text verified on ILGA) [S2]

| Subsection | Duty | Trigger | Humanity analysis |
|---|---|---|---|
| 15(a) | Written, **public** retention schedule and destruction guidelines. Destroy when the initial purpose is satisfied or within 3 years of last interaction, whichever is first. Comply with it. | "private entity **in possession of**" identifiers or information | Hinges on "possession". Under *G.T.* and *Barnett*, the developer does not possess on-device data. Under *Hazlitt*, a developer might if it exclusively controls it. |
| 15(b) | Before collecting, capturing, purchasing, receiving or otherwise obtaining: (1) written notice that it is collected or stored, (2) written notice of purpose and length of term, (3) written release. | entity that "collect[s], captur[es]... or otherwise obtain[s]" | *Barnett*: the user captures, the device is the tool. *G.T.*: control by the company is required. |
| 15(c) | No sale, lease, trade or profit from the data. | "in possession" | Not implicated unless data is transmitted. Selling the *software* is not selling the data (*Bhavilai* logic). A Gumroad key sale is not a sale of biometrics. |
| 15(d) | No disclosure or dissemination without consent, etc. | "in possession" | The AIKit sends transcript **text** only to the user's chosen LLM provider. Text is not a voiceprint, but a transcript with a speaker label derived from the voiceprint ("Alice") arguably is "information based on" a voiceprint. Treat the label as an edge case, and keep it out of AIKit payloads unless the user opts in. **[my analysis]** |
| 15(e) | Store, transmit and protect with the industry standard of care, and at least as protectively as other confidential information. | "in possession" | Local `profiles.json` is currently plain JSON under Application Support. Not encrypted at rest (assumption: confirm in code). A consumer-grade store is a user-side issue if the developer has no possession. |

### 2.1 Damages and SB 2979 (P.A. 103-769, eff. 2024-08-02)

- 14/20(a): $1,000 (negligent) or $5,000 (intentional or reckless) or actual damages, plus fees, costs and injunctive relief. [S3]
- 14/20(b): repeated collection of the same identifier from the same person by the same method in violation of 15(b) is **one** violation, with at most one recovery. 14/20(c) does the same for 15(d) disclosures to the same recipient. This ends the per-scan accrual set by *Cothron v. White Castle*, 2023 IL 128004 **[UNVERIFIED cite]**. [S3, S23]
- Electronic signature now counts as a written release. [S1]
- **Retroactivity.** *Clay v. Union Pacific R.R.*, No. 25-2185 (7th Cir. Apr. 1, 2026) held the amendment remedial and applicable retroactively to pending cases. Illinois state appellate courts may differ **[UNVERIFIED: I did not check for a conflicting state ruling]**. [S24]
- Limitations period is five years for all BIPA claims (*Tims v. Black Horse Carriers*, 2023 IL 127801) **[UNVERIFIED cite from memory]**.
- Remaining exposure math for a voice profile: one third party equals roughly one 15(b) violation, $1,000 to $5,000 per person, plus fees. A class of non-consenting meeting participants is plausible only if the developer is a proper defendant.

## 3. KEY QUESTION: developer liability for purely on-device data

**Short answer.** Under the best current authority, a developer who ships software that creates and keeps biometric data only on the user's device, and who never possesses, accesses or receives it, is unlikely to be liable under 15(a)-(e). That result is stated as probable, not certain.

### 3.1 Case table

| Case | Court / date | Facts | Holding on possess / collect / capture | Weight |
|---|---|---|---|---|
| *Barnett v. Apple Inc.*, 2022 IL App (1st) 220187 | Ill. App. Ct. 1st Dist., 2022-12-23 | Touch ID and Face ID; data stored in device Secure Enclave, not on Apple servers | Apple did not "possess" the data merely because its software processed it. The user captures her own biometrics using the device as a tool. Affirmed dismissal. [S4, S25] | Binding Illinois intermediate appellate authority (First District). Secondary summaries only; I could not load the opinion text. |
| *Hazlitt v. Apple Inc.*, No. 3:20-cv-421, 500 F. Supp. 3d 738 | S.D. Ill. (Rosenstengel, C.J.), 2020 MTD ruling; later orders through 2026 | Photos app face grouping; faceprints in on-device database | Possession plausibly alleged: users allegedly could not access or delete the data or disable the feature; only Apple could. "Complete and exclusive control". Denied MTD on 15(a) and 15(b). Standing found for 15(a) and (b); the 15(c) claim was remanded for lack of Article III standing. [S12, S26] | Outlier. Pleading stage. Status after *G.T.* **[UNVERIFIED]**; I found no 2026 merits ruling. |
| *Bhavilai v. Microsoft*, No. 1:22-cv-03440 | N.D. Ill., 2024-02-08 | Windows Photos facial scanning | Dismissed 15(a) and 15(b). "Control of the facial scan software is not the same as control of the facial scan data"; selling a tool is not collecting. Photographs are excluded. [S27] | District court. |
| *G.T. v. Samsung Electronics America*, No. 25-1120 | N.D. Ill. 2024-07-24 (dismissed); **7th Cir. 2026-08-07** (affirmed; Lee, J., with Kirsch and Brennan) | Samsung Gallery face templates | "Possession", "collection" and "capture" require some control by the company. Samsung could not access, modify or use the on-device templates. Tool-versus-data distinction (camera lucida analogy). District court also found no allegation that the data could identify anyone. [S9-S11, S28] | **Strongest and most recent authority**, federal circuit level. Does not bind Illinois state courts. |
| *Zellmer v. Meta Platforms*, 104 F.4th 1117 | 9th Cir., 2024-06-17 | Facebook Tag Suggestions "face signature" for a non-user, created on Meta's servers | BIPA applies to non-users, but a face signature that cannot identify is not a biometric identifier or information. [S21] | Illustrates the "identify" defense and that non-user status is no defense. Does not help on possession, since Meta held the data. Not on-device. |
| *In re Clearview AI Consumer Privacy Litig.* (N.D. Ill. MDL) | Settlement approved 2025-03-20; **vacated by 7th Cir. 2026-07-13** on adequacy-of-representation grounds; remanded | Scraped images, faceprints held on Clearview servers, sold to customers | Not an on-device case; Clearview held the data. Merits unaffected; the settlement ($51.75M-equivalent equity stake) was set aside and the case is back in district court. [S29] | Cautionary: server-side possession plus sale equals the high-exposure pattern, and shows BIPA suits can last for years. |

### 3.2 What the case law implies for the developer

Facts that favor the developer (all true per brief and PRIVACY.md):
- The developer receives nothing from users beyond Gumroad sale records.
- No telemetry, crash reports or update checks.
- Camera frames are never stored. Derived data stays in `~/Library/Application Support/`. The user can delete it.
- MIT-licensed, open source: anyone can inspect that there is no exfiltration.

Facts that could cut against the developer (the G.T. "would be liable" list as summarized in secondary sources [S11]):
- **Remote access or updates:** the app is not notarized yet and has no update checker, which helps. Adding an auto-updater or remote configuration could be argued to give the developer a channel to change on-device behavior. It is not access to data, but keep the distinction clear.
- **Transmission:** AIKit sends transcripts to third-party providers under the user's own API key. Diarized, named speaker labels in transcripts are the closest thing to a biometric derivative leaving the device. Keep it text-only and disclose (see section 6).
- **Forcing capture:** if enrollment were compulsory or hidden (the *Hazlitt* pattern of "cannot disable, cannot delete"), the user-as-tool argument weakens. Make everything optional, visible and deletable.
- **Gumroad:** only key and product ID go there. No biometric data.
- **The developer's own use:** if the developer ever runs the software on his own Mac with other people's voices (demo, support, beta testing), he becomes the "user", and is in possession. Avoid enrolling real third parties during development, or get releases.

### 3.3 Residual legal uncertainty

- Illinois Supreme Court has not addressed on-device processing. A state trial court is not bound by *G.T.* (federal interpretation of state law). *Barnett* is binding on Illinois trial courts in the First District and persuasive elsewhere.
- Not every Illinois appellate district has to follow *Barnett*. **[UNVERIFIED: I did not search for a later contrary state appellate case.]**
- Other state or federal statutes (Texas CUBI, Washington, CCPA/CPRA, GDPR for later international sales) have different triggers. Outside this file's scope.

## 4. Extraterritoriality and personal jurisdiction

- BIPA has no express extraterritorial reach. Courts require the relevant conduct to occur "primarily and substantially" in Illinois (*Avery v. State Farm*, 216 Ill. 2d 100 (2005), applied to BIPA by several courts) **[UNVERIFIED cite; not fetched]**. A Massachusetts seller with Illinois customers does not escape automatically: an Illinois user is the "subject" and the suit would name the developer.
- Personal jurisdiction over a sole developer who sells to Illinois buyers via Gumroad is plausible (purposeful sales) but is a defense argument for counsel. **[my analysis]**
- Practical: because the data stays on the device, the "conduct" occurs in Illinois at the user's Mac, which cuts both ways.

## 5. Third-party voiceprints created by the user (speaker profiles of non-consenting call participants)

### 5.1 What the product does

Meetings records the mic plus another app's audio (Zoom etc.). It diarizes on-device. When the user names a speaker, the app saves that speaker's embeddings as a profile tied to a name, then auto-matches that person in later meetings (matchThreshold 0.5). Profiles can be of non-users. The developer never sees them.

### 5.2 Who is the BIPA "private entity" that "collects"?

- **The user is the closest candidate.** BIPA defines "private entity" to include any individual. A user who enrolls a named colleague's voiceprint, without that colleague's written release, fits the *text* of 15(b) as a person who "capture[s]... or otherwise obtain[s]" another's voiceprint. BIPA has no express exemption for personal or household use. Whether courts would apply BIPA to an ordinary individual or business user is unsettled; I found no case on point **[no authority found]**. If the user is a business or employer, the exposure is more conventional (like the employer cases).
- **The developer** is protected by the *Barnett*/*G.T.* reasoning (tool, not collector) only so long as the developer does not control the data. The AI-meeting-assistant suits show the contrary pattern when the vendor itself runs the pipeline:
  - *In re Otter.AI Privacy Litig.* (N.D. Cal., Lee, J.): BIPA voiceprint claims by participants, including non-account holders, survived dismissal on 2026-08-13 (per UC Today summary **[UNVERIFIED: secondary only]**). Allegations: Otter built speaker-identification profiles and retained them without BIPA notice and consent. [S14, S15]
  - *Cruz v. Fireflies.AI Corp.* (N.D. Ill., filed Dec. 2025) and a second suit (*Fricker*, Mar. 2026): "Speaker Recognition" voiceprints for non-user participants, no public retention schedule, no written release. No ruling found. [S16, S17]
  - Distinction: those vendors store and process on their own servers. They are "in possession". Humanity is not. But the plaintiffs' bar is now focused on exactly this feature class, so Humanity's marketing and docs should not invite a claim that the developer "enables" non-consensual voice-profiling.
- **Facilitation theories** (aiding or contributory liability under BIPA) have no established basis in the text **[no authority found]**. Still, a product that prompts the user to "name this speaker" invites the argument that the developer designed the capture. *G.T.* rejects "supplied the software" as enough, but flagged forced capture as different.
- **Other laws that ride along with this feature** (outside BIPA but relevant to the same flow): recording consent (all-party consent states, e.g., IL eavesdropping act, MA wiretap act, CA CIPA). The call-audio recording is more clearly a risk than the embedding. See the other research files for those statutes **[not researched here]**. PRIVACY.md already tells users to "tell people when you record a meeting".

### 5.3 Risk ranking for Humanity (my judgment, not a legal conclusion)

| Feature | Biometric type | Developer possession? | Third parties? | Relative exposure |
|---|---|---|---|---|
| Voice profiles (named embeddings) | voiceprint, identifying | No (local) | **Yes** | Highest for users; moderate-low for developer if local-only holds |
| Diarization without profiles ("Speaker 1/2") | arguably none (clustering only, not used to identify a named person) | No | Yes | Low; weak "identify" prong |
| OculOS calibration and patches | face geometry or eye region, not used to identify | No | No (self) | Low |
| Gaze recordings and screenshots | gaze data; photographs excluded | No | Incidental | Low under BIPA |
| ManOS hand gestures | hand geometry, thresholds only | No | No | Low |
| Murmur dictation and voice notes (audio) | recordings, not voiceprint unless template extracted | No | Possibly | Low under BIPA; recording-consent laws are the issue |

## 6. Recommended product and documentation changes

### 6.1 Consent flow before enrolling a voice profile (highest priority)

1. Make enrollment an explicit, separate step ("Create voice profile"), not a side effect of naming a speaker. A modal should state in plain words: it creates a numeric voiceprint used to identify this person's voice in future meetings; stored only on this Mac; never sent to the developer; how long it is kept; how to delete it.
2. **Own-voice enrollment** (the user's own voice): require a click-to-sign electronic release screen. Check box plus typed name and the words "I agree" so it plainly qualifies as an electronic signature under 14/10 (intent to sign). Record timestamp and policy version locally.
3. **Third-party enrollment:** require the user to attest "I have this person's written consent to create a voiceprint of them" with a one-click link to a short consent text the user can send ("Meeting Voiceprint Consent" template, with purpose, term, and deletion). Keep a local consent record (who, when, how obtained). The app cannot verify consent, so this is risk allocation to the user, not elimination. Counsel should decide whether this shifts risk effectively or just documents knowledge.
4. Consider disabling third-party profile enrollment by default, and allowing only the user's own voice profile, with the consent attestation for others behind an "Advanced" toggle. Without enrollment, diarization still labels "Speaker 1/2" and the user can rename labels per meeting without storing embeddings.
5. Do not auto-create or auto-extend profiles. The current design ("Automatic matches never change a profile"; embeddings added only when the user names a speaker) is good: keep it and document it.
6. Avoid the *Hazlitt* pattern: never create voice embeddings silently, and let users keep using Meetings without any profile.

### 6.2 Default off

- Voice profiles feature off by default, with an opt-in switch in settings. First use triggers the consent screen. Same for OculOS screenshot recording (already optional) and the saved 10x6 eye patches (if they can be omitted without hurting accuracy, make them opt-in or session-only).
- Disabling must work and be easy: turning the feature off should stop matching and offer "delete all profiles". This directly answers the "cannot disable" fact in *Hazlitt*.

### 6.3 Retention policy and a public schedule (15(a))

- Even if the developer is likely not "in possession", publishing a short retention and destruction policy is cheap insurance and consistent with the brief. Put it in PRIVACY.md and on the product page (a "public" document), e.g.:
  - Voiceprints are kept only until the user deletes them, or automatically when unused for 12 months (suggested), and in any case no later than 3 years after last use (matches 15(a)'s outer bound of "within 3 years of the individual's last interaction"; the "individual" here includes third parties, whose last interaction is the last meeting where they were matched).
  - The developer does not hold voiceprints and cannot destroy them remotely; uninstalling plus deleting `~/Library/Application Support/Humanity/VoiceProfiles/` removes them.
- Implement the auto-expiry in code (store `lastMatchedAt` per profile; purge on launch). A written schedule that the software does not follow is worse than none, because 15(a) also requires compliance with the established schedule.
- Same for OculOS calibration and gaze recordings: state a schedule (e.g., calibration persists until cleared; recordings user-managed).

### 6.4 Deletion

- Per-profile delete and "Delete all voiceprints" buttons (present in Voice Profiles; confirm bulk delete exists). Also delete matching embedding data from any cached diarization output, and consider whether saved `Meeting` records retain speaker names (a name label is not a voiceprint but derived "information").
- Provide a documented way for a non-user to ask the user (not the developer) to delete their profile; list a contact email for the developer only to explain that the developer holds nothing.
- Secure deletion: remove file contents (overwrite or atomic rewrite). Encrypt `profiles.json` at rest (Keychain-held key or FileVault note) to support a 15(e)-style standard of care story **[confirm current implementation]**.

### 6.5 Keep the architecture facts true (these are what *G.T.* and *Barnett* rest on)

- Never add telemetry, crash upload, cloud sync (iCloud included, if developer-operated), remote config that changes biometric processing, or an updater that could read user data. Add a project rule: "no biometric data or embeddings leave the device, ever; no feature flag to turn this on".
- AIKit: keep the payload text-only and exclude speaker-identity labels derived from voiceprints, or label by "Speaker 1/2" unless the user opts in to named speakers, and disclose it.
- Document it plainly (PRIVACY.md and ToS): "The developer does not collect, receive, store or have access to voiceprints, eye data or hand data."
- Terms of use: state the user's responsibility for consent, prohibit use to profile people without consent where law requires, and include an indemnity or disclaimer (attorney to draft and judge enforceability; consumer-terms limits apply).

### 6.6 Geofencing Illinois: recommendation

Options:
| Option | Pro | Con |
|---|---|---|
| Do nothing; rely on on-device design plus consent | Keeps the product available to all US users | Illinois is the highest-litigation state; defense costs even for winning cases |
| Geofence **only voice profiles** (disable feature for Illinois users) | Removes the single highest-risk feature in the highest-risk state | Hard to enforce on a keyed, offline app: no server, region can only be inferred from system locale or timezone, easily bypassed; may look like an admission; selling to Illinois via Gumroad is still possible (Gumroad can restrict countries, not states) |
| Block Illinois sales | Strongest avoidance on its face | Impractical via Gumroad (no state-level blocking known **[UNVERIFIED]**); not a legal safe harbor; also loses customers; BIPA claims could still be asserted by a person who travels or who is a third party in a call (a non-Illinois user can record an Illinois participant) |

**Recommendation (for attorney review):** do not rely on geofencing. It is weak technically for an offline app, and the third-party problem means an Illinois resident can be the *subject* of a voiceprint made by a user anywhere. Prioritize design measures (default off, explicit consent, deletion, retention schedule, no data leaves device). If the attorney wants an extra layer, an "Illinois, Texas, Washington notice" screen at voice-profile enrollment, based on a user-chosen "I am in / am recording someone in" prompt, is cheap but is not a reliable control. Revisit once the developer has an LLC and insurance.

### 6.7 Corporate and insurance

- No entity currently: personal assets are exposed under any BIPA judgment. Forming an LLC (and, ideally, cyber or media liability insurance that does not exclude BIPA; many policies exclude it) is a business decision to raise with an attorney. **[my analysis]**

## 7. Triggers and thresholds summary

| Trigger | Threshold | Status for Humanity |
|---|---|---|
| Applies to "private entity" | any person, including individuals; excludes government | Yes, developer and users are private entities |
| No revenue or headcount threshold | BIPA has none (unlike CCPA) | Applies regardless of size |
| Biometric identifier or information | retina or iris scan, fingerprint, voiceprint, hand or face geometry scan; info "used to identify" | Voice profiles: yes. OculOS and ManOS: likely no |
| 15(a), (c), (d), (e) | "in possession" | Developer: unlikely under *G.T.* and *Barnett* |
| 15(b) | "collect, capture... or otherwise obtain" | Developer: unlikely (user is the actor); user: unresolved for third parties |
| Damages | $1,000 / $5,000 per violation, one recovery per person per method after Aug. 2, 2024 | Retroactive per *Clay* (7th Cir.) |
| Limitations | 5 years | *Tims* **[UNVERIFIED]** |
| Illinois nexus | Illinois resident subject or user; "primarily and substantially" in Illinois | Likely satisfied for Illinois users and participants |

## 8. Attorney-review flags

1. Whether the Seventh Circuit's *G.T.* reasoning will be followed by Illinois state courts, and whether any state appellate decision since *Barnett* has gone the other way **[not searched]**.
2. Whether a Massachusetts sole developer selling via Gumroad faces jurisdiction in Illinois, and whether to form an LLC first.
3. Exposure of the **user** under BIPA for enrolling third-party voiceprints, and whether the developer can be a contributory or facilitating party; whether the Terms of Service can shift responsibility.
4. Wording of the consent text and electronic-signature mechanics for own-voice and third-party enrollment; whether an in-app attestation is enough where the third party never sees it.
5. Whether PRIVACY.md's "can count as biometric data under laws like the GDPR" language is wise in public docs (it concedes a characterization; also incorrectly names only the GDPR, omitting BIPA).
6. The "info based on voiceprint" status of named speaker labels in transcripts sent to LLM providers (15(d)).
7. Interaction with recording-consent statutes for the call-audio capture (outside this file).
8. Insurance and BIPA exclusions.
9. Whether gaze data or eye-region patches could be argued to be "scan of face geometry" or iris/retina data, and whether to avoid persisting the 10x6 patches.
10. Verify the Hazlitt docket status post-*G.T.* and any 2026 developments.

## 9. Limits of this research

- ILGA statute pages for sections 10, 15, 20 and 25 were fetched directly (verbatim text above). The *G.T.* Seventh Circuit opinion (ca7.uscourts.gov) downloaded as a PDF I could not text-extract in this environment, so its holding and the "would be liable" list come from secondary summaries (WLF, ID Tech, Mondaq). Also, Justia and CourtListener returned 403 or empty pages for several opinions (*Barnett*, *Hazlitt*, *G.T.*), so those are summarized from secondary sources. **Read the primary opinions before relying on any quoted phrase.**
- No case found addressing a developer liable for **user-created third-party voiceprints stored only locally**. This is an open question.
- Cites tagged UNVERIFIED (*Cothron*, *Tims*, *Avery*, *Carpenter* reporter cite) are from memory or secondary summaries.

## 10. Sources verified (accessed 2026-10-01)

Primary (fetched):
- S1 740 ILCS 14/10 (Definitions, P.A. 103-769): https://www.ilga.gov/Documents/legislation/ilcs/documents/074000140K10.htm
- S2 740 ILCS 14/15: https://www.ilga.gov/Documents/legislation/ilcs/documents/074000140K15.htm
- S3 740 ILCS 14/20 (Right of action, as amended): https://www.ilga.gov/Documents/legislation/ilcs/documents/074000140K20.htm
- S3b 740 ILCS 14/25 (Construction): https://www.ilga.gov/Documents/legislation/ilcs/documents/074000140K25.htm
- Humanity repo: /Users/taylorpan/Cloud/Humanity/PRIVACY.md, MeetingKit/README.md, OculOS/README.md

Court opinions and dockets (URLs located by search; opinion text not read directly unless noted):
- S4 Barnett v. Apple, 2022 IL App (1st) 220187: https://law.justia.com/cases/illinois/court-of-appeals-first-appellate-district/2022/1-22-0187.html (page 403 on fetch; summary from S25)
- S9 G.T. v. Samsung, No. 25-1120 (7th Cir. Aug. 7, 2026), Justia: https://law.justia.com/cases/federal/appellate-courts/ca7/25-1120/25-1120-2026-08-07.html (not read, blocked)
- S10 same, Seventh Circuit site: https://media.ca7.uscourts.gov/cgi-bin/OpinionsWeb/processWebInputExternal.pl?Submit=Display&Path=Y2026%2FD08-07%2FC%3A25-1120%3AJ%3ALee%3Aaut%3AT%3AfnOp%3AN%3A3587785%3AS%3A0 (PDF not text-extracted)
- S12 Hazlitt v. Apple, 3:20-cv-00421 (S.D. Ill.): https://www.courtlistener.com/docket/18360440/hazlitt-v-apple-inc/ and https://www.casemine.com/judgement/us/5fb372c34653d056552fe8b7
- S13 Hazlitt docket entry 174 (Mar. 8, 2024): https://www.docketalarm.com/cases/Illinois_Southern_District_Court/3--20-cv-00421/Hazlitt_et_al_v._Apple_Inc/174/
- S21 Zellmer v. Meta, 104 F.4th 1117 (9th Cir. June 17, 2024): https://law.justia.com/cases/federal/appellate-courts/ca9/22-16925/22-16925-2024-06-17.html
- S24 Clay v. Union Pacific, No. 25-2185 (7th Cir. Apr. 1, 2026): https://law.justia.com/cases/federal/appellate-courts/ca7/25-2185/25-2185-2026-04-01.html
- S27 Bhavilai v. Microsoft, No. 1:22-cv-03440 (N.D. Ill. Feb. 8, 2024): https://caselaw.findlaw.com/court/us-dis-crt-n-d-ill-eas-div/115913600.html
- S28 G.T. v. Samsung, N.D. Ill. July 24, 2024 order: http://blogs.duanemorris.com/classactiondefense/wp-content/uploads/sites/56/2024/07/G.T.-v.-Samsung-Order-Granting-MTD-7-24-24.pdf and https://www.courtlistener.com/opinion/10178932/gt-v-samsung-electronics-america-inc/
- S29 In re Clearview AI (7th Cir. July 13, 2026): https://caselaw.findlaw.com/court/us-7th-circuit/217411.html
- S19 Gunderson v. Amazon (N.D. Ill. class cert. Nov. 6, 2025): https://www.courthousenews.com/wp-content/uploads/2025/11/gunderson-v-amazon-usdc-illinois-class.pdf
- S16 Cruz v. Fireflies complaint: https://www.workplaceprivacyreport.com/wp-content/uploads/sites/938/2026/04/Fireflies.ai-Complaint-1.pdf

Secondary (summaries relied on; verify against opinions):
- S11 Mondaq on G.T.: https://www.mondaq.com/unitedstates/privacy-protection/1833724/seventh-circuit-holds-that-bipa-does-not-reach-biometric-data-that-remains-on-a-users-device ; ID Tech: https://idtechwire.com/appeals-court-affirms-samsung-bipa-dismissal-over-on-device-face-templates/ ; WLF: https://www.wlf.org/2026/09/01/wlf-legal-pulse/possess-or-collect-under-illinois-bipa-seventh-circuit-resolves-trial-court-split/
- S25 Barnett summaries: https://blogs.duanemorris.com/classactiondefense/2023/01/09/illinois-appellate-court-affirms-dismissal-of-bipa-class-action-lawsuit/ ; https://www.americanbar.org/groups/antitrust_law/resources/newsletters/barnett-v-apple-privacy-by-design/
- S26 Hazlitt summary: https://www.ubglaw.com/news-and-media/illinois-federal-court-rules-apple-may-be-in-possession-of-biometric-data-stored-on-user-devices
- S20 Martell v. X Corp.: https://www.insideprivacy.com/privacy-and-data-security/illinois-federal-court-dismisses-bipa-suit-against-x-holding-biometric-identifiers-must-identify-individuals/
- S18, S22 FPF on eye tracking and Carpenter: https://fpf.org/blog/old-laws-new-tech-as-courts-wrestle-with-tough-questions-under-us-biometric-laws-immersive-tech-raises-new-challenges/
- S23 SB 2979 summaries: https://www.gtlaw.com/en/insights/2024/8/bipa-update-illinois-limits-liability-and-clarifies-electronic-consent-for-biometric-data-collection ; https://www.faegredrinker.com/en/insights/publications/2024/8/illinois-governor-signs-law-that-limits-damages-recoverable-under-the-biometric-information-privacy-act
- S14, S15 Otter.ai: https://www.uctoday.com/productivity-automation/otter-ai-fails-to-dismiss-core-privacy-claims-in-u-s-court/ ; https://idtechwire.com/otter-ai-must-face-voiceprint-claims-under-illinois-biometric-law/
- S17 Fireflies: https://natlawreview.com/article/lawsuit-alleges-firefliesai-corp-illegally-collects-biometric-data-virtual-meetings ; https://www.ebglaw.com/insights/publications/ai-meeting-assistants-and-biometric-privacy-lessons-from-the-fireflies-ai-lawsuit
