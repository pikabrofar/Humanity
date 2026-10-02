# 04 - Biometric laws other than Illinois BIPA (TX, WA, CO, NYC, Portland, 2025-26 new laws)

Research analyst memo, not legal advice. Prepared 2026-10-01 for the Humanity suite (OculOS, ManOS, Murmur, AIKit, LicenseKit). Nothing here says the product is "compliant" or "safe". Items marked **[UNVERIFIED]** I could not confirm against a primary source. See "Sources verified" at the end for what was read and how.

## 0. Bottom line (analyst view, not a conclusion of law)

| Law | Does it reach this product? | Why | Residual risk driver |
|---|---|---|---|
| Texas CUBI, Bus. & Com. Code 503.001 | **Unclear; the most important to review.** No on-device carve-out, no thresholds, AG-only, up to $25,000 per violation | "Voiceprint" is listed by name. Murmur voice profiles (speaker embeddings of named people, including non-users) are the closest fit. "Record of hand or face geometry" and "retina or iris scan" are a weaker fit for ManOS/OculOS | Who "captures" (end user vs. developer), and what "commercial purpose" means. Neither is defined in the statute |
| Washington RCW 19.375 (biometric identifiers) | **Probably not** | Duties attach only to *enrolling* an identifier *for a commercial purpose*. That term is defined as sale or disclosure to a third party for marketing unrelated goods. Photos, video, audio and data generated from them are excluded | Ambiguity over whether a voiceprint is "data generated from" an audio recording |
| Washington My Health My Data Act (MHMDA), ch. 19.373 RCW | **Possible, depends on facts.** Biometric data is expressly "consumer health data". Private right of action via the CPA | No revenue or volume threshold. A "regulated entity" is one that determines purposes and means of collecting or processing. "Collect" includes "access, retain, receive, ... infer, derive, or otherwise process" | Whether a developer who never receives the data "collects" or "determines the means" when the user's Mac does the processing. Not resolved by any authority I found |
| Colorado Privacy Act biometric amendment, HB24-1130 (C.R.S. 6-1-1314, eff. 2025-07-01) | **Plausibly in scope if the developer is a "controller"**. Applies "regardless of the amount" processed (6-1-1304(1)(b)). No private right of action | Capability-based trigger: a "biometric identifier" is data that "can be processed for the purpose of uniquely identifying". Voiceprints are listed | Controller status for software that processes only on the user's device. Unresolved |
| NYC Admin. Code 22-1201 to 1205 | **No** (on the face of the text) | Binds "commercial establishments" (retail store, place of entertainment, food and drink) collecting *customers'* biometric identifier information | Only if a user deploys the apps in a store or venue |
| Portland City Code ch. 34.10 | **Probably no.** Low priority | Bans private entities' use of face recognition in places of public accommodation | Broad text. A user running OculOS in a cafe is an edge case |
| Gaze / eye tracking as "biometric" or "health" data | **No authority found that says gaze alone is either.** It becomes risky once data can identify a person, or once health is claimed or inferred | See section 6 | Marketing as accessibility, and OculOS calibration artifacts |

The recurring unresolved question is whether a software vendor whose code runs entirely on the user's machine, and who never receives the data, is a "person who captures" (TX), a "regulated entity" that "collects" (WA MHMDA) or a "controller" that "collects" (CO). The statutory definitions turn on "capture," "collect," "determines the purposes and means," and "controller." I found no AG guidance or court decision applying them to local-only software. **[UNVERIFIED as to any such authority; absence of results is not proof none exists.]**

---

## 1. Texas - CUBI, Tex. Bus. & Com. Code 503.001

**Text** (mirror of the official code; section is "up to date" as of 2025-05-26 per the mirror, plus the 2025 TRAIGA amendment below):
- (a) "biometric identifier" means "a retina or iris scan, fingerprint, voiceprint, or record of hand or face geometry."
- (b) A person may not capture a biometric identifier of an individual for a commercial purpose unless the person (1) informs the individual before capturing it and (2) receives the individual's consent.
- (c) A possessor of an identifier captured for a commercial purpose: (1) may not sell, lease or otherwise disclose it except in four listed cases (consent for disappearance/death identification, completing a requested financial transaction, disclosure required or permitted by federal or other state statute, law enforcement under a warrant); (2) must store, transmit and protect it with reasonable care, at least as protective as for other confidential information; (3) must destroy it "within a reasonable time, but not later than the first anniversary of the date the purpose for collecting the identifier expires". (c-1) extends that for identifiers tied to legally retained documents. (c-2) presumes an employer security purpose expires at termination of employment.
- (d) Civil penalty up to $25,000 per violation, recoverable by the Attorney General. **No private right of action.** (e) carve-out for financial-institution voiceprint data.
- Undefined in the statute: "capture," "commercial purpose," "consent." There is no thresholds test, no small-business exemption and no local-processing exemption.
- **2025 amendment (TRAIGA, HB 149, eff. 2026-01-01):** new (b-1) says an individual has not been informed of or consented to capture "based solely on the existence of an image or other media containing one or more biometric identifiers of the individual on the Internet or other publicly available source" unless the individual made it public. Secondary summaries also report an AI-training/security exemption added in the same bill; I did not read that text. **[UNVERIFIED: the exemption language]**. It is directed at AI development and security uses and does not obviously help a dictation or eye-tracking app.

**Enforcement history (AG settlements):**
- **Meta:** Settled 2024-07-29, judgment entered 2024-07-30. $1.4 billion, payable over five years. The AG calls it the first suit and first settlement under CUBI and the largest ever obtained by a single state. The 2022 suit concerned Facebook's photo "Tag Suggestions" facial-recognition feature. (AG release and Meta's 10-Q confirm the dates and amount; the "five years" detail is from law-firm/press coverage.)
- **Google:** Announced 2025-05-09. $1.375 billion. Resolved the AG's 2022 suit over geolocation, Incognito-mode data and biometric data. Law-firm coverage ties the biometric piece to voiceprints and face geometry in Google Photos/Assistant, and reports the final agreement signed 2025-10-31. **Only the AG press releases and secondary coverage were reachable. I could not read the release text (HTTP 402), the complaint or the judgment.** The specific CUBI theories against Google come from secondary sources. **[UNVERIFIED]**
- **What these cases do and do not tell us:** Both involved server-side processing at scale of faces or voices from consumer cloud products, with the AG treating biometric capture as a deceptive/unlawful practice and pairing CUBI with the DTPA. Neither addresses on-device-only processing. They show the AG will pursue a large out-of-state company under CUBI and will use per-violation counting (the settlements were negotiated, so the penalty math is not tested). No CUBI decision on "capture" or "commercial purpose" surfaced.

**Applicability to Humanity:**
- *Murmur voice profiles* are voiceprints in the literal sense. The user creates them for named people, including non-users, and stores them locally. The person doing the "capturing" is plausibly the end user, and whether that user acts "for a commercial purpose" depends on the use (a business user recording client meetings is closer than a hobbyist). The developer's exposure depends on a theory that supplying the tool is "capture" by the developer. That theory is not impossible given the AG's expansive approach, but nothing I found endorses it for on-device software. The developer also never "possesses" the identifiers (so (c)(1) to (3) duties attach to the user, if anyone).
- *OculOS* eye-feature measurements and 10x6 px eye patches are not a "retina or iris scan" on their face (the patch is far below iris-scan resolution, but the file `OculOS/` calibration also holds "eye-feature measurements" whose content I did not audit; verify they cannot be used to identify a person). *ManOS* hand landmarks could be described as a "record of hand geometry". Camera frames are not stored, which helps. Whether transient in-memory landmark extraction is "capture" is untested.
- Triggers if in scope: inform before capture, obtain consent, do not sell/disclose, protect, destroy within one year after purpose ends.

---

## 2. Washington

### 2a. RCW 19.375 (biometric identifiers; 2017)
- "Biometric identifier": "data generated by automatic measurements of an individual's biological characteristics, such as a fingerprint, voiceprint, eye retinas, irises, or other unique biological patterns or characteristics that is used to identify a specific individual." Excludes "physical or digital photograph, video or audio recording or data generated therefrom" and HIPAA health information.
- "Enroll": capture, convert into a non-reconstructible reference template, and store in a database that matches it to a specific individual. "Commercial purpose": "in furtherance of the sale or disclosure to a third party of a biometric identifier for the purpose of marketing of goods or services when such goods or services are unrelated to the initial transaction"; excludes security or law enforcement purposes.
- Duty (19.375.020): no *enrollment for a commercial purpose* without notice, consent, or a mechanism to prevent subsequent commercial use; sale/lease/disclosure limited; retention only as reasonably necessary; reasonable security; no notice/consent needed for security purposes. Enforcement is AG-only through the Consumer Protection Act (per secondary and the fetched summary; I did not read the enforcement subsection text itself **[UNVERIFIED]**).
- **Fit:** Humanity does not sell or disclose identifiers for marketing, and the developer receives none. This statute very likely does not apply. The one open point: a voiceprint is derived from audio, and the exclusion for "data generated therefrom" may or may not swallow it. Not needed to resolve if there is no commercial purpose.

### 2b. My Health My Data Act, ch. 19.373 RCW
- **Definitions (RCW 19.373.010, read from app.leg.wa.gov):** "Consumer health data" = "personal information that is linked or reasonably linkable to a consumer and that identifies the consumer's past, present, or future physical or mental health status." The "physical or mental health status" list includes (ix) **"Biometric data"**, (v) "bodily functions, vital signs, symptoms, or measurements", (xi) precise location information, and (xiii) data derived to associate a consumer with any of these. Inference counts: the statute and the AG FAQ cover data "derived or extrapolated" from non-health data. "Biometric data" = "data that is generated from the measurement or technological processing of an individual's physiological, biological, or behavioral characteristics and that identifies a consumer, whether individually or in combination with other data" (examples include imagery of the iris, retina, fingerprint, face and keystroke patterns).
- **Answer to "does consumer health data include biometric or gaze data?"** Biometric data: **yes, by express statutory list**, but only if it "identifies a consumer". Gaze data: **not named.** Raw gaze coordinates that do not identify anyone and do not reveal a health condition are not within the text as I read it. Gaze could enter if (i) it is used to identify the person (then it is "biometric data"), (ii) the feature or marketing links it to a health condition (see section 6), or (iii) the product infers health status from it.
- **Scope:** "Regulated entity" = conducts business in Washington or targets WA consumers, and "alone or jointly with others, determines the purpose and means of collecting, processing, sharing, or selling of consumer health data." "Collect" is very broad ("buy, rent, access, retain, receive, acquire, infer, derive, or otherwise process"). No size threshold; small businesses get a later compliance date only (3/31/2024 vs. 6/30/2024). "Consumer" covers WA residents (and data collected in WA) acting in an individual or household context, and excludes employment context. The AG FAQ says an entity that merely stores data in WA is not regulated, and out-of-state processors must comply. The FAQ does not address on-device software.
- **Requirements if in scope:** consumer health data privacy policy linked on the homepage (categories collected and purposes, sources, categories shared, third parties, how to exercise rights) (19.373.020); consent to collect for a specified purpose and separate, distinct consent to share, with the consent request explaining categories, use, recipients and withdrawal; both consents are excused to the extent "necessary to provide a product or service that the consumer ... has requested" (19.373.030); access/withdrawal/deletion rights (19.373.040, not read); a separate valid authorization for any sale (19.373.070, not read **[UNVERIFIED]**); security (19.373.050, not read).
- **Exemptions (19.373.100):** HIPAA PHI, ch. 70.02, GLBA, FERPA etc., and processing to prevent or respond to security incidents or fraud. None fits.
- **Enforcement:** a violation is a per se violation of the Consumer Protection Act, RCW 19.86, enforced by the AG and by private plaintiffs (AG FAQ). First class action: *Maxwell v. Amazon.com, Inc.*, No. 2:25-cv-261 (W.D. Wash., filed 2025-02-10), alleging SDK-based collection of location data and biometric/health data. I found no ruling; status unknown. **[UNVERIFIED: current status.]** The risk is a plaintiff-side private right of action, unlike TX and CO.
- **2025-26 legislative changes:** Nothing amending MHMDA surfaced. HB 1671 (a broader WA privacy bill) was reported stuck in Appropriations as of January 2026. **[UNVERIFIED: outcome of the 2026 session]**.
- **Applicability to on-device-only:** Strongest argument for non-application is that the developer neither receives nor "determines the means" by which the user's own device processes the user's own face or voice. Counter-argument: "determines the purpose and means ... of collecting, processing" can describe whoever designs the processing, and "collect" includes "derive" and "infer". A conservative reading says apply a light-touch MHMDA-style disclosure and consent for the identification-capable data (voice profiles), and avoid any health framing.

---

## 3. Colorado - HB24-1130 (C.R.S. 6-1-1314; signed 2024-05-31; effective 2025-07-01)

Read from the signed act (official PDF, text recovered by OCR). Key text:
- **Applicability, 6-1-1304(1):** the original two-threshold test (100,000 consumers, or 25,000 plus revenue/discount from sales of personal data) is now paragraph (a). New (b): the part applies to a controller that "controls or processes any amount of biometric identifiers or biometric data regardless of the amount ... controlled or processed annually," but such a controller that meets (b) and not (a) "shall comply with this part only for the purposes of a biometric identifier or biometric data that the controller collects and processes." **Confirmed: the CPA thresholds do not limit the biometric provisions.** (The one exception: the access right in 6-1-1314(5) is limited to entities that meet the (a)-type thresholds.)
- **Definitions (6-1-1303(2.2), (2.4)):** "Biometric identifier" = data generated by technological processing, measurement or analysis of a consumer's biological, physical or behavioral characteristics "which data can be processed for the purpose of uniquely identifying an individual," including fingerprint, voiceprint, retina/iris scan, facial map/geometry/template, "or other unique biological, physical, or behavioral patterns or characteristics." "Biometric data" = one or more biometric identifiers "used or intended to be used ... for identification purposes"; excludes photographs, audio/voice recordings and data generated from photographs or audio/video recordings *unless used for identification*. "Collect" (6-1-1314(1)(a)) = "access, assemble, buy, rent, gather, procure, receive, capture, or otherwise obtain ... by any means, online or offline," including passively receiving and "obtaining biometric data by observing the consumer's behavior".
- **Duties:**
  - Written policy (6-1-1314(2)): retention schedule; incident-response protocol incl. notification under 6-1-716; deletion guidelines requiring deletion by the *earliest* of (A) purpose satisfied, (B) 24 months after the consumer last interacted, (C) no more than 45 days (extendable by 45) after the controller determines storage is no longer necessary/adequate/relevant, based on an annual review. The policy must be made public (carve-outs: employee-only policies, internal-only policies, internal incident protocol).
  - Before collecting or processing a biometric identifier (6-1-1314(4)(a)): satisfy 6-1-1308 duties; tell the consumer, clearly and accessibly, that a biometric identifier is being collected, the specific purpose, how long it will be retained, and whether it goes to a processor and why. (4)(e): obtain consent before collecting biometric data (consent standard in 6-1-1308(7) and 6-1-1303(5)).
  - Limits: no sale/lease/trade; disclosure only with consent, for a requested financial transaction, to a necessary processor within consented purpose, or as required by law; no refusal of service for refusing consent unless collection is necessary to provide it; no differential price/quality for exercising rights; no purchase without payment, consent and unrelated purpose; protect to the industry standard of care.
  - Employer rules (6-1-1314(6)): employee/prospective employee consent may be a condition of employment only for secure access, timekeeping, workplace/public safety; otherwise consent must be voluntary and non-retaliatory. "Employee" includes contractors, interns and fellows.
  - AG rulemaking (6-1-1314(7)); I saw references to Rule 6.12 ("Biometric Identifier Notice") and amended rules (proposed amendments dated through October 2025), but could not read the rule text or confirm the final version. **[UNVERIFIED: rule content]**
- **Enforcement:** the AG and district attorneys under the CPA; secondary sources say no private right of action and penalties up to $20,000 per violation under the Colorado Consumer Protection Act. **[UNVERIFIED: exact penalty cite]** The section title in the act mentions "remedies and civil actions," but I found no private action text in the OCR.
- **Neural data (HB24-1058, eff. 2024-08-06):** adds "biological data" (used for identification) and "neural data" (measurement of central or peripheral nervous system activity) as sensitive data (per Hunton/NatLawReview summaries; I did not read the act). Camera-based gaze is not a measurement of nervous-system activity in the ordinary sense, so I do not expect it to be neural data; EOG/EEG/EMG sensors would be. **[Analyst view, UNVERIFIED]**

**Applicability to Humanity:**
- Colorado's text makes thresholds irrelevant, so "we are small" is not a defense. The live question is controller status. The CPA defines "controller" as a person that "alone or jointly with others, determines the purposes for and means of processing personal data" (definition not read from a primary source in this session **[UNVERIFIED]**). A vendor that ships code determining the means, but never receives data, is an open question. The statutory definition of "collect" (access, receive, capture... "by any means") is broad, but all of those verbs presuppose the developer obtaining the data.
- *Murmur voice profiles* clearly meet the "biometric identifier" definition and are "used for identification purposes" (speaker recognition), so they are also "biometric data". *OculOS* calibration (eye-feature measurements) is the gray area: the "can be processed for the purpose of uniquely identifying" test is capability-based and does not ask for intent, so the question is whether the stored eye features could realistically identify someone. *ManOS* and gaze coordinates are less likely.
- If in scope: public written policy, notice (purpose, retention, processor), consent, no-conditioning, 24-month/45-day deletion, no sale.
- Consumer scope: "consumer" is a Colorado resident acting in an individual or household context (commercial/employment context excluded) **[UNVERIFIED, from memory of 6-1-1303(6)]**. Business users deploying Murmur Meetings may themselves be controllers; the employer section of 1314(6) applies to them, not to Humanity.

---

## 4. NYC and Portland

**NYC Admin. Code 22-1201 to 22-1205 (Local Law 3 of 2021; read from the official session-law PDF via OCR):**
- Applies to a "commercial establishment" (place of entertainment, retail store, food and drink establishment) that "collects, retains, converts, stores or shares biometric identifier information of customers." "Biometric identifier information" = a physiological or biological characteristic "used by or on behalf of a commercial establishment ... to identify, or assist in identifying, an individual" (iris/retina scan, fingerprint/voiceprint, hand or face geometry scan).
- Duty: a clear sign near all customer entrances (22-1202(a)). Separate ban on selling, leasing, trading or profiting from biometric identifier information (22-1202(b)). Exemptions in 22-1204 include government, financial institutions (for the sign) and photos/video not analyzed to identify people. Private right of action (22-1203): 30-day written notice and cure for sign violations; $500 per sign violation or negligent sale; $5,000 per intentional/reckless sale; fees and costs.
- **Fit:** Humanity is software sold to individuals, not a commercial establishment collecting customer data. Not applicable on its face. A retailer who ran OculOS/ManOS on store customers would be the covered party. There is no sale of data, so 22-1202(b) is not implicated.

**Portland City Code ch. 34.10 (effective 2021-01-01):**
- Prohibits "private entities" (any individual, business or entity) from using "Face Recognition Technologies" in "places of public accommodation" in the city. Technology definition (from portland.gov): "automated or semi-automated processes using Face Recognition that assist in identifying, verifying, detecting, or characterizing facial features of an individual." Exceptions: legal compliance; user verification to access the individual's own or employer-issued device; automatic face detection in social media apps. Private right of action: damages or $1,000 per day, whichever is greater, plus attorney fees if written demand was made 30 days before suit.
- **Fit:** Humanity's apps run on the user's own computer. The ordinance is aimed at operators of the place. I think a visitor using their own laptop is not the target, but the text ("characterizing facial features") is broad and I found no case law. **[UNVERIFIED: the "Face Recognition" sub-definition and any case law]**. Low priority; consider a one-line note.

---

## 5. New state biometric-related laws, 2025-2026 (not exhaustive)

| Law | Status | Relevance |
|---|---|---|
| Texas TRAIGA (HB 149), amends CUBI | Signed 2025-06-22, effective 2026-01-01 (text of (b-1) read from capitol.texas.gov) | Online-image "consent" rule and AI exemptions. Minimal relevance to on-device capture |
| Colorado HB24-1130 | Effective 2025-07-01 | Section 3 |
| Colorado HB24-1058 (neural/biological data) | Effective 2024-08-06 | Section 3 |
| Montana SB 163 (neural data via Genetic Information Privacy Act) | Reported effective October 2025 **[UNVERIFIED, secondary only]** | Not gaze |
| California neural-data amendment to CCPA | Reported enacted **[UNVERIFIED]** | Not gaze |
| Connecticut SB 4 / Public Act 26-64 | Signed 2026-05-27 per secondary sources; facial-recognition signage for on-premises use effective 2026-10-01, AG enforcement reported from 2027-02-01 **[UNVERIFIED: official text not read; cga.ct.gov fetch failed on a certificate error]** | Premises-signage duty for businesses using facial recognition. Not directed at personal software |
| Comprehensive state privacy laws (VA, CT, OR, MT, TX and others) | Biometric data used to identify is "sensitive data," opt-in consent | Texas TDPSA (541.001, read via mirror): "biometric data" = automatic measurements of biological characteristics used to identify (excludes photos/audio per usual formulation, not confirmed here). TDPSA applies to those who are not SBA-defined small businesses (541.002(a)); small businesses face a limited rule on selling sensitive data without consent (541.107, not read). A sole individual developer is probably a "small business," **[UNVERIFIED]** |

I did not find a new standalone, BIPA-style statute enacted in 2025-2026 beyond the items above. That is a limit of the search, not a finding.

---

## 6. Is eye or gaze tracking "biometric" or "health" data under these laws?

| Question | TX CUBI | WA 19.375 | WA MHMDA | CO |
|---|---|---|---|---|
| Is gaze (x,y point of regard) a listed identifier? | No (retina/iris scan, fingerprint, voiceprint, hand/face geometry) | No | Only if it "identifies a consumer" | No; but "other unique ... behavioral patterns" can catch behavioral signals that can uniquely identify |
| Can eye-derived features (iris texture, eye landmarks, calibration vectors) be an identifier? | Yes if they amount to a "retina or iris scan" or "face geometry" record | Yes if "used to identify a specific individual" | Yes if they identify a consumer | Yes, capability-based: "can be processed" for unique identification |
| Is gaze "health" data? | n/a | n/a | Not by list. Becomes health data if it identifies a health condition, is linked to a condition, or is used to infer one | n/a (CO has no gaze-specific rule) |

- **No statute, regulation, AG guidance, or case I found names eye or gaze tracking.** The treatment of gaze is analyst inference. Academic and law-firm commentary (VR/AR eye-tracking pieces) treats eye-tracking as potentially biometric where it can identify users. I did not verify these.
- **Accessibility framing is the health-data risk.** If Humanity markets OculOS/ManOS as tools for people with motor disabilities or repetitive strain, then using the product could "identify the consumer's ... health status" or "[data] identifying a consumer seeking health care services." That creates MHMDA exposure the product would not otherwise have, and may trigger heightened expectations under other laws (ADA marketing claims, FTC health-claims) outside this memo's scope.
- **Raw gaze recordings with screenshots** (OculOS heatmaps): screenshots may capture other people's data or sensitive content; not a biometric issue under these laws, but relevant to MHMDA if a screenshot shows health information. Keep it user-local and user-deletable.
- Calibration "eye image patches" at 10x6 px: very low resolution, but the stored per-user "eye-feature measurements" are the thing to inspect. If they cannot re-identify a person across sessions, the Colorado "biometric identifier" argument is weak; if they can, treat them as an identifier.

---

## 7. Applicability to on-device-only processing (cross-law summary)

| Law | Any on-device carve-out in text? | Best argument for non-application | Counter-risk |
|---|---|---|---|
| TX CUBI | No | Developer does not "capture" or "possess"; end user does | AG has read CUBI broadly (Meta, Google); "commercial purpose" and "capture" are undefined; no thresholds; end users who are businesses are exposed |
| WA 19.375 | No | No commercial purpose (no sale/disclosure for marketing) | Voiceprint-from-audio exclusion ambiguity cuts in favor of non-application |
| WA MHMDA | No | Developer does not "collect" or determine means for data it never receives | "Collect" includes "derive" and "process"; private right of action; AG FAQ silent on local processing |
| CO | No | Developer is not a "controller" that "collects" (no access or receipt) | "Determines ... means of processing" can describe the software author; thresholds irrelevant |
| NYC / Portland | n/a | Not a commercial establishment / not operating a place | User deployment in a store or venue |

None of the statutes I read exempts data processed only on the user's device. Reliance on "we never receive the data" is an interpretive argument, not a safe harbor.

---

## 8. Recommended product and documentation measures

**Product (all low-cost, consistent with the existing no-telemetry design):**
1. **Explicit first-use consent for identification-capable data.** Before creating a Voice Profile: a separate, unbundled, affirmative prompt (not buried in terms) stating that a voiceprint will be created, the purpose (speaker labels in meetings), that it is stored only on this Mac, how long, and how to delete. This one flow answers TX (inform + consent), CO (4)(a) notice elements, and MHMDA-style consent. Record the consent locally with a timestamp.
2. **Third-party voiceprints.** On creating a profile for a non-user, show a reminder that the user is responsible for informing and obtaining consent from that person under local law (TX and CO treat the speaker as the consumer). Provide a one-click "delete this person's profile" and a "do not create profiles" setting.
3. **Retention controls.** Auto-expiry for voice profiles and OculOS calibration (suggest default: delete after 12 months of non-use, which sits inside both Texas's one-year-after-purpose rule and Colorado's 24-month/45-day rule; make configurable and visible). Provide a single "Delete all biometric data" action covering `OculOS/`, `Humanity/VoiceProfiles/` and any cached embeddings.
4. **Audit what OculOS stores.** Document precisely what "eye-feature measurements" contain and whether they could re-identify a person. If not needed after calibration, store only task-specific parameters. Keep camera frames in memory only (already true).
5. **Do not add identification features** (cross-session face/eye identification, gaze-based authentication) without a legal review. Do not add any telemetry, cloud sync or backup of biometric folders, and exclude `VoiceProfiles/` and calibration from iCloud/Time Machine-synced locations or at least disclose the backup behavior (Time Machine copies would extend retention).
6. **AIKit guardrail.** Confirm no voiceprint, embedding or eye data can ever be included in text sent to cloud AI providers (the documented design sends transcript text only). Transcripts that label speakers by name are personal data but not biometric identifiers; note that in docs.
7. **Do not infer or label health or attention states** from gaze (fatigue, neurological or attention scoring). Keep gaze as pointer input only.
8. **Employer/team use.** Add a short note that employers deploying the suite on employees need their own notices and consent (CO 6-1-1314(6), TX (c-2), BIPA in IL).

**Documentation:**
1. **Biometric data notice and written policy page** (public, versioned). Contents: what is collected (voiceprints in Murmur; eye-feature calibration in OculOS; hand landmarks transiently in ManOS), the purpose, where stored, retention schedule, deletion guidelines (earliest of: purpose met, 24 months of non-use, and 45 days from a decision that storage is unnecessary, with an annual review), incident-response protocol (an individual developer can state: no server-side data exists; a lost or compromised Mac is the user's incident; provide a way to contact the developer), no sale or disclosure, no processors for biometric data. Mirrors CO 6-1-1314(2) and (4)(a) and answers TX (c)(3).
2. **Fix `PRIVACY.md`.** It currently says only that gaze data and voiceprints "can count as biometric data under laws like the GDPR" and tells users to follow consent laws. Add U.S. state coverage, a plain statement that the developer does not receive or have access to the data, and the retention/deletion controls above. Avoid asserting the data "is not biometric" or "is not regulated."
3. **Marketing/website.** Avoid health, medical, diagnostic or disability-treatment claims for OculOS/ManOS. If accessibility use is promoted, have counsel review the MHMDA, FTC and ADA implications first. Do not advertise as "compliant with BIPA/CUBI/GDPR."
4. **Terms/EULA.** State that users are responsible for lawful use, including consent from people whose voices they profile or record; add an indemnity/limitation appropriate for an individual seller. Do not rely on a click-through alone as "consent" under the Colorado/Texas standards (CO excludes bundled acceptance; TDPSA's consent definition excludes acceptance of broad terms).
5. **Washington.** If counsel concludes MHMDA could apply, publish a short consumer health data privacy policy page and link it on the website homepage and Gumroad page (RCW 19.373.020); if not, document the reasoning internally.
6. **Gumroad/LicenseKit.** Sale records (name/email via Gumroad) are not biometric. Keep Gumroad payload limited to key and product ID, as now.
7. **Store a dated compliance-reasoning memo** (the interpretation that on-device-only processing falls outside "capture," "collect," and "controller") so there is a record if the AG inquires.

---

## 9. Attorney-review flags

1. **Texas:** Is an individual developer who distributes software that creates voiceprints on users' machines a "person who captures"? What is a "commercial purpose" when the user is a business? Does the AG treat the user's own device as the developer's agent? Review the Meta and Google final judgments (not obtained) for the AG's theory, definitions and injunctive terms.
2. **Colorado:** Is the developer a "controller" for local-only processing? Does "collect ... by any means" reach software that gives the user the means? Read the final AG Rules (Rule 6.12 and any 2025 amendments) and 6-1-1308(7) consent standard. Confirm penalty and enforcement provisions and whether "remedies and civil actions" in the section title implies anything beyond AG enforcement.
3. **Washington:** MHMDA applicability to non-receiving developers; whether eye-feature calibration "identifies a consumer"; effect of accessibility marketing; *Maxwell v. Amazon* developments.
4. **Third-party voiceprints** (non-users): who obtains consent, and whether the Meetings feature design shifts liability to the developer. Also interacts with federal and state wiretap laws (outside this memo).
5. **BIPA overlap** (Illinois, separate memo): if the developer has even one Illinois user, BIPA's private right of action dwarfs the AG-only regimes discussed here.
6. **Entity structure and insurance** (Massachusetts individual developer, no LLC): personal exposure to per-violation penalties; consider LLC and insurance before expanding sales.
7. Confirm Connecticut PA 26-64 and any other 2026 enactments against official text.

---

## Sources verified (read 2026-10-01 unless noted)

**Primary or near-primary, read:**
- Tex. Bus. & Com. Code 503.001 text via Texas Public Law mirror of the official code: https://texas.public.law/statutes/tex._bus._and_com._code_section_503.001 (official site https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm#503.001 is script-rendered and could not be fetched; mirror says verified 2025-05-26).
- TRAIGA, HB 149 enrolled text, (b-1) amendment and effective date: https://capitol.texas.gov/tlodocs/89R/billtext/html/HB00149F.htm (read via fetch summary, quoted passage consistent with secondary sources).
- Colorado HB24-1130 signed act, read in full (OCR of official PDF): https://content.leg.colorado.gov/sites/default/files/2024a_1130_signed.pdf ; bill page (signed 2024-05-31, effective 2025-07-01): https://leg.colorado.gov/bills/hb24-1130
- RCW 19.375.010 and .020: https://app.leg.wa.gov/RCW/default.aspx?cite=19.375.010 and ...cite=19.375.020 (read via fetch summaries, not verbatim page)
- RCW 19.373.010, .020, .030, .100: https://app.leg.wa.gov/RCW/default.aspx?cite=19.373.010 (and .020, .030, .100) (read via fetch summaries, not verbatim page)
- WA AG My Health My Data FAQ: https://www.atg.wa.gov/protecting-washingtonians-personal-health-data-and-privacy
- NYC Local Law 3 of 2021 (Admin. Code 22-1201 to 22-1205), official PDF, read via OCR: https://intro.nyc/local-laws/2021-3
- Portland City Code ch. 34.10: https://www.portland.gov/code/34/10 (read via fetch summary)
- Texas AG release, Meta ($1.4B, CUBI first suit; dates confirmed by Meta 10-Q): https://www.texasattorneygeneral.gov/news/releases/attorney-general-ken-paxton-secures-14-billion-settlement-meta-over-its-unauthorized-capture ; Meta 10-Q: https://www.sec.gov/Archives/edgar/data/1326801/000132680124000069/meta-20240630.htm (only search-result excerpts read; release page returned HTTP 402 on direct fetch for the related release)
- Texas AG releases, Google ($1.375B): https://www.texasattorneygeneral.gov/news/releases/attorney-general-ken-paxton-secures-historic-1375-billion-settlement-google-related-texans-data and https://www.texasattorneygeneral.gov/news/releases/attorney-general-ken-paxton-finalizes-historic-settlement-google-and-secures-1375-billion-big-tech (search-result excerpts only; page fetch returned HTTP 402)
- Tex. Bus. & Com. Code 541.001-.002 (TDPSA) via mirror: https://texas.public.law/statutes/tex._bus._and_com._code_section_541.001

**Secondary only (not confirmed against primary text):** Google settlement CUBI details and 2025-10-31 signing (Alston & Bird, Blank Rome, Norton Rose Fulbright coverage); Colorado AG rules (https://coag.gov/app/uploads/2025/10/FINAL-REDLINE-Proposed-Amendments-to-CPA-Rules.pdf, https://regulations.justia.com/states/colorado/900/904/rule-4-ccr-904-3/part-4-ccr-904-3-6/section-4-ccr-904-3-6-12/ - both unreadable here); Colorado HB24-1058 (https://content.leg.colorado.gov/sites/default/files/2024a_1058_signed.pdf not read; Hunton/NatLawReview summaries); Connecticut PA 26-64 (Proskauer, DataGuidance, recordinglaw summaries); Montana SB 163 and California neural-data law; *Maxwell v. Amazon* docket (https://dockets.justia.com/docket/washington/wawdce/2:2025cv00261/344509, not opened); WA HB 1671 status.

**Could not access:** Justia Colorado statute pages (HTTP 403), Colorado Revised Statutes definition of "controller"/"consumer"/"consent", cga.ct.gov Public Act 26-64 (certificate error), AG press release full texts for Google (HTTP 402).
