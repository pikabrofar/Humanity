# Humanity: Legal and Compliance Research Map

> **This is not legal advice.** An engineer wrote it as research, not a lawyer. Nothing here says the product is "compliant" or "safe". It maps which laws may touch the product, why, and what to change or ask about. Every row marked **Attorney review: YES** needs a licensed attorney before anyone relies on it.
>
> **As of:** 2026-10-01. **Verification legend:**
> - **V**: primary or official source fetched and read on 2026-10-01.
> - **V2**: confirmed through a secondary source or search snippet only.
> - **U**: NOT verified; background knowledge, must be checked before relying on it.

---

## 0. Facts the analysis relies on (from the code, 2026-10-01)

| Data | Where it lives | Leaves the Mac? | Code |
|---|---|---|---|
| Camera frames | Memory only, discarded per frame | No | `OculOS/Sources/GazeKit/CameraCapture.swift` |
| OculOS calibration: eye-feature numbers, model parameters, **10×6-pixel eye patches** (tiny image crops of the eye) | `~/Library/Application Support/OculOS/` | No | `GazeCalibration.swift`, `EyePatch.swift` |
| Gaze recordings (coordinates) and optional screen screenshot | Same | No | `OculOSUI/AppModel.swift` |
| Hand pose (ManOS) | Memory only; only pinch thresholds stored | No | `ManOS/` |
| Dictation text; audio if history is on and no secure field was focused; voice-note audio | `Murmur/Recordings/` | No | `MurmurUI/AppModel.swift:153-168` |
| **Meetings**: mic track, other app's audio track (Core Audio tap / ScreenCaptureKit), transcript, summary | `Humanity/Meetings/` | No (summary text can go to a cloud LLM, see AIKit row) | `MeetingKit/` |
| **Voice profiles**: up to 20 × 256-float speaker embeddings per *named person* | `Humanity/VoiceProfiles/profiles.json` | No | `VoiceProfileStore.swift` |
| License | `Humanity/license.json` (key and last-verified date) | Key, product ID and `increment_uses_count` go to `api.gumroad.com` at activation and weekly | `LicenseKit/License.swift` |
| AIKit (opt-in, user's own key) | Keychain | **Transcript text and speaker names** go to the user-chosen LLM provider for that task; default is on-device; skipped for password fields | `AIKit/` |
| Diarization models | Downloaded once from Hugging Face via FluidAudio (exposes IP; no hash pinning) | Download only | `Diarizer.swift` and FluidAudio `ModelHub` |
| Telemetry, analytics, crash reports, update checks | None found | n/a | grep of all `URLSession` users |

**Consent UX today:**
- **Meetings:** a grey caption reads "Tell everyone on the call that you're recording before you start." There is no confirmation step and no notice that the *other* participants can hear or see (`MeetingRecorderControl.swift`).
- **Voice profiles:** naming a speaker ("Rename this speaker and remember their voice") silently enrolls a voiceprint of a **third party**. There is no consent step and no retention limit (`MeetingDetailView.swift`).

**Gumroad's reply holds more than the app uses.** Per Gumroad's docs, the license-verify response includes the buyer's `email` and `ip_country`, among other fields. The app parses only `success` and the refunded/chargebacked/disputed flags and stores nothing else. Source: https://gumroad.com/help/article/76-license-keys (V).

**Already fixed by the coordinator before this pass:**
- Info.plist camera, mic and speech strings.
- README "free" wording: it now says the download "costs nothing, but the apps need a paid license key to run".
- The voiceprint "can't be recovered" comment.

---

## 1. The threshold question: does the developer "collect" or "possess" data that never leaves the user's Mac?

**Short answer from the sources:** under the best authorities found, probably not, as long as the developer has no **control** over or **access** to the data. Three things change that:
- **Architecture changes** such as sync, telemetry, crash uploads, remote config that reads local data, or a hosted feature.
- **Third-party voiceprints**, which weaken the "user handles only their own data" rationale.
- **Statutes keyed to "controllers"** who decide the "purposes *and means*". A software designer arguably sets the means.

| Authority | What it says about on-device processing | Status |
|---|---|---|
| **G.T. v. Samsung Elecs. Am., Inc., No. 25-1120 (7th Cir. Aug. 7, 2026)**, https://media.ca7.uscourts.gov/cgi-bin/OpinionsWeb/processWebInputExternal.pl?Submit=Display&Path=Y2026%2FD08-07%2FC%3A25-1120%3AJ%3ALee%3Aaut%3AT%3AfnOp%3AN%3A3587785%3AS%3A0 | BIPA "possession" and "collect/capture/obtain" require **control over the biometric data itself**. Supplying software that builds face templates on the user's device, with no allegation that data left the device or that Samsung could access, modify or use it, is not enough. Data that "remain parked" on the device fall outside BIPA's core. Adopts *Bhavilai v. Microsoft* ("providing the tool versus using the tool") and *Barnett v. Apple*; rejects the *Hazlitt v. Apple* line. | **V** (opinion PDF read) |
| **Barnett v. Apple Inc., 2022 IL App (1st) 220187** | Face ID / Touch ID stored on the device: the user, not Apple, captures; Apple did not possess. | **V2** (as described in G.T.; Illinois courts PDF not fetched) |
| **FTC COPPA FAQ**, https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions | For a children's app that never transmits photos: "You are not collecting personal information simply because your app interacts with personal information that is stored on the device and is never transmitted." | **V** |
| **GDPR Recital 18 and Art. 2(2)(c)**, https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679 | Household processing is exempt. But the GDPR "applies to controllers or processors which provide the means" for household processing. That reaches tool providers only if they are controllers or processors, i.e. they process the data. | **V** |
| **WA RCW 19.373.010** (My Health My Data Act), https://app.leg.wa.gov/RCW/default.aspx?cite=19.373.010 | "Collect" includes to "access ... derive, or otherwise process … in any manner". A "regulated entity" is one that "alone or jointly with others, determines the purpose and means". **The "means" prong is the open hook for a software designer.** | **V** |

**Engineering rule that follows:** keep the developer *technically unable* to access, modify or use any camera, mic, gaze or voiceprint data. Treat any feature that breaks this (cloud sync, crash reports with payloads, analytics, remote kill-switch that reads data, hosted AI) as a **legal-review gate**.

---

## 2. Law-by-law

Format for each law:
- **Applies?** (with the reason)
- **Trigger** (I = immediate, T = threshold)
- **Obligations**
- **Changes** (product)
- **Docs**
- **Source** (with V/V2/U)
- **Confidence**
- **Attorney** (review needed?)

### 2.1 FTC Act §5 (US, federal): deception and unfairness

- **Applies?** **Yes, immediately.** §5 reaches any "unfair or deceptive acts or practices in or affecting commerce". It needs no data collection. **The privacy claims themselves are the regulated conduct.**
- **Trigger:** **I**, any commercial sale.
- **Obligations:**
  - Every express or implied claim must be truthful and substantiated: "never uploaded", "no telemetry", "frames never saved", "stays on this Mac", accessibility claims.
  - Unfairness test (§45(n)): substantial injury, not reasonably avoidable, not outweighed by benefits.
- **Relevant precedent:**
  - *Zoom* (final Feb. 1, 2021): false end-to-end encryption claims, plus a Mac update that secretly bypassed a Safari safeguard. The order required a security program and review of updates.
  - *Everalbum* (May 7, 2021): facial recognition without consent. The order required deleting the models built from the data and getting express consent.
  - *Avast* (June 27, 2024): $16.5M after "blocks tracking" claims while selling browsing data.
  - *accessiBe* (final Apr. 22, 2025): $1M for unsupported claims that an AI tool makes sites WCAG-compliant, plus undisclosed paid reviews.
- **FTC "Free" Guide, 16 CFR 251.1:** conditions of a "free" offer must be disclosed clearly and conspicuously at the outset. The README fix addresses this; apply the same wording on the GitHub Releases page and the Gumroad page.
- **Changes:**
  - Claims-vs-code audit before each release. A CI grep for `URLSession`/`NWConnection`/`URLRequest` outside `AIKit`, `LicenseKit` and FluidAudio's downloader should fail the build.
  - Reword "Only derived numbers are kept" in PRIVACY.md: the 10×6-pixel eye patches are image crops, not just numbers.
  - The camera string "Video frames … never saved" is defensible for full frames. Add "tiny eye crops for calibration" for precision.
  - Disclose that Gumroad's verify response returns buyer email and IP country to the app, even though the app discards them.
  - Disclose that speaker names and other participants' words go to the AI provider when cloud summaries are on.
  - Pin SHA-256 hashes for the Hugging Face model downloads (a data-security reasonableness point).
  - Notarize releases. The Zoom-Mac precedent shows the FTC watches Mac security shortcuts. Telling users to click "Open Anyway" is not deceptive, but it weakens the security posture.
  - Never claim the app makes anything "accessible", "ADA/WCAG compliant" or medically useful without substantiation.
- **Docs:** PRIVACY.md (accurate, versioned, dated); claims log mapping each claim to the code path.
- **Source:** 15 U.S.C. §45 https://www.law.cornell.edu/uscode/text/15/45 (V)
  - Deception Statement landing page https://www.ftc.gov/legal-library/browse/ftc-policy-statement-deception (V; PDF not re-read)
  - Zoom https://www.ftc.gov/news-events/press-releases/2021/02/ftc-gives-final-approval-settlement-zoom-over-allegations-company (V)
  - Everalbum https://www.ftc.gov/news-events/news/press-releases/2021/05/ftc-finalizes-settlement-photo-app-developer-related-misuse-facial-recognition-technology (V)
  - Avast https://www.ftc.gov/news-events/news/press-releases/2024/06/ftc-finalizes-order-avast-banning-it-selling-or-licensing-web-browsing-data-advertising-requiring-it (V)
  - accessiBe https://www.ftc.gov/news-events/news/press-releases/2025/04/ftc-approves-final-order-requiring-accessibe-pay-1-million (V)
  - 16 CFR 251.1 https://www.law.cornell.edu/cfr/text/16/251.1 (V)
- **Confidence:** High that §5 applies; medium on which specific wording would be challenged.
- **Attorney:** **YES** (one-time review of PRIVACY.md, README, Gumroad copy and in-app strings).

### 2.2 FTC Policy Statement on Biometric Information (May 18, 2023)

- **Applies?** **Yes, as enforcement guidance under §5.** It is not a rule. Voiceprints and face or eye measurements are within its scope.
- **Trigger:** **I.**
- **Obligations (as guidance):** assess foreseeable harms before deploying, avoid surreptitious or unexpected collection, back up any accuracy claims, evaluate third parties. **List from memory (U):** ftc.gov was down during this pass and the PDF was not read.
- **Changes:**
  - Make speaker recognition **opt-in**.
  - Give a clear just-in-time notice when a voiceprint is saved.
  - Make no accuracy claims for gaze or speaker ID without test data. The match threshold of 0.5 is documented in code; publish evaluation numbers if you claim accuracy.
- **Docs:** a short internal "biometric risk assessment" note (purpose, data, retention, misuse cases such as secret identification of coworkers).
- **Source:** https://www.ftc.gov/legal-library/browse/policy-statement-federal-trade-commission-biometric-information-section-5-federal-trade-commission
  - V: the page is live and shows no withdrawal notice.
  - No withdrawal was found. On Sept. 9, 2026 the FTC withdrew a *different* (health-app breach) policy statement: https://www.ftc.gov/news-events/news/press-releases/2026/09/ftc-withdraws-obsolete-policy-statement (V).
  - Its standing under current FTC leadership is **U**.
- **Confidence:** Medium.
- **Attorney:** NO (fold into the §5 review).

### 2.3 Negative Option / ROSCA (US, federal)

- **Applies?** **No, today.** The sale is a one-time license with no recurring charge.
  - ROSCA (15 U.S.C. §8403) applies to online negative-option features: disclose before billing, get express consent, provide simple cancellation.
  - The FTC's 2024 "Click-to-Cancel" amendments were vacated by the 8th Circuit (*Custom Communications v. FTC*, No. 24-3137, July 8, 2025; V2).
  - The FTC published an ANPRM to restart the rulemaking (~Mar. 2026; V on the FTC rule page; Federal Register citation U).
- **Trigger:** T, only if subscriptions, auto-renew or trial conversion are added.
- **Changes:** none now. If subscriptions are ever added, cancellation must be as easy as signup.
- **Source:** https://www.law.cornell.edu/uscode/text/15/8403 (V); https://www.ftc.gov/legal-library/browse/rules/negative-option-rule (V)
- **Confidence:** High.
- **Attorney:** NO.

### 2.4 COPPA (US, federal), 15 U.S.C. §6501 ff.; 16 CFR Part 312 as amended 2025

- **Applies?** **Probably not.**
  - The service is general-audience.
  - The developer collects nothing from the app. The COPPA FAQ says on-device data that "is never transmitted" is not collected.
  - Gumroad collects buyer data (buyers are adults paying by card).
- **Why it matters anyway:** the amended §312.2 "personal information" now includes biometric identifiers such as **voiceprints** and **facial templates** (V). Any future transmission of such data from a child would be squarely covered. "Operator" means one who "collects or maintains" personal information (V).
- **Trigger:** T: a child-directed service, or actual knowledge of collecting from a child, plus any transmission.
- **Changes:**
  - Don't market to children.
  - Add "not directed to children under 13" to the Terms and PRIVACY.md.
  - Keep camera, mic and voice data on-device.
- **Docs:** age statement.
- **Source:** https://www.law.cornell.edu/cfr/text/16/312.2 (V; no currency date shown); FAQ https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions (V). Federal Register dates of the 2025 amendments (published Apr. 22, 2025; compliance Apr. 22, 2026) are **U**.
- **Confidence:** Medium-high.
- **Attorney:** NO.

### 2.5 Massachusetts Wiretap Act, G.L. c.272 §99 (all-party knowledge): **critical for Meetings**

- **Applies?** **Yes, to users. Indirect exposure for the developer.**
  - "Interception" means "to secretly hear, secretly record, **or aid another to secretly** hear or secretly record" a wire or oral communication with an intercepting device. Recording is lawful only for someone given prior authority by all parties.
  - "Intercepting device" is anything "capable of ... recording": a capability test, so a Mac running Meetings qualifies.
  - "Oral communication" means "speech", with no expectation-of-privacy element.
- **Who is liable:**
  - The **user** who records without every participant's knowledge.
  - **Developer theories:**
    - "aid another to secretly record" sits in the definition of interception itself;
    - C1 "procures any other person";
    - C5 "permits an intercepting device to be used" for unlawful interception;
    - C6 "accessory".
    - All of these need intent or knowledge, and no case applying them to a general-purpose software vendor was found.
  - No manufacture or sale offense exists in §99 (unlike federal §2512).
- **"Secretly":** per *Commonwealth v. Jackson*, 370 Mass. 502 (1976), it means without actual knowledge (U: opinion not fetched; Justia returned 403). *Commonwealth v. Grimaldi*, SJC-13842 (June 2, 2026) reportedly held that visible notice can negate a willful *secret* interception (V2). **A caption only the recording user sees does not give the other parties knowledge.**
- **Penalties:**
  - Interception: up to 5 years and/or $10,000.
  - Possession or permitting (C5): up to 2 years and/or $5,000.
  - Civil (Q): actual damages, at least $100/day or $1,000, plus punitive damages and attorney fees.
- **Trigger:** **I** for users in MA, or with MA participants.
- **Obligations (user):** every participant's actual knowledge before recording.
- **Changes (developer, to stay far from "aid"):**
  1. **Blocking pre-record sheet** on every recording: "Everyone on this call knows it's being recorded", needing an explicit tap; optionally remembered per meeting, never globally.
  2. **Optional audible announcement** injected into the call ("This call is being recorded"). The audio injection is technically harder; a pasteable chat message is the fallback.
  3. A persistent menu-bar recording indicator.
  4. Never market Meetings as covert, background or "silent".
  5. Keep the "Tell everyone" text, but link to a help page on consent laws.
  6. Consider defaulting the "All system audio" source off, or warning that it captures every app.
- **Docs:** "Recording consent" help page; Terms clause making the user responsible for consent; incident log for any complaints.
- **Source:** https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99 (V)
  - Grimaldi: https://law.justia.com/cases/massachusetts/supreme-court/2026/sjc-13842.html (V2)
  - *Project Veritas Action Fund v. Rollins*, 982 F.3d 813 (1st Cir. 2020): as-applied invalidity limited to secretly recording officials in public; irrelevant to private calls (U).
- **Confidence:** High that the statute covers users' secret recordings; low-medium on developer secondary liability.
- **Attorney:** **YES.**

### 2.6 Other all-party-consent states (applies to users wherever any participant is located)

| State | Statute | Rule | Source / status |
|---|---|---|---|
| California | Penal Code §632 (confidential communications, all parties); §631 ("aids, agrees with, employs, or conspires"); §637.2 (greater of $5,000 per violation or 3× damages; no actual damages needed) | All-party consent for confidential communications | https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PEN&sectionNum=632. ; …=631. ; …=637.2. (V). §631 last amended 2022 (SB 1272). |
| Washington | RCW 9.73.030 | All parties' consent. An announcement to all parties, if itself recorded, counts as consent. **This supports the "announce in the call" design.** | https://app.leg.wa.gov/RCW/default.aspx?cite=9.73.030 (V) |
| Florida | Fla. Stat. 934.03 | Lawful only when all parties consent beforehand; violation is a third-degree felony | https://www.flsenate.gov/Laws/Statutes/2025/934.03 (V) |
| IL, MD, MT, NH, PA, CT (phone, civil), MI (ambiguous), OR (in-person), NV (phone) | 720 ILCS 5/14-2; Md. Cts. & Jud. Proc. 10-402; MCA 45-8-213; RSA 570-A:2; 18 Pa.C.S. 5703-5704; C.G.S. 52-570d; MCL 750.539c; ORS 165.540 | Mixed all-party rules | **U**: official pages not fetched (ilga.gov blocked; PA redirect) |

**CIPA vendor cases:**
- *Brewer v. Otter.ai* / *In re Otter.ai Privacy Litigation* (N.D. Cal. No. 5:25-cv-06911): a partial dismissal ruling was reportedly issued Aug. 13, 2026, with some CIPA, ECPA and BIPA claims surviving (**V2/U**). It concerns a *cloud* recorder that receives the audio. Humanity's local-only design is the key distinction.
- *Javier v. Assurance IQ* and *Graham v. Noom* (the "capability" test for whether a vendor is a third-party eavesdropper): **U**.
- CA **SB 690** (2025-26) reportedly narrowed to pen-register claims; signature status **U**.

**Changes:** same as 2.5. **Confidence:** High on the statutes; low on vendor-liability case law. **Attorney:** **YES.**

### 2.7 Federal Wiretap Act, 18 U.S.C. §2511 / §2512 / §2520 (one-party)

- **Applies?** **Yes, to users. Developer exposure is mainly §2512.**
  - §2511(2)(d): lawful when a party records or one party consents, **unless** the purpose is a "criminal or tortious act" under federal or *any State* law.
  - §2512: criminal to sell, ship or **advertise** a device the person knows or has reason to know is "primarily useful for the purpose of the surreptitious interception". A visibly operated meeting recorder is not, as long as it isn't built or marketed for stealth.
  - §2520 civil liability runs against the person or entity "which engaged in that violation". Greater of actual damages plus profits, or $100/day or $10,000; 2-year limitations period.
  - Secondary liability: *Doe v. GTE*, 347 F.3d 655 (7th Cir. 2003), found no aiding-and-abetting liability under §2520 (V2). *Luis v. Zang*, 833 F.3d 619 (6th Cir. 2016), found a spyware maker could be directly liable where its software routed captured communications to the **vendor's servers** (V2). Local-only design distinguishes it.
- **Trigger:** **I.**
- **Changes:** no stealth modes; never hide the app or indicator during recording; marketing copy review.
- **Source:** https://www.law.cornell.edu/uscode/text/18/2511 , /2512 , /2520 (V)
- **Confidence:** High on text; medium on vendor analysis.
- **Attorney:** **YES** (combine with 2.5).

### 2.8 Massachusetts Chapter 93A (consumer protection) and AG regulations

- **Applies?** **Yes, immediately.** An MA seller in trade or commerce.
  - §9: consumer suit after a 30-day written demand. Greater of actual damages or $25; **double to treble** if willful or knowing, or if the demand is refused in bad faith; attorney fees.
  - **940 CMR 3.13(4):** unfair or deceptive to fail to "clearly and conspicuously disclose to a buyer, prior to the consummation of a transaction" the refund, return or cancellation policy, or to misrepresent it or fail to honor it.
  - **G.L. c.106 §2-316A:** language excluding or modifying implied warranties of merchantability or fitness for **consumer goods** is "unenforceable". The MIT "AS IS" disclaimer may not hold against MA consumers *if* a software license is a "good". No MA case was found deciding that.
- **Trigger:** **I.**
- **Changes:**
  - Publish a refund policy on the Gumroad product page before purchase.
  - Add an end-user license/terms that keeps MIT for the source but carries a warranty and limitation clause drafted with MA §2-316A in mind.
  - Keep privacy claims accurate (a §5 violation is typically a 93A violation too; **U** on cross-reference, see 940 CMR 3.16).
- **Docs:** Terms of Sale/EULA; refund policy; record of 93A demand letters and responses (30-day clock).
- **Source:** https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section9 (V)
  - https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-13 (V; LII copy; mass.gov PDF not opened)
  - https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter106/Section2-316A (V)
- **Confidence:** High (93A, 3.13); low (whether §2-316A reaches software).
- **Attorney:** **YES.**

### 2.9 Massachusetts G.L. c.93H (breach notice) and 201 CMR 17.00 (WISP)

- **Applies?** **Probably not, on the current data.**
  - 93H "personal information" means name **plus** SSN, driver's license/state ID number, or financial account or credit/debit card number (V).
  - 201 CMR 17.00 binds persons who "own or license personal information about a resident" (V, mass.gov summary).
  - Gumroad data the developer receives is name, email, country and amount (Gumroad privacy policy: name, email, billing info). None of these is 93H "personal information" unless card or account numbers are present.
  - The app's license file holds only the key and a date.
- **Trigger:** T: holding any 93H data element (e.g. exporting Gumroad data that contains billing details).
- **Obligations if triggered:** written information security program (WISP); breach notice to the AG, OCABR and residents.
- **Changes:** don't download or store Gumroad exports with billing or card data; keep exports encrypted and minimal.
- **Docs:** a one-page "data inventory + minimal WISP" anyway (cheap, and useful for GDPR Art. 30-style records).
- **Source:** https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93H/Section1 (V)
  - https://www.mass.gov/regulations/201-CMR-1700-standards-for-the-protection-of-personal-information-of-residents-of-the-commonwealth (V, landing page; full PDF not read)
- **Confidence:** Medium-high.
- **Attorney:** NO (confirm in the general review).

### 2.10 Massachusetts comprehensive privacy bill (status Oct 1, 2026)

- **Status:** **Not enacted.**
  - S.2619 (Senate passed 40-0, Sept. 25, 2025).
  - H.5479 (House passed 146-0, June 4, 2026).
  - Senate non-concurred and a conference committee was appointed (June 11/17, 2026). The last bill-history entry is 6/17/2026.
  - Under new joint rules, bills in conference stay eligible for passage in a fall or year-end "pop-up" formal session (V2).
- **Why it matters:**
  - The House version would cover entities "collecting **any** sensitive data", which includes biometric data, regardless of volume, effective July 1, 2027.
  - The Senate version has volume thresholds (60k, or 20k + 20% of revenue), effective 2027 (V2 comparison).
  - The "collect" question in §1 becomes decisive.
  - Biometric bill S.43 is in Senate Ways & Means; H.4746 is in House Ways & Means. Neither is enacted.
- **Trigger:** T (if enacted).
- **Changes:** none now; watch the bill.
- **Source:** https://malegislature.gov/Bills/194/S2619 (V)
  - https://malegislature.gov/Bills/194/SD2204 (V)
  - https://malegislature.gov/Bills/194/H4746 (V)
  - https://foleyhoag.com/news-and-insights/blogs/state-ag-insights/2026/june/one-step-closer-to-a-massachusetts-data-privacy-law-comparing-the-current-house-and-senate-bills/ (V2)
  - https://aimnet.org/key-bills-remain-active-as-legislature-ends-formal-sessions/ (V2)
- **Confidence:** High on status as of the fetch.
- **Attorney:** NO (monitor).

### 2.11 Illinois BIPA, 740 ILCS 14

- **Applies?** **Likely not to the developer under G.T. v. Samsung (7th Cir. 2026).**
  - Voiceprints and "scan of hand or face geometry" are biometric identifiers (statutory text **U**: ilga.gov blocked automated access; G.T. quotes §15).
  - §15(a) duties attach to a private entity "in possession"; §15(b) to one that "collect[s], capture[s] … or otherwise obtain[s]". Both require control over the data (G.T.).
  - The developer has none.
- **Residual risks:**
  - (a) G.T. binds federal courts in the 7th Circuit, not Illinois state courts. *Barnett* (Ill. App.) agrees.
  - (b) **Third-party voiceprints:** the user, not the developer, "collects". Whether an individual user is a "private entity" exposed to suit is **U**.
  - (c) Any future access (sync, crash logs with embeddings) would change the analysis.
- **Damages:** P.A. 103-0769 (Aug. 2, 2024) limits recovery to one per person per collection method. The 7th Circuit held it retroactive in *Clay v. Union Pacific*, No. 25-2185 (Apr. 1, 2026) (V via FindLaw).
- **Trigger:** T: possession or control.
- **Changes:**
  - Opt-in voice profiles.
  - Consent attestation when naming a person.
  - Retention limit (e.g. auto-delete profiles unused for 12 months).
  - One-click delete and export.
  - No developer access, ever.
- **Docs:** a published biometric data retention and destruction policy (§15(a)-style). Not required of a non-possessor, but cheap, and doubles for Colorado.
- **Source:** G.T. (V, URL in §1)
  - Clay: https://caselaw.findlaw.com/court/us-7th-circuit/118259102.html (V)
  - BIPA text: https://www.ilga.gov/legislation/ilcs/ilcs3.asp?ActID=3004&ChapterID=57 (U)
- **Confidence:** Medium-high for the current design.
- **Attorney:** **YES** (third-party voiceprint and user-as-defendant questions).

### 2.12 Texas CUBI, Bus. & Com. Code §503.001

- **Applies?** **Probably not to the developer.**
  - "Biometric identifier" includes **voiceprint** and "record of hand or face geometry".
  - "A person may not capture a biometric identifier … for a commercial purpose" without informing the individual and getting consent.
  - Destroy within a reasonable time, no later than one year after the purpose expires; $25,000 per violation; **AG-only enforcement** (V).
  - Amended by H.B. 149 (2025), effective Jan. 1, 2026 (V).
  - The user captures; the developer doesn't. "Commercial purpose" is undefined in the section.
- **Trigger:** T: capture for a commercial purpose.
- **Changes:** same as BIPA. A **retention cap** (e.g. ≤ 1 year after last use) lines up with §503.001(c)(3).
- **Source:** https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm (V)
  - Texas AG settlements with Meta (2024) and Google (2025): **U**, press releases not fetched.
- **Confidence:** Medium.
- **Attorney:** **YES** (business users in Texas recording meetings for a commercial purpose).

### 2.13 Washington RCW 19.375 (biometric identifiers)

- **Applies?** **Probably not.**
  - Bars a person from enrolling a biometric identifier "in a database for a commercial purpose" without notice, consent, or an opt-out mechanism (V).
  - The developer enrolls nothing; the user's local profiles file is arguably the user's database.
  - AG-only enforcement: **U** (enforcement section not fetched).
- **Trigger:** T.
- **Changes:** consent attestation (as above).
- **Source:** https://app.leg.wa.gov/RCW/default.aspx?cite=19.375.020 (V)
- **Confidence:** Medium.
- **Attorney:** NO (fold into the biometric review).

### 2.14 Washington My Health My Data Act, RCW 19.373

- **Applies?** **Uncertain. This is the biggest US "means" risk.**
  - "Biometric data" that "identifies a consumer" is consumer health data.
  - "Collect" is very broad: access, derive, process.
  - A "regulated entity" is one that "alone or jointly with others, determines the purpose **and means**" (V).
  - Small business is defined (under 100k consumers, etc.), but that only changes timing.
  - Private right of action through the Consumer Protection Act, RCW 19.86: **U**, section not fetched.
  - Strong argument: the developer determines no purpose and touches no data. Counter-argument: designing the software sets the "means".
- **Trigger:** T (regulated entity status), with no revenue floor.
- **Obligations if covered:** a consumer health data privacy policy linked on the homepage; separate consent to collect and to share; signed authorization to sell (**U**, text not fetched).
- **Changes:**
  - Publish a short "Consumer Health Data Privacy Policy" stating that no consumer health data is collected by the developer and describing on-device processing. Low cost.
  - Keep voiceprints opt-in with consent prompts.
- **Source:** https://app.leg.wa.gov/RCW/default.aspx?cite=19.373.010 (V)
- **Confidence:** Low-medium.
- **Attorney:** **YES.**

### 2.15 Colorado biometric amendment, HB24-1130 (C.R.S. 6-1-1314)

- **Applies?** **Uncertain.**
  - Applies to a **controller** that "controls or processes one or more biometric identifiers", i.e. **any amount**. Effective July 1, 2025; signed May 31, 2024 (V).
  - Requires a written policy (retention schedule, incident response, deletion deadlines) and notice and consent before collection (V).
  - Whether a vendor of local-only software is a "controller" (determines purposes and means, C.R.S. 6-1-1303) is untested. The definition text is **U**.
- **Trigger:** T (controller status), no volume floor.
- **Changes:** publish the biometric policy from 2.11; consent prompts.
- **Source:** https://leg.colorado.gov/bills/hb24-1130 (V)
- **Confidence:** Low-medium.
- **Attorney:** **YES.**

### 2.16 Other state comprehensive privacy laws (mostly threshold-based)

The developer's only personal data is Gumroad customer data. Volume thresholds won't be met for years. **Two no-threshold traps:** Connecticut's sensitive-data prong and Texas's small-business sale ban.

| Law | Threshold (key prong) | Biometric = sensitive? | Effect here | Source |
|---|---|---|---|---|
| CCPA/CPRA (CA) | Gross revenue > **$26,625,000** (2025 CPI adjustment, applied in odd years); other prongs (100k consumers; 50% of revenue from selling/sharing) **U** | Yes (**U** cite) | N/A at current scale | https://cppa.ca.gov/regulations/cpi_adjustment.html (V) |
| Virginia VCDPA §59.1-576 | ≥100,000 consumers, or ≥25,000 + >50% of revenue from sales | Yes (**U**) | N/A | https://law.lis.virginia.gov/vacode/title59.1/chapter53/section59.1-576/ (V) |
| **Connecticut CTDPA** as amended by **PA 25-113 (SB 1295), eff. July 1, 2026** | ≥35,000 consumers, **or "control or process consumers' sensitive data"** (excluding payment-only data), or sells personal data | Yes: "genetic or biometric data **or information derived therefrom**". The definition excludes photos and recordings unless "generated to identify a specific individual" | **Live question.** If the developer were deemed to "process" on-device voiceprints, there is no volume floor. Same control analysis as §1. | https://www.cga.ct.gov/2025/ACT/PA/PDF/2025PA-00113-R00SB-01295-PA.PDF (V) |
| Colorado CPA §6-1-1304 | 100k, or 25k + revenue from sales (**U**) | Yes | N/A (but see 2.15) | **U** |
| **Texas TDPSA** §541.002 | Applies only to persons that are **not** SBA small businesses. **§541.107:** a small business "may not engage in the sale of personal data that is sensitive data without receiving prior consent". AG exclusive | Yes (**U** cite) | N/A unless you **sell** data. Don't. | https://statutes.capitol.texas.gov/Docs/BC/htm/BC.541.htm (V) |
| MD (MODPA, eff. Oct 1, 2025), NE (small-business rule like TX), OR, MT, MN, NJ, DE, NH, IN/KY/RI (Jan 1, 2026), TN, IA, UT | Various (mostly 35k-100k consumers; MD has strict sensitive-data necessity rules) | Yes | N/A at scale; Nebraska's TX-style rule is the only small-seller hook | **U** (not fetched) |

- **Changes:** never sell or share customer data; no ad pixels on any download site.
- **Docs:** a privacy notice covering customer and license data.
- **Confidence:** High for CA, VA and TX text; medium for CT application.
- **Attorney:** **YES** (CT sensitive-data prong only).

### 2.17 GDPR / UK GDPR (international launch)

- **Applies?** **Yes, for the developer's own customer and license data once EU/UK consumers are targeted. No, for on-device content.**
  - Art. 3(2)(a): applies to non-EU controllers offering goods or services to people in the EU. Recital 23 says "envisaging" offers to EU residents is the test (V).
  - Gumroad's privacy docs say **the seller is the data controller** and Gumroad acts as processor under a DPA incorporated into its Terms. Gumroad has appointed no Art. 27 representative for sellers (V). Gumroad's ToS separately calls it merchant of record for tax; this hybrid framing is worth confirming.
  - **Art. 27(2)(a):** no EU representative is needed for occasional processing that is not large-scale Art. 9 data and is unlikely to pose a risk (V). Plausible here, but steady sales may not be "occasional".
  - **Household exemption** (Art. 2(2)(c); Recital 18): covers a *user's* purely personal recordings. The CJEU construes it narrowly (*Ryneš*, C-212/13, paras 29, 33; V). **Work meetings are not household activity**, so the user or their employer is the controller and needs an Art. 9(2) basis (e.g. explicit consent) for third-party voiceprints, which are "biometric data for the purpose of uniquely identifying" (Art. 4(14), Art. 9(1); V).
  - **Art. 25** (privacy by design) binds controllers, not tool makers. Recital 78 only "encourages" producers (V).
  - The GDPR "Digital Omnibus" (procedure 2025/0360(COD)) is **not adopted**; still in first reading as of the Aug. 1, 2026 EP update (V).
- **Trigger:** **T:** when EU/UK sales are targeted (EU currency or language, EU marketing).
- **Obligations (developer):**
  - Privacy notice (Arts. 13/14) for customer and license data.
  - Lawful basis: contract.
  - Data subject rights handling.
  - Records.
  - Confirm the DPA with Gumroad.
  - Art. 27 assessment.
- **Changes:**
  - Ship features that let *users* comply: opt-in voice profiles with an "I have this person's explicit consent" attestation, per-profile deletion, retention timer, export.
  - Warn that work recordings are not personal use.
- **Docs:** GDPR privacy notice; Art. 27 decision memo; DPA confirmation.
- **UK:** UK GDPR and DPA 2018 mirror the above. Data (Use and Access) Act 2025 commencement status **U**. ICO biometric guidance URL **U**. Check https://www.legislation.gov.uk/ukpga/2025/18/contents.
- **Source:** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679 (V)
  - https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:62013CJ0212 (V)
  - https://gumroad.com/privacy (V)
  - https://gumroad.com/help/article/349-gdpr-data-requests (V)
  - https://www.europarl.europa.eu/legislative-train/theme-a-new-plan-for-europe-s-sustainable-prosperity-and-competitiveness/file-digital-package (V)
- **Confidence:** Medium-high.
- **Attorney:** **YES** (before the EU/UK launch).

### 2.18 EU AI Act (Reg. 2024/1689, as amended by Reg. 2026/1744) (international)

- **Applies?** **Possibly, to the voice-profile feature.**
  - "Remote biometric identification system" means identifying people "without their active involvement, typically at a distance" by comparison with a reference database. Recital 17 says it is technology-neutral, which covers voice (V).
  - Annex III 1(a) lists RBI (excluding verification) as **high-risk**.
  - Art. 2(12): the free/open-source exclusion does not hold where the system is placed on the market as high-risk. Recital 103 says FOSS components "provided against a price or otherwise monetised" don't get the FOSS exceptions (V). **A paid Gumroad license likely makes the developer a "provider".**
  - Art. 2(10) shields only individual users in personal, non-professional use (V).
  - **Dates:** the Digital Omnibus on AI (Reg. 2026/1744, in force July 27, 2026; V) moved Annex III high-risk obligations to **Dec. 2, 2027**.
  - Gaze and gesture tracking are not emotion recognition (Art. 3(39)) unless emotions or intentions are inferred.
- **Trigger:** **T:** EU market placement and the high-risk date.
- **Changes:**
  - Before any EU launch, either drop *cross-meeting* voice recognition for EU builds (diarize with "Speaker 1/2" labels only), or plan for high-risk provider duties (risk management, technical documentation, conformity assessment). The first is far cheaper.
  - Never add emotion or attention inference from gaze for workplace or education use (Art. 5(1)(f)).
- **Source:** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R1689 (V); https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng (V)
- **Confidence:** Medium (the RBI classification of a small, user-curated meeting database is arguable).
- **Attorney:** **YES.**

### 2.19 EU Cyber Resilience Act (Reg. 2024/2847) (international)

- **Applies?** **Likely, once the developer sells in the EU.**
  - Supply "in the course of a commercial activity" includes "charging a price for a product with digital elements". So the FOSS carve-out is lost for the paid build (recital text, V).
  - **Art. 14 reporting obligations (actively exploited vulnerabilities, severe incidents) apply from Sept. 11, 2026.** Full application is Dec. 11, 2027 (final provisions, V; article number not checked).
- **Trigger:** **T:** making the product available on the EU market. Already relevant if any EU buyer can purchase today.
- **Obligations:** from 2026, report actively exploited vulnerabilities and incidents to the CSIRT/ENISA platform. From 2027: security-by-design requirements, vulnerability handling, SBOM, CE marking, conformity assessment (default class; **U**).
- **Changes:** SECURITY.md already has a disclosure path. Add an SBOM (FluidAudio, models), signed and notarized builds, and a documented update channel.
- **Source:** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R2847 (V)
- **Confidence:** Medium.
- **Attorney:** **YES.**

### 2.20 EU/UK consumer contract rules (international)

- **EU CRD 2011/83/EU Art. 16(m):** the 14-day withdrawal right is lost for non-tangible digital content once performance begins, **only if** the consumer gave prior express consent, acknowledged losing the right, and got confirmation (V, consolidated text). Gumroad, as merchant of record, runs the checkout; confirm it captures this consent.
- **UK:** Consumer Contracts Regs 2013 reg. 37 / Consumer Rights Act 2015 digital content (**U**).
- **European Accessibility Act** (Dir. 2019/882): likely N/A to a standalone app; microenterprise services exemption (**U**).
- **Attorney:** NO (ask Gumroad support; confirm in the GDPR review).

### 2.21 Accessibility: ADA and related

- **Applies?** **Generally no, to the software as a product.**
  - ADA Title II covers state and local governments. DOJ's 2024 web and mobile-app rule binds public entities; ada.gov reports an interim final rule (Apr. 20, 2026) moving the large-entity deadline to Apr. 26, 2027 (V on ada.gov; FR citation U). It matters only if universities or agencies buy Humanity and impose accessibility contract terms.
  - Title III's reach to websites and apps is split across circuits (*Robles v. Domino's*, 9th Cir. 2019; *Gil v. Winn-Dixie*, 11th Cir., vacated). No authority was found applying it to downloadable software sold as such (**U**).
  - Section 508 binds federal procurement only (**U**).
- **Trigger:** T (procurement contracts).
- **Changes:** VoiceOver labels and keyboard access in the app UI. An accessibility statement *without* compliance claims (see accessiBe in 2.1).
- **Source:** https://www.ada.gov/resources/2024-03-08-web-rule/ (V)
- **Confidence:** Medium.
- **Attorney:** NO.

### 2.22 FDA device status (material for an assistive input tool)

- **Applies?** **Only if marketed for a medical purpose.**
  - 21 CFR 890.3710 (powered communication system) and 890.3725 (powered environmental control system) are Class II, 510(k)-exempt subject to §890.9. Both are defined by intended medical purpose (V).
  - General "control your Mac with eyes, hands, voice" framing likely isn't a device claim. "For ALS or paralysis patients" or therapy claims could be.
- **Trigger:** T (intended-use claims).
- **Changes:** marketing copy rule: no disease, patient or therapeutic claims.
- **Source:** https://www.law.cornell.edu/cfr/text/21/890.3710 ; https://www.law.cornell.edu/cfr/text/21/890.3725 (V). FDA software and general wellness guidance: **U**.
- **Confidence:** Medium-low.
- **Attorney:** **YES** (only before any disability-targeted marketing).

### 2.23 Export controls (EAR) and sanctions (OFAC)

**EAR:**
- Published software is not subject to the EAR (15 CFR 734.3(b)(3), 734.7(a)(4): posting on public Internet sites). **Current §734.7 has no "price not exceeding cost of reproduction" test.** That language was removed in 2016, so a paid license doesn't by itself defeat "published" status (V, eCFR current as of 2026-09-29).
- Publicly available encryption source code is not subject to the EAR; notice to BIS/NSA is required only for "non-standard cryptography" (742.15(b), as revised by 86 FR 16482, Mar. 29, 2021; V).
- Humanity uses only OS-provided TLS. Whether calling OS crypto makes it an "encryption item" at all: **U**.
- **Fallback:** if treated as subject to the EAR, it is 5D992.c mass market (740.17(b)(1)). After 2021 the annual self-classification report covers only mass-market components and "executable software", not ordinary apps (740.17(e)(3); V). Keep an internal self-classification memo anyway; the Note to 740.17(b) ties "publicly available" status to classification.
- **Russia/Belarus (746.8):** 5D992.c items need a license except for listed corporate and diplomatic end users. There is **no consumer mass-market exception** (V). This matters only if the binary is treated as subject to the EAR.

**OFAC:**
- Active programs include Cuba, Iran, North Korea, Ukraine/Russia-related, and Syria as "PAARSS" (a targeted program) (V, OFAC program list).
- Whether the comprehensive Syria embargo regulations were removed in 2025: **U**. Iran GL D-2 (personal communications software): **U**.
- Gumroad's Terms bar export to embargoed countries and listed persons (§27.13) and allow KYC screening (§4.2) (V).

- **Trigger:** **I** (any foreign sale or download).
- **Changes:**
  - Confirm with Gumroad which countries checkout blocks.
  - Add a Terms clause: buyer is not in an embargoed region or on the SDN list.
  - Don't sell to Cuba, Iran, North Korea, Crimea/"DNR"/"LNR"; handle Russia/Belarus conservatively.
- **Docs:** export self-classification memo (EAR99 or 5D992.c, rationale, date).
- **Source:** https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-734/section-734.7 , …/section-734.3 , …/part-742/section-742.15 , …/part-740/section-740.17 , …/part-746/section-746.8 (V via eCFR API)
  - https://www.federalregister.gov/documents/2021/03/29/2021-05481/ (V)
  - https://ofac.treasury.gov/sanctions-programs-and-country-information (V)
  - https://gumroad.com/terms (V)
- **Confidence:** Medium-high (EAR); medium (OFAC).
- **Attorney:** **YES** (short export memo review).

### 2.24 Sales tax / VAT

- **Gumroad as merchant of record (MoR):**
  - Gumroad is the "merchant of record" and "non-exclusive reseller". It is "treated as the seller" for indirect tax and collects and remits sales tax, VAT and GST worldwide (ToS §§1.1, 6.1, 6.2(e), 10.2; effective Jan. 1, 2025; last updated Sept. 14, 2026, binding existing accounts Oct. 14, 2026) (V).
  - Sellers who already file returns report Gumroad sales as "sales to other retailers for purposes of resale" and keep Gumroad's Reseller Certificate (V).
  - The seller keeps direct (income) tax duties (§10.6) (V).
  - 1099-K comes from Gumroad (via Stripe) only above $20,000 **and** 200 transactions (V). MA's state 1099-K threshold: **U**.
- **Massachusetts:**
  - 830 CMR 64H.1.3(3)(a): sales of prewritten software are taxable "regardless of the method of delivery, including electronic delivery", including licenses (V).
  - Marketplaces must collect for marketplace sellers once the marketplace's MA sales exceed $100,000 (V).
  - With Gumroad as reseller, the developer's sale is arguably a sale for resale (Reseller Certificate). Whether an in-state MA seller selling only through Gumroad must still register with DOR: **U**.
- **Trigger:** **I** (income tax); T (registration).
- **Changes:** none in product.
- **Docs:** keep the Gumroad Reseller Certificate; annual income records.
- **Source:** https://gumroad.com/terms ; https://gumroad.com/help/article/121-sales-tax-on-gumroad ; https://gumroad.com/help/article/10-dealing-with-vat ; https://gumroad.com/help/article/15-1099s (V)
  - https://www.mass.gov/regulations/830-CMR-64h13-computer-industry-services-and-products (V)
  - https://www.mass.gov/info-details/remote-seller-and-marketplace-facilitator-faqs (V)
- **Confidence:** High (Gumroad MoR); medium (MA registration).
- **Attorney:** **YES**, or a CPA, for MA registration and income tax.

### 2.25 Consumer refunds

- **US federal:** no general refund mandate was found.
  - FTC Mail/Internet Order Rule (16 CFR 435) is keyed to "shipment" (physical placement with a carrier). Likely N/A to instantly delivered license keys (V on text; no FTC staff view found).
  - Magnuson-Moss covers tangible "consumer products"; software status **U**.
- **MA:** 940 CMR 3.13(4) requires disclosing the refund policy **before** purchase (see 2.8).
- **Gumroad:**
  - Handles refunds and disputes "in Gumroad's sole discretion"; the seller reimburses (ToS §7.1).
  - Sellers set their own policy, but Gumroad may refund within 90 days to prevent chargebacks.
  - Brazil: 7-day withdrawal.
  - Over 1% disputes triggers an enforced 30-day guarantee account-wide (V).
- **EU:** 14-day withdrawal unless the Art. 16(m) waiver is captured (2.20).
- **App behavior:** refunded, chargebacked or disputed keys stop working at the next weekly re-check, with a 60-day offline grace (`License.swift`). **Disclose this** in the refund policy.
- **Changes:** set a Gumroad custom refund policy (e.g. 14 or 30 days, no questions asked); show it on the product page; state the key-revocation behavior.
- **Source:** https://gumroad.com/help/article/51-what-is-gumroads-refund-policy ; https://gumroad.com/help/article/335-custom-refund-policy (V)
  - https://www.law.cornell.edu/cfr/text/16/435.1 (V)
- **Confidence:** Medium-high.
- **Attorney:** NO.

### 2.26 Trademark sanity check (NOT clearance)

Method:
- USPTO Trademark Search (https://tmsearch.uspto.gov), word search, 2026-10-01.
- Only **LIVE marks in Classes 9/42** on the **first 50 results** were reviewed.
- No phonetic, design, state, common-law or foreign search.

| Name | Notable LIVE USPTO marks found (serial, owner, class) | Conflict view |
|---|---|---|
| **OculOS** | No live OCULOS marks (the 5 hits are dead or unrelated). **OCULUS:** 86757871 Meta Platforms, IC 9 "Virtual reality software; VR computer hardware…"; 86757882 Meta, IC 28 VR headsets; **85909459 Oculus Optikgeräte GmbH, IC 9/10/42, physical and optical (ophthalmic) apparatus**; 86362507 J. R. Systems, IC 9/42 software | **HIGH.** One letter from OCULUS, near-identical sound, and related goods (head/eye tracking software; ophthalmic eye devices). Meta enforces actively (**U**). Strongest rename candidate. |
| **Humanity** | 86131356 **HUMANITY.COM INC.**, IC 42 SaaS; 88918140 Humanity Health Inc., IC 5/9/10/41/42/44 incl. downloadable software; 88732793 tha ltd., IC 9 game programs. 477 total hits. "Humanity Protocol" not checked | **MEDIUM-HIGH.** Identical word in Classes 9/42 for software. The scheduling SaaS mark is in a different field, but Class 42 overlap matters. |
| **Murmur** | 87240988 Daniel Akira Max, IC 9/45 downloadable mobile applications; 99682054 (pending) IC 42 game software; EMURMUR 86640605 IC 9 medical exam systems; MURMMOR 99801504 (pending) IC 9/42 app. Mumble's open-source "Murmur" server (common law): **U** | **MEDIUM.** Identical word for downloadable apps (live registration). |
| **ManOS** | No live Class 9/42 MANOS marks on page 1 of 142 results | **LOW-MEDIUM** (incomplete search; "manOS" may also read as an OS name) |

- **Changes:** pause brand spend on OculOS; get a clearance search before registering or marketing internationally.
- **Docs:** clearance opinion; record of first-use dates.
- **Source:** https://tmsearch.uspto.gov (V, results as listed); TSDR records not opened.
- **Confidence:** Low-medium (screening only).
- **Attorney:** **YES.**

### 2.27 CFAA, 18 U.S.C. §1030 (input automation)

- **Applies?** **Negligible developer exposure.**
  - ManOS, Murmur and OculOS synthesize input on the user's *own* Mac with the user's Accessibility grant.
  - *Van Buren v. United States*, 593 U.S. 374 (June 3, 2021): "exceeds authorized access" is a "gates-up-or-down inquiry" about access to areas of a computer, not misuse of permitted access (V).
  - A user automating a third-party site against its terms is mainly a contract issue (*hiQ v. LinkedIn*, 9th Cir. 2022: **U**). Mass. G.L. c.266 §120F: **U**.
  - The app already respects Secure Event Input (no paste into password fields), which also helps on §5 unfairness.
- **Trigger:** none for the developer.
- **Changes:** don't add features that bypass security prompts, CAPTCHAs or other apps' protections; keep the Secure Event Input back-off.
- **Source:** https://www.law.cornell.edu/supremecourt/text/19-783 (V)
- **Confidence:** High.
- **Attorney:** NO.

### 2.28 Other material items

| Item | Why it matters | Status |
|---|---|---|
| **Third-party ML licenses** | Diarization models (pyannote/WeSpeaker via FluidAudio) are CC BY 4.0 and attributed in THIRD_PARTY_NOTICES.md. The optional OculOS CNN script downloads MobileGaze weights; the datasets they were trained on may carry non-commercial terms. They are **not shipped**; users build them. | **U** dataset terms. Don't bundle those weights in a paid build without review. |
| **Cloud LLM transfers of third-party content** | Meeting transcripts and speaker names go to providers the user picks. The user is controller; the developer's duty is accurate disclosure. | Add an in-app note on the AI Providers screen that meeting content includes other people's words. |
| **Sole-proprietor liability** | 93A, wiretap and §5 claims run against the individual. | Business question: consider an LLC and insurance (attorney). |
| **Notarization / Gatekeeper** | Not law, but tied to the §5 security posture and CRA readiness. | Planned. |

---

## 3. Top 10 risks (ranked) and implied changes

| # | Risk | Laws | Product / doc changes |
|---|---|---|---|
| 1 | **Users secretly recording calls with Meetings** in all-party states (MA, CA, FL, WA…); developer pulled in on "aid / procure / permit" or §2512 theories; reputational and FTC unfairness exposure | c.272 §99; CA PC 631/632/637.2; RCW 9.73.030; Fla. 934.03; 18 U.S.C. 2511/2512/2520 | Blocking per-recording consent confirmation; optional in-call announcement or pasteable notice; persistent indicator; no stealth features or marketing; consent help page; Terms clause putting consent on the user |
| 2 | **Voiceprints of third parties enrolled silently** | BIPA, CUBI, RCW 19.375, MHMDA, CO 6-1-1314, CT sensitive data, GDPR Art. 9, AI Act RBI | Voice profiles **off by default**; "I have <Name>'s consent" attestation when naming; retention cap (≤12 months unused); per-profile delete and export; published biometric retention policy |
| 3 | **Privacy claims drift from code** | FTC §5; 93A | CI network-call guard; claims log; fix "only derived numbers" (eye patches); disclose Gumroad response fields and LLM transfer of third-party speech; hash-pin model downloads |
| 4 | **Architecture change voids the "no possession / no control" position** | G.T. v. Samsung control test; MHMDA "collect"; COPPA | Policy: no telemetry, sync, crash payloads or hosted features touching sensor or voice data without legal review; document the "developer cannot access" design |
| 5 | **EU/UK launch duties**: CRA reporting already live from Sept. 11, 2026; AI Act high-risk (Dec. 2, 2027); GDPR for customer data; withdrawal-right consent | CRA; AI Act; GDPR/UK GDPR; CRD 16(m) | EU build without cross-meeting voice ID, or a high-risk plan; SBOM and vulnerability process; GDPR notice and Art. 27 memo; confirm Gumroad's withdrawal-waiver capture |
| 6 | **Trademark conflict**, esp. OculOS vs OCULUS (Meta; Oculus Optikgeräte eye devices) | Lanham Act (not researched in depth) | Clearance search; consider renaming OculOS before marketing spend; check HUMANITY and MURMUR |
| 7 | **MA consumer-law gaps**: no pre-sale refund disclosure; MIT "AS IS" may not bind MA consumers | 93A §9; 940 CMR 3.13(4); c.106 §2-316A | Gumroad refund policy on the product page; EULA/Terms of Sale; key-revocation disclosure |
| 8 | **WA MHMDA / CO / CT "means"-based coverage** with no volume floor and, in WA, private suits | RCW 19.373; C.R.S. 6-1-1314; CTDPA §42-516 | Publish a consumer health data / biometric statement; keep data inaccessible to the developer; attorney opinion on "controller" status |
| 9 | **Export and sanctions on direct sales** | EAR 734/742/746.8; OFAC | Self-classification memo; Gumroad country blocks; Terms sanctions clause |
| 10 | **Marketing claims**: accessibility compliance or medical use | FTC §5 (accessiBe); FDA 890.3710/3725 | Copy rules: no "ADA/WCAG compliant", no disease or patient claims; accessibility statement framed as goals |

---

## 4. Questions for an attorney

1. **Wiretap:** Could a developer of a local-only meeting recorder face civil or criminal exposure under G.L. c.272 §99 ("aid another to secretly record", C1 "procures", C5 "permits", C6 "accessory") or CA PC §631 ("aids") when a user records without notice? Do a blocking consent confirmation and an optional in-call announcement materially reduce that exposure?
2. Is an in-call spoken announcement (recorded) enough for all-party states in general, as RCW 9.73.030(3) suggests for Washington? What wording works across MA, CA, FL, IL, PA and MD?
3. **BIPA:** After *G.T. v. Samsung* (7th Cir. 2026), how likely is an Illinois *state* court to treat the developer as "in possession" of locally stored third-party voiceprints? Can an *individual user* be a defendant as a "private entity"?
4. **WA MHMDA / Colorado 6-1-1314 / CT CTDPA:** Is a vendor of local-only software a "regulated entity" or "controller" because it designs the "means"? Is a published statement enough, or are formal policies and consent flows needed now?
5. **Texas CUBI:** Does a business user's capture of meeting participants' voiceprints count as "for a commercial purpose", and could Texas AG attention reach the vendor?
6. **Massachusetts:** Does G.L. c.106 §2-316A void the MIT "AS IS" implied-warranty disclaimer for consumer buyers of a paid license key? What Terms of Sale/EULA structure keeps the code MIT while managing consumer warranty exposure?
7. Does the developer need to register with MA DOR as a vendor when every sale goes through Gumroad as merchant of record and reseller?
8. **EU:** Is cross-meeting speaker recognition a "remote biometric identification system" (Annex III 1(a)) for a paid open-source app? Would the Art. 6(3) derogation apply? Is the developer a CRA "manufacturer" now, triggering Art. 14 reporting since Sept. 11, 2026, if any EU buyer can purchase?
9. **GDPR:** Is an Art. 27 representative needed given Gumroad's "seller is controller" framing? What notice is needed for license verification, given that Gumroad's verify response returns buyer email and IP country to the app?
10. **Trademark:** Full clearance for HUMANITY, OCULOS, MANOS, MURMUR in Classes 9/42 (US, EU, UK), and how serious the risk is from Meta's OCULUS and Oculus Optikgeräte's marks.
11. **Export:** Confirm EAR "published" status for the free binary unlocked by a paid key; check the Russia/Belarus and comprehensive-embargo posture for direct sales; confirm what Gumroad blocks.
12. **Entity and insurance:** LLC formation and media/tech E&O cover, given wiretap and biometric class-action trends.

---

## 5. Not verified in this pass (do before relying on it)

- BIPA statute text (ilga.gov blocked automated access).
- *Jackson*, *Hyde*, *Grimaldi*, *Du*, *Rios* opinion texts.
- *Project Veritas v. Rollins*.
- *Javier* and *Graham* (CIPA capability test).
- The *Otter.ai* order.
- CA SB 690 signature status.
- All-party state table rows marked U.
- FTC biometric statement practice list (ftc.gov was down).
- COPPA amendment Federal Register dates.
- ADA Title III case law; Section 508.
- FDA software and general wellness guidance.
- Magnuson-Moss software status.
- UK DUAA commencement; ICO biometric guidance.
- EDPB 3/2018; CJEU C-25/17.
- EAA scope.
- OFAC: Syria comprehensive-embargo regulations and Iran GL D-2.
- EAR: whether OS-provided TLS makes the app an "encryption item".
- Texas AG settlement URLs.
- Colorado C.R.S. 6-1-1303 definition text.
- MD, OR, MT and the other state thresholds.
- Mass. c.266 §120F; *hiQ*.
- MA 1099-K threshold; MA DOR registration for in-state marketplace sellers.
- Common-law "Murmur" (Mumble).
- TSDR detail for listed serials.
