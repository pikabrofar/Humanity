# 02 - Recording-consent laws (US states) and AI note-taker / transcription litigation

Prepared 2026-10-01 by a research analyst (not a lawyer; nothing here is legal advice or a statement that any design is "compliant" or "safe"). Applies to Humanity (Murmur Meetings / MeetingKit: mic + other-app audio, on-device diarization, voiceprint "voice profiles" of named non-users; developer = one individual in Massachusetts; no servers; AIKit optionally sends transcript TEXT to a third-party LLM using the user's own key).
Legend: [V] = primary text fetched this session. [S] = only secondary sources (law-firm/news/tracker pages) seen; verify before relying. [U] = from my background knowledge, not re-verified.

## 0. Bottom line

1. Who is exposed depends on who "records". In Humanity the USER's Mac records; the developer never receives audio. The statutes below primarily bind the person who records (the Humanity user, who may be in a different state from the other participants). Developer exposure is secondary: (a) aiding/abetting or "procuring" clauses (Massachusetts c.272 s.99 expressly reaches one who "aid[s] another to secretly ... record" [V], and the developer lives in MA); (b) deceptive marketing ("invisible", "undetectable") that plaintiffs now plead as intent (Granola complaint [S]); (c) voiceprint statutes (BIPA etc.) if the developer is ever deemed to "collect/possess" voiceprints.
2. The 2025-26 AI-notetaker suits (Otter, Granola, Google CCAI) rest on a vendor receiving and using content on ITS servers ("independently collects, retains, and uses communications for its own commercial purposes" - Otter order [S via FindLaw summary]). A local-only recorder whose vendor never receives audio is factually outside that core theory. That is a design fact to preserve and document, not a guarantee: plaintiffs can still sue on aiding/abetting, deceptive-design, or UCL theories, and courts decide "third party" on pleadings.
3. Biggest residual risks: (i) user-recorded all-party-consent calls without disclosure (user liability; developer aiding claims, esp. MA); (ii) voiceprints of non-users (BIPA/TX/WA/CO etc.); (iii) any future cloud feature (sync, crash upload, "cloud transcription") that would flip the analysis.

## 1. All-party (or hybrid) consent states

Federal baseline: one-party consent, 18 U.S.C. 2511(2)(d), except where interception is "for the purpose of committing any criminal or tortious act" (https://www.law.cornell.edu/uscode/text/18/2511) [U for text; the tortious-purpose carve-out is quoted as applied in the Otter order, S]. State law that is stricter controls the call if any participant is in that state (conflict-of-laws is unsettled; Kearney v. Salomon Smith Barney, 39 Cal.4th 95 (2006) applied CA law to out-of-state-to-CA calls, https://law.justia.com/cases/california/supreme-court/2006/s124739.html [U]).

| State | Statute (official/primary URL) | Consent rule (what I verified) | Penalties / civil | Notes |
|---|---|---|---|---|
| CA | Pen. Code 632, https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PEN&sectionNum=632 [V]; 631 ...sectionNum=631 [V]; 632.7 ...sectionNum=632.7 [V]; 637.2 ...sectionNum=637.2 [V] | 632(a): intentionally, "without the consent of all parties to a confidential communication", uses recording device. "Confidential" = circumstances reasonably indicating a party wants it confined to parties (632(c)). 632.7: cellular/cordless calls, no confidentiality element. 631(a): wiretap, read/learn contents in transit, use info so obtained, aid/abet. | Criminal: up to $2,500 per violation / 1 yr (repeat $10,000). Civil 637.2: greater of $5,000 per violation or 3x actual damages; injunction; no actual-injury prerequisite. 632(d): evidence inadmissible. | 632 last amended 2016 (AB 1671), 632.7 in 2022 (SB 1272). See sec. 2 for SB 690 (2026). |
| FL | Fla. Stat. 934.03(2)(d), http://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0900-0999/0934/Sections/0934.03.html [V] | Lawful only "when all of the parties ... have given prior consent". | Generally third-degree felony (934.03(4)); civil 934.10 (statutory amounts not verified [U]: greater of actual or $100/day or $1,000). | Applies to oral communications with reasonable expectation of privacy (934.02(2) [U]). |
| IL | 720 ILCS 5/14-2, https://www.ilga.gov/legislation/ilcs/fulltext.asp?DocName=072000050K14-2 [fetch failed - cert error; U] | Eavesdropping: surreptitiously recording a "private conversation" without consent of all parties (2014 rewrite after People v. Melongo/Clark). | Class 4 felony first offense; civil action 14-6 [U]. | Illinois also has BIPA (740 ILCS 14) - separate, bigger risk for voiceprints (sec. 5). |
| MD | Md. Code, Cts. & Jud. Proc. 10-402, https://mgaleg.maryland.gov/mgawebsite/Laws/StatuteText?article=gcj&section=10-402&enactments=false [V] | 10-402(c)(3): lawful where party and "all of the parties ... have given prior consent", unless for criminal/tortious purpose. | Felony: up to 5 years and/or $10,000 (10-402(b)). Civil 10-410 [U]. | Maryland courts apply to conversations with expectation of privacy. |
| MA | G.L. c.272 s.99, https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99 [V] | "Interception" = secretly hear/record, or "aid another to secretly hear or secretly record", without prior authority of all parties. Open recording (actual knowledge) is not "secret" (Commonwealth v. Hyde, 434 Mass. 594 (2001) [U]). | Up to $10,000 fine and/or 5 yrs state prison / 2.5 yrs house of correction. Civil: actual damages, not less than liquidated $100/day or $1,000 (higher), punitive, fees. | DEVELOPER'S HOME STATE. "Aid another" language is the single most relevant aiding hook. |
| MT | MCA 45-8-213(1)(c), https://mca.legmt.gov/bills/mca/title_0450/chapter_0080/part_0020/section_0130/0450-0080-0020-0130.html [V] | Unlawful to record a conversation "by use of a hidden electronic or mechanical device ... without the knowledge of all parties." Exceptions incl. persons who receive advance warning. | Misdemeanor: up to $500 and/or 6 months (first offense). | Knowledge-based ("hidden device") rather than express consent. |
| NH | RSA 570-A:2, https://gc.nh.gov/rsa/html/LVIII/570-A/570-A-2.htm [V] | Willful interception of telecommunication or oral communication "without the consent of all parties". | Class B felony (Part I); misdemeanor Part I-a for certain party interceptions. Civil 570-A:11 (amounts [U]). | |
| PA | 18 Pa.C.S. 5704(4), https://www.palegis.us/statutes/consolidated/view-statute?txtType=HTM&ttl=18&div=0&chapter=57&section=4&subsctn=0 [fetch returned only site nav; U] | Interception lawful where all parties consented (5704(4)); 5703 offense. | Felony 3rd degree; civil 5725 ($100/day or $1,000 [U]). | WESCA; "oral communication" requires expectation of non-interception. |
| WA | RCW 9.73.030, https://app.leg.wa.gov/RCW/default.aspx?cite=9.73.030 [V] | Unlawful to intercept/record "private" communications "without first obtaining the consent of all the participants"; consent may be shown by announcement that is itself recorded. | Gross misdemeanor 9.73.080 [U]; civil 9.73.060 [referenced, amounts U]. | Note: Washington Privacy Act count in Otter was dismissed with leave to amend (Aug. 2026). |
| DE | 11 Del. C. 1335(a)(4) (private oral comm.) and 2402(c)(4) (wire/electronic), https://delcode.delaware.gov/title11/ [fetch 404; U] | Commonly listed as all-party for private oral communications, one-party for wire; treated as 11th by secondary sources [S: sipnex, recordinglaw.com lists]. | [U] | Verify; counsel to confirm hybrid reading. |
| NV | NRS 200.620 / 200.650, https://www.leg.state.nv.us/nrs/nrs-200.html [fetch failed; U] | Statute allows one-party for some; Nevada Supreme Court (Lane v. Allstate, 114 Nev. 1176 (1998)) requires all-party consent for telephone calls [U]. | [U] | Treat as all-party for calls. |
| CT | Conn. Gen. Stat. 52-570d, https://www.cga.ct.gov/current/pub/chap_933.htm [fetch failed; U] | Civil all-party rule for recording telephonic communications (not criminal for in-person). | Civil, $1,000 per [U]. | Hybrid. |
| OR | ORS 165.540(1)(a),(c), https://www.oregonlegislature.gov/bills_laws/ors/ors165.html [V] | Telecommunications: at least one participant's consent; in-person "conversation": unlawful unless all participants "specifically informed". | Class A misdemeanor [U]. | Hybrid: online meeting = telecommunication, but in-room capture = conversation. |
| MI | MCL 750.539c [U] | Text reads all-party for eavesdropping; Sullivan v. Gray, 117 Mich App 476 (1982) read it as participant-exempt. A federal ruling reaffirming that in April 2026 is reported [S: consentpixel/secondary]. | Felony; civil 750.539h [U]. | Ambiguous; treat conservatively. |
| HI | HRS 711-1111 [U] | Private-place recording; hybrid. | | Low relevance. |

Everything else (about 35 states + DC) is one-party by statute per secondary roundups (e.g., https://www.recordinglaw.com/united-states-recording-laws/ [S]; Reporters Committee guide https://www.rcfp.org/reporters-recording-guide/ [U]); I did not individually verify them. Vermont is reported to lack a wiretap statute [S]. Practical rule: the strictest state of ANY participant may be asserted; Humanity cannot know where other participants are.

Recent changes (2025-26) - none found [S] to the core all-party statutes in the states above. Items that did change:
- CA SB 690 (Caballero): after July 2, 2026 amendment, the broad "commercial business purpose" exemption was dropped; as passed (Aug. 28, 2026) it removes the private right of action under Pen. Code 638.51 (pen register/trap-and-trace) for website/app conduct, AG-only, operative Jan. 1, 2027, retroactive to certain pending claims. Reported signed by Gov. Newsom Sept. 30, 2026 [S: https://www.newsmediaalliance.org/newsom-signs-sb-690-into-law/; analysis https://www.dataprivacyandsecurityinsider.com/2026/09/california-sb-690-could-narrow-cipa-website-tracking-lawsuits/; Assembly analysis https://apcp.assembly.ca.gov/system/files/2026-06/sb-690-caballero-apcp-analysis.pdf]. Per that analysis it does NOT remove private suits under 631, 632, 632.7 or 637.2. Confirm chaptered text at leginfo.
- Case-law shifts (sec. 3) are the real change.

## 2. CIPA mechanics that matter for AI recorders

- 632: needs a "confidential communication" and "recording device"; a PARTY to the call can still violate 632 by recording without all-party consent (that is what 632 is for). 632 is the user-facing risk.
- 631(a): four clauses; courts split on whether a vendor is a "third party" (not a party to the conversation) who is "reading ... contents ... in transit". A party can't eavesdrop on itself (Rogers v. Ulrich, 52 Cal.App.3d 894 (1975) [U]); a vendor whose tool merely records for its customer is treated as the party's "extension" (tape recorder) under one line of cases.
- 632.7 / 637.5 are the other hooks pleaded (Ambriz: 631(a) and 637.5 [S]).
- Consent must be prior (Javier v. Assurance IQ, 9th Cir. 2022, unpublished, retroactive consent insufficient [S: https://www.troutman.com/insights/ninth-circuit-rejects-retroactive-consent-for-recording-website-users/]).
- Damages: $5,000 per violation under 637.2, no injury required; class exposure is the driver. Federal standing arguments (TransUnion; Popa v. Microsoft (9th Cir. 2025) [S: https://sjipl.mainelaw.maine.edu/2025/12/18/the-collapse-of-capability-theory-ambriz-popa-and-the-future-of-article-iii-standing-in-ai-privacy-cases/]) are being used by defendants; unresolved for audio content.

## 3. Case survey (status as of 2026-10-01)

| Case | Court / No. | Theory | Status | Sources |
|---|---|---|---|---|
| In re Otter.ai Privacy Litigation (Brewer v. Otter.ai) | N.D. Cal. 5:25-cv-06911-EKL (Judge Eumi K. Lee); filed Aug. 15, 2025; consolidated Oct. 22, 2025 [S] | Otter Assistant/OtterPilot joins or captures Zoom/Teams/Meet meetings without all-participant consent; trains models on transcripts; speaker-ID voiceprints. Counts: ECPA, CIPA 631 (and 632), CFAA, CDAFA, intrusion, Cal. Const., BIPA, Washington Privacy Act, UCL, unjust enrichment. | Aug. 13, 2026 order: MTD granted in part/denied in part. SURVIVED: ECPA (tortious-purpose exception to party consent not defeated by commercial motive), CIPA (631; 632 only for plaintiff Theus who pleaded specific private medical content), BIPA (2 counts), UCL, unjust enrichment, declaratory relief, intrusion (Theus only). DISMISSED with leave to amend: CFAA, CDAFA, Washington PA, other plaintiffs' intrusion/Cal. Const. Amended complaint due about Aug. 27, 2026; discovery next. Court said Otter plausibly a third-party interceptor because it "independently collects, retains, and uses communications for its own commercial purposes" (rejecting mere-tool defense). 632.7 not addressed. | FindLaw order summary https://caselaw.findlaw.com/court/us-dis-crt-n-d-cal/322025.html [S: summary page, not slip opinion]; docket https://www.courtlistener.com/docket/71118721/brewer-v-otterai-inc/ ; https://www.recordinglaw.com/news/otter-ai-wiretap-lawsuit-explained/ [S] |
| Ambriz v. Google LLC (Google Cloud Contact Center AI) | N.D. Cal. 3:23-cv-05437-RFL | Google's CCAI transcribes call-center calls for businesses; vendor "capable" of using data for own purposes (model improvement) = third party under 631(a); also 637.5. | Feb. 10, 2025 MTD denied; the court applied the CAPABILITY test, no need for proof of actual use. Active per trackers [S]; later status/class cert not verified. | https://www.zwillgen.com/privacy/federal-judge-allows-google-customer-service-ai-class-action-to-proceed/ [S]; order https://www.classaction.org/media/ambriz-v-google-llc-ordering-granting-motion-to-dismiss.pdf [not read] |
| Chamberlain v. Granola, Inc. (and Granola Labs Ltd.) | N.D. Cal. 3:26-cv-07926-EMC; filed July 30, 2026 [S] | "Invisible" bot-free capture of system audio + mic; no notice to participants; default use of data for AI training; advertises hidden nature. Counts: intrusion, ECPA, CIPA 631, CIPA 632, CDAFA, UCL, unjust enrichment. Plaintiff is a Florida resident (FL all-party). | Early stage; response deadline extended; no merits ruling. Granola says it does not save audio [S]; where processing occurs not stated in sources. MOST analogous to Humanity (no visible bot). | https://btlaw.com/en/insights/alerts/2026/what-the-granola-class-action-means-for-companies-building-and-deploying-conversation-capture-tools [S]; https://www.computerworld.com/article/4206255/granola-lawsuit-raises-concerns-over-ai-note-taking-app-privacy.html [not read] |
| Cruz v. Fireflies.AI Corp. | C.D. Ill. 3:25-cv-03399; filed Dec. 2025 [S] | BIPA only: "Speaker Recognition" voiceprints of non-user participants; no written release, no retention policy. No CIPA count seen. | One source says voluntarily dismissed without prejudice March 2026 (recordinglaw); another says early stage; a separate March 10, 2026 Fireflies BIPA class action is reported. CONFLICTING - verify on docket. | https://natlawreview.com/article/ai-meeting-assistants-and-biometric-privacy-governance-lessons-firefliesai-lawsuit ; https://topclassactions.com/lawsuit-settlements/lawsuit-news/fireflies-ai-sued-over-alleged-unlawful-data-collection-from-meeting-participants/ [S] |
| Microsoft Teams live-transcription BIPA suit | W.D. Wash. 2:26-cv-00422; filed Feb. 5, 2026 [S, single source] | BIPA voiceprints | MTD pending (filed May 22, 2026) [S] | https://thelittlebinger.com/ai-notetaker-lawsuits-otter-granola-employer-consent-risk/ |
| Galanter v. Cresta; Lisota v. Heartland Dental | CIPA (June 2025); federal wiretap (July 2025) [S, names only] | AI call/conversation intelligence vendors | Not verified | https://topclassactions.com/... (see Fireflies page) |
| Read.ai, Gong, Zoom AI Companion | - | Brief asked about CIPA 631 suits. I found NO verified suit against Read.ai or Gong; Read.ai appears only in university-blocking stories. One roundup claims a Zoom AI Companion CIPA suit with MTD "denied in part Aug. 13, 2026"; that date matches the Otter order and looks conflated - treat as UNVERIFIED. | - | https://emailexpert.com/ai-meets-the-wiretap-statutes-three-class-actions-the-email-industry-should-be-watching/ [S]; search PACER/CourtListener before relying |

Earlier website-tracking lineage for the tests: Javier v. Assurance IQ, 649 F.Supp.3d 891 (N.D. Cal. 2023) and Graham v. Noom, Inc., 533 F.Supp.3d 823 (N.D. Cal. 2021) [U on holdings; listed https://case-law.vlex.com/vid/javier-v-assurance-iq-1029896722].

## 4. Capability test vs. extension test - why it matters

- Extension test (Graham v. Noom; Rogers-style): a vendor that merely hosts/records for its customer is an "extension" of a party, like a tape recorder, so it is not a third-party eavesdropper. Liability turns on whether the vendor actually uses the data for its own purposes. Favors vendors with a strict processor role.
- Capability test (Javier-line cases; applied to AI in Ambriz): vendor is a third party if it has the ABILITY to use the intercepted data for its own purposes (e.g., training), whether or not it does. Pleading-stage friendly to plaintiffs; contract promises not to use data may not be enough if the technical capability exists.
- Otter's order (as summarized) leaned on alleged actual independent collection/retention/use, so it is compatible with either test; but note that "extension" protection fails once training/analytics use is pleaded.
- Both tests presuppose the vendor RECEIVES the content. For a local-only recorder the developer has no copy, no access, no technical capability to read or use it. That difference is structural (no server, no telemetry, no upload) and should be preserved, documented in PRIVACY.md and kept verifiable by open source code.
- Residual theories that bypass both tests: (a) the user is the recorder and is liable under 632 / state analogs for not obtaining all-party consent (user vs. other participant; developer not a defendant but may be sued as aider/abettor); (b) "aids/agrees with/employs/conspires" clause of 631(a) and MA "aid another"; (c) design-intent pleading as in Granola ("invisible" advertised as a feature); (d) UCL "unlawful" prong borrowing violation; (e) BIPA/other biometric laws reach "collect/possess" - on-device storage reduces but doesn't eliminate arguments, especially because the developer supplied the feature that creates voiceprints of non-users.
- AIKit: transcript text sent to OpenAI/Anthropic/Gemini/Groq under the user's key. The LLM provider is the party that receives content; under Ambriz-type theories THEY could be "third party", and the user is the one directing it. Developer is not in the data path, but should not market AIKit as consent-free.
- Timing caveat: 631 requires interception "in transit"; recording local mic/system audio is closer to 632 than 631 for the developer. Courts have not squarely ruled on local-only AI recorders [no authority found].

## 5. Voiceprints of non-users (separate from recording-consent)

Otter order (S) held voiceprints = biometric identifiers, standing OK, and extraterritoriality satisfied by Illinois residents + in-state meetings. Humanity "voice profiles" store embeddings of named people including non-users, locally. BIPA (740 ILCS 14/15 - written release, retention policy, 14/20 private action: $1,000 negligent / $5,000 reckless; https://www.ilga.gov/legislation/ilcs/ilcs3.asp?ActID=3004 [U]) is the exposure if the developer is treated as "private entity" that "collects/captures/possesses". Texas CUBI (Bus. & Com. Code 503.001, AG-only) and Washington (RCW 19.375) [U] also exist. See companion biometric research file (if produced) for depth.

## 6. Applicability to THIS product

| Factor | Effect |
|---|---|
| Developer receives no audio/transcripts; no servers | Core strength vs. Otter/Ambriz/Granola-type "vendor eavesdropper" counts. Keep as hard invariant. |
| Captures another app's audio (Zoom etc.) with no visible bot/indicator in the call | Granola-like "covert" optics. Users' other participants cannot tell. Raises 632/FL/MA "secret"/"hidden device" exposure for users (MT 45-8-213 is literally "hidden device"). |
| Open-source, MIT, individual developer, MA resident | No corporate shield (no LLC); personal liability; MA c.272 s.99 "aid another" is local statute; MA also all-party and the 5-yr felony. MA courts require "secret" - openly disclosed recording is outside. |
| Free DMG, pay-what-you-want keys, US customers | Wide user base across all-party states; commercial distribution supports "knowingly facilitates" arguments. |
| Voice profiles of non-users | BIPA-type risk plus data-subject expectations. |
| Not notarized | Irrelevant to recording law; relevant to user trust/Gatekeeper warnings. |

Triggers/thresholds: any participant located in an all-party state; CA 632 requires "confidential communication" (Otter order demanded specifics); damages under CA $5,000 per violation; MA liquidated $100/day or $1,000; BIPA $1,000/$5,000 per person; criminal felony tier in FL, MD, NH, PA, MA, IL.

## 7. Recommended product design measures

1. Keep local-only invariant: no upload of audio/transcripts/voiceprints by any Humanity code path; state it in PRIVACY.md and add CI/grep guard against new network calls in MeetingKit. If a cloud feature is ever added, re-run this analysis first (it flips the capability/extension analysis).
2. Consent gate before first meeting capture and per meeting: a non-skippable "I will tell all participants / have their consent" prompt with jurisdiction note (all-party states list); log a local timestamped attestation (user-side evidence, not sent anywhere).
3. Built-in disclosure tooling: one-click "recording notice" to paste in chat; optional spoken/audible announcement or on-screen overlay; a persistent menu-bar recording indicator with no "stealth/hide" option. Remove any "undetectable/invisible" wording from marketing, README, Gumroad page (Granola complaint pleads exactly this).
4. Per-meeting "consent obtained" checkbox default off; disable recording of non-mic audio until checked. Consider a "all-party mode" default-on for the US.
5. Voice profiles: opt-in per person with a stored consent note ("this person agreed"), no profiles for unnamed/unconsenting people by default, easy delete, auto-expire (e.g., 12-24 months), never exported. Warn users about BIPA if participants may be in Illinois, Texas, Washington. Consider disabling profile creation for non-users until counsel reviews.
6. Retention: configurable auto-delete for meeting audio (default short), "transcript only, delete audio" option (data minimization; also helps 632(d)-type and discovery risk).
7. AIKit: before first transcript send, show "this sends meeting text, which may include other people's words, to <provider>"; require explicit confirmation; remove consent-free default; exclude diarization voiceprints from payloads.
8. Do not train or analyze anything centrally; no analytics SDKs.

## 8. Recommended Terms / documentation changes

- Terms of Use / license: user is solely responsible for recording-consent compliance in every participant's jurisdiction; user warrants it will not record without legally required consent; prohibition on covert recording of confidential communications; right to terminate keys for violations; acknowledgment that the developer does not receive, access, or control recordings or voiceprints.
- Role statement: Humanity is a local tool; user is the "recorder"; developer is not a party to any communication and has no technical access (supports extension/no-capability argument).
- No-warranty / limitation of liability and indemnity from user (enforceability varies, especially for consumers; MA c.93A and 940 CMR exposure for unfair terms [U]) - attorney review.
- Add an arbitration/class-waiver question for counsel: pay-what-you-want sales may make consent to arbitration weak; MA individual with no entity - consider LLC formation to reduce personal exposure (flag, not advice).
- PRIVACY.md line "Tell people when you record a meeting, and follow your local consent laws" (PRIVACY.md line 49) is too weak: expand with a state list, the all-party warning, the voiceprint warning for non-users, and AIKit disclosure.
- Gumroad listing/README: remove any "invisible/silent" claims; add a recording-consent notice.
- Retain version history showing local-only architecture (open-source commit history is useful evidence).

## 9. Attorney-review flags

1. MA c.272 s.99 "aid another" application to a distributor of recording software (no case found) and individual criminal/civil exposure.
2. Whether any developer-side activity could be "collect/possess" for BIPA (local embeddings).
3. Choice-of-law for multi-state calls; reach of CA 632 for a non-CA developer and non-CA users with a CA participant.
4. Confirm primary text for IL, PA, DE, NV, CT, MI, HI, FL civil remedy, and the other ~35 states.
5. Confirm SB 690 chaptered text, signing, and effect on 631/632/637.2 (secondary sources only).
6. Pull actual Otter Aug. 13, 2026 order (CourtListener) and check amended complaint; verify Fireflies, Zoom, Gong, Read.ai dockets; verify Ambriz status (class cert, any 9th Cir. appeal).
7. Terms enforceability for unfair-practice rules and the "individual developer, no LLC" structure.

## 10. Sources verified (fetched 2026-10-01)

Primary text fetched [V]:
- https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=PEN&sectionNum=632 (also 631, 632.7, 637.2)
- http://www.leg.state.fl.us/statutes/index.cfm?App_mode=Display_Statute&URL=0900-0999/0934/Sections/0934.03.html
- https://mgaleg.maryland.gov/mgawebsite/Laws/StatuteText?article=gcj&section=10-402&enactments=false
- https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99
- https://mca.legmt.gov/bills/mca/title_0450/chapter_0080/part_0020/section_0130/0450-0080-0020-0130.html
- https://gc.nh.gov/rsa/html/LVIII/570-A/570-A-2.htm
- https://app.leg.wa.gov/RCW/default.aspx?cite=9.73.030
- https://www.oregonlegislature.gov/bills_laws/ors/ors165.html
Fetch tool summarizes pages; quotes above are the tool's extracts, not independently checked against page images.

Secondary only [S] (case status): FindLaw Otter summary, recordinglaw.com, thelittlebinger.com, btlaw.com Granola alert, ZwillGen Ambriz, natlawreview Fireflies, dataprivacyandsecurityinsider SB 690, newsmediaalliance SB 690 signing.

Not retrievable this session: ILCS (cert error), PA legislature (nav only), Delaware, Connecticut, Nevada sites. Case opinions (Otter slip op., Ambriz, Graham, Javier) not read in full. Several search results reported 2026 events that I could only see in summaries; treat all 2026 case dates as needing docket confirmation.
