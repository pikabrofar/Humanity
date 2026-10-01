# 06 - FTC Act Section 5: claims audit for Humanity

Analyst notes, not legal advice. Nothing here says the product is "compliant" or "safe". Date: 2026-10-01. Status tags: [V] = fetched/confirmed this session; [S] = seen only in search-result summaries (law-firm or news pages), re-check primary text; [U] = from general knowledge, not re-fetched.

## 1. Bottom line

- Section 5 (15 U.S.C. 45(a)) bans "unfair or deceptive acts or practices in or affecting commerce" [U: https://www.law.cornell.edu/uscode/text/15/45]. It applies to a sole proprietor selling software online; there is no size, LLC or revenue threshold. Individuals are reachable directly. No LLC means no entity shield, but that is a state-law question (flag for attorney).
- The FTC's core theory in every case below is "say what you do, do what you say, and have evidence for the claim". Deception = a representation or omission that is likely to mislead a reasonable consumer, and is material (FTC Deception Policy Statement [U: https://www.ftc.gov/legal-library/browse/ftc-policy-statement-deception]). Objective claims need substantiation before they are made (Substantiation Policy Statement [U: https://www.ftc.gov/legal-library/browse/ftc-policy-statement-regarding-advertising-substantiation]).
- Humanity's biggest exposure is **absolute privacy wording** ("never", "nothing leaves your Mac", "private by design", "nothing is uploaded") sitting next to documented exceptions (Gumroad license pings, Hugging Face model downloads, optional BYO-key cloud AI text, eye-image patches and voiceprints stored on disk). Absolutes with exceptions are the pattern behind Zoom, Avast and similar cases.
- Second: **"free"** (README, Gumroad) when the apps will not run without a paid key.
- Third: **biometric handling** (eye patches, voiceprints of non-users) against the 2023 Biometric Policy Statement, whose "failure to assess foreseeable harm / failure to inform / failure to obtain consent" prongs apply even without a false statement.
- Enforcement climate (2025-26): FTC still brings plain deception and unsubstantiated-claims cases (IntelliVision, Workado, accessiBe, Amazon Prime), but set aside the Rytr order in Dec 2025 citing the AI Action Plan. "AI innovation" arguments help on theories that rest on novel unfairness, not on false-claim cases. State AGs (MA Ch. 93A) are a parallel risk; out of scope here, see other research notes.

## 2. Case lessons (what the FTC actually pursued)

| Case | Date | What happened | Lesson for Humanity |
|---|---|---|---|
| Everalbum ("Ever" photo app) | Jan 2021 settlement; final May 2021 | Told users face recognition was on only if they enabled it; it was on by default for many. Kept photos of deactivated accounts. Order: obtain express consent before face recognition, delete data AND models/algorithms derived from it. [S] https://www.ftc.gov/news-events/news/press-releases/2021/01/california-company-settles-ftc-allegations-it-deceived-consumers-about-use-facial-recognition-photo | Your calibration/eye-patch and voiceprint stores must match what UI/PRIVACY say about opt-in, retention and deletion. "Delete" must delete derived models/embeddings too. Voice profiles of non-users = no consent from the person profiled. |
| Rite Aid | Dec 2023 | 5-year ban on facial recognition for surveillance; alleged failure to assess accuracy/bias, test, train staff, monitor, or notify consumers; delete images. [V] https://www.ftc.gov/news-events/news/press-releases/2023/12/rite-aid-banned-using-ai-facial-recognition-after-ftc-says-retailer-deployed-technology-without | Unfairness case without an express false claim. Different facts (retail surveillance), but the "reasonable safeguards" checklist is the template regulators will reuse for any face/voice identification feature. Voice profiles that identify named third parties in meetings is the nearest Humanity feature. |
| Zoom | Nov 2020 | Marketed "end-to-end, 256-bit encryption" while holding keys and using lower encryption; also other security claims. Order: security program, biennial assessments. [V] https://www.ftc.gov/business-guidance/blog/2020/11/zooming-zooms-unfair-deceptive-security-practices-more-about-ftc-settlement | A security term of art used loosely is deceptive. Avoid "encrypted", "secure", "end-to-end", "military-grade". Repo currently only says Keychain "encrypted at rest" in a code comment (AIKit/KeychainStore.swift); fine in code, do not repeat in marketing without wording check. |
| Avast / Jumpshot | Feb 2024 ($16.5M) | Promised products would protect from tracking and data shared "anonymous and aggregate"; sold re-identifiable browsing data. Ban on selling browsing data for ads. [V] https://www.ftc.gov/news-events/news/press-releases/2024/02/ftc-order-will-ban-avast-selling-browsing-data-advertising-purposes-require-it-pay-165-million-over | "Private"/"anonymous" is judged against actual flows. You do not sell data (good), but "private by design" will be read against the Gumroad and Hugging Face pings and BYO-AI. Also: never describe voiceprints or eye patches as "anonymous". |
| IntelliVision | Dec 2024 proposed; final Jan 2025 | Claims of "zero gender or racial bias", top accuracy, trained on millions of faces, without evidence. Order bars unsubstantiated accuracy/bias claims. [S] https://www.ftc.gov/news-events/news/press-releases/2024/12/ftc-takes-action-against-intellivision-technologies-deceptive-claims-about-its-facial-recognition | Any "accurate", "precise", "works for everyone/all users" claim for eye tracking, hand tracking or diarization needs testing evidence across glasses, skin tone, lighting, accents. OculOS UI shows measured accuracy (degrees) from the user's own calibration; good, but README/Gumroad must not generalize it. |
| accessiBe | Jan 2025 proposed; final Apr 2025 ($1M) | Claimed AI tool makes websites WCAG-compliant; presented paid/connected reviews as independent. [S] https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-order-requires-online-marketer-pay-1-million-deceptive-claims-its-ai-product-could-make-websites | Directly on point for "for people with disabilities" marketing AND for promo-key reviewers (section 7). |
| Workado | Apr 2025 proposed; final Aug 28 2025 | "98% accurate" AI-detector claim lacked competent and reliable evidence. [S] https://www.ftc.gov/news-events/news/press-releases/2025/08/ftc-approves-final-order-against-workado-llc-which-misrepresented-accuracy-its-artificial | Numeric accuracy claims for any ML feature (WER, gaze error, diarization) need documented, representative testing. |
| Operation AI Comply | Sept 25 2024 | Sweep: DoNotPay ("robot lawyer", $193k), Ascend Ecom, Ecommerce Empire Builders, FBA Machine, Rytr. [V] https://www.ftc.gov/news-events/news/press-releases/2024/09/ftc-announces-crackdown-deceptive-ai-claims-schemes | "AI" is not a license to exaggerate. "Using AI is not an excuse for a claim you could not make without AI." |
| Rytr order set aside | Dec 22 2025 | FTC reopened and vacated the 2024 Rytr order, citing AI Action Plan and failure to plead a violation. [V] https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-reopens-sets-aside-rytr-final-order-response-trump-administrations-ai-action-plan | Signals less appetite for "means and instrumentalities" theories against AI tools. Does NOT soften false-claim or substantiation cases (Workado, accessiBe finalized in 2025). |
| Amazon Prime (ROSCA, dark patterns) | Sept 2025 ($2.5B) | $1B penalty + $1.5B refunds over enrollment/cancellation flows. [S] https://www.alston.com/en/insights/publications/2025/10/ftc-settlement-prime-subscription-practices | Dark-pattern theory is alive. Humanity has no subscription, so ROSCA is likely inapplicable (section 6). |
| Click-to-Cancel rule | Vacated by 8th Cir. Jul 8 2025; FTC reopened rulemaking ~Mar 2026 | [S] https://www.crowell.com/en/insights/client-alerts/eighth-circuit-cancels-click-to-cancel ; https://www.consumerfinancialserviceslawmonitor.com/2026/03/ftc-reopens-negative-option-rulemaking-after-eight-circuit-vacates-2024-amendments/ | Not applicable unless you add subscriptions. |

Unverified 2024-26 items worth an attorney or later pass: Evolv (AI weapons-detection claims, Nov 2024), Air AI and other 2025 "AI income" cases, Cleo AI ($17M, Mar 2025 [S]), any 2026 FTC action on voice/biometric data. I did not locate a 2026 FTC case specifically about on-device "private" claims. Treat as unknown, not absent.

## 3. 2023 Biometric Policy Statement (May 18, 2023)

Source [V that it exists, content from summaries S]: https://www.ftc.gov/legal-library/browse/policy-statement-federal-trade-commission-biometric-information-section-5-federal-trade-commission (direct fetch of the PDF returned binary; re-read primary text before relying on specifics).

- "Biometric information" is defined broadly: data depicting or describing physical, biological or behavioral traits, characteristics or measurements of or relating to an identified or identifiable person's body, including derived data (templates, embeddings, models). Facial/voice recognition, and arguably gaze/eye-feature data, can fall in. [S]
- Practices the statement says may violate Section 5: (1) false or unsubstantiated claims about validity, reliability, accuracy, performance, fairness or efficacy; (2) deceptive statements about collection/use; (3) failing to assess foreseeable harms before collecting; (4) failing to promptly address known or foreseeable risks (incl. bias/disparate performance); (5) engaging in surprise secondary uses; (6) failing to evaluate vendors/third parties; (7) failing to train staff; (8) failing to monitor technology for use consistent with intent. [S]
- It is a policy statement, not a rule: no civil penalties on its own; it signals how Section 5 unfairness/deception will be applied. Not withdrawn as of my searches (unverified; check ftc.gov before relying). Current-leadership enforcement emphasis is narrower than 2023, but the statement stays on the FTC website.

Applicability to Humanity:

| Feature | Biometric-like data | Why it matters |
|---|---|---|
| OculOS | 10x6 eye-patch image fragments, eye-feature measurements, gaze recordings, optional screenshots | PRIVACY.md says "Camera frames are never stored" and also stores eye-patch pixels derived from frames. A regulator or reporter could read "never stored" as contradicted. |
| ManOS | Hand landmarks (transient), pinch thresholds | Low. |
| Murmur Meetings | Speaker voiceprint embeddings for named people, including non-users who never saw your policy | Core Everalbum/Rite Aid analog: identification of third parties without their knowledge. Only you, as local app user, control it; developer never receives it. The FTC's lens is on whoever designs the feature and its defaults. |

Because the developer receives none of this data, the case for "unfair practice by Humanity" is weaker than for a cloud vendor, but marketing statements about it are still the developer's own representations. Recommended: a short "Biometric data" section in PRIVACY.md (what, where, how to delete including derived models, no sharing, no sale), an in-app one-time notice before first voice profile creation that states the person profiled should be told, and a documented pre-launch harm assessment (even one page) covering misidentification and bias in diarization and gaze. Attorney flag: state biometric laws (BIPA, Texas CUBI, WA) are covered in other research notes and are not repeated here.

## 4. Audit of actual claims

Sources read: README.md, PRIVACY.md, four Info.plist files, UI strings in Humanity/OculOS/ManOS/Murmur/MeetingKit/AIKit Swift sources. The Gumroad text was quoted by the requester; I could not view the live listing. Risk: H = fix before launch, M = tighten, L = fine/monitor.

### 4.1 Privacy and security claims

| # | Where | Claim (exact text) | Issue | Risk | Suggested replacement |
|---|---|---|---|---|---|
| 1 | Gumroad | "private by design... nothing is uploaded unless you add your own AI key" | Absolute. Counter-examples in your own PRIVACY.md: license key + product ID go to Gumroad weekly; MeetingKit downloads models from Hugging Face (request reveals IP, model name); Apple may download speech model; also Gumroad receives purchaser data by definition. "Private by design" is a vague quality claim the FTC reads as an express "your data stays private" claim. | H | "Your camera and microphone data is processed on your Mac. Humanity has no accounts, analytics or telemetry. It contacts Gumroad to check your license key, and downloads speech-separation models from Hugging Face the first time you use Meetings. If you add your own AI key, the text of transcripts you choose to send goes to the provider you pick. Details: PRIVACY.md." |
| 2 | OculOS LiveView.swift:80 | "OculOS processes video on-device only. Nothing leaves your Mac." | "Nothing" is false as a whole-app statement (license check). True only of video. | H | "OculOS processes camera video on this Mac. Video is never uploaded." |
| 3 | README intro | "Camera and audio are processed on-device ... no account, and cloud AI only if you add your own key." | Omits license check and HF download; "cloud AI only if" is accurate but incomplete since app does contact Gumroad. Close to OK; "processed on-device" is accurate. | M | Add: "Aside from license checks and a one-time model download, the only network use is cloud AI you configure." |
| 4 | PRIVACY.md | "The apps have no analytics, telemetry, crash reporting or update checks. They make network requests in only these cases" | Strong, falsifiable. Need evidence: a network capture (Little Snitch/`nettop`/mitmproxy) of every module across a full session; confirm no Sparkle/URLSession elsewhere; note macOS itself may send crash reports to Apple (outside app control). Also "Scripts you run yourself" bullet is good. Add AIKit local providers (Ollama) as local-only if true. | M | Keep, but add "Last verified: <date, version>" and a line on how to verify (`lsof`/Little Snitch). Add: "macOS may send its own crash reports to Apple if you opt in; that is outside Humanity." |
| 5 | PRIVACY.md | "Camera frames are never stored. Each frame is analyzed in memory and discarded." plus Info.plist: "never saved or uploaded" | Eye patches are pixel crops from frames and stored; OculOS "optional screenshot" is screen capture, not camera, but a reader may conflate. Must be consistent. | H | "Camera video is never recorded or uploaded. OculOS keeps small derived measurements and 10x6-pixel eye-region patches (cropped from camera frames) to calibrate gaze, stored only on your Mac." Info.plist: "...Video is processed on this Mac and is not recorded or uploaded. OculOS stores small calibration data locally." |
| 6 | All Info.plists | "Video frames are processed on this Mac and never saved or uploaded." | Same as #5 for OculOS; ManOS version looks fine if ManOS stores no images (verify). | M | As #5 for OculOS; ManOS can stay. |
| 7 | Info.plist (Humanity, Murmur) | "Audio is transcribed on this Mac and never uploaded. Only text goes to an AI provider, if you set one up." | Meeting call audio and voice notes are stored locally (fine). "Never uploaded" correct if code verified; but diarization models are downloaded, not audio uploaded: fine. Verify no code path uploads audio (AIKit transcription via Groq/OpenAI Whisper?). If any AIKit task accepts audio, claim is false. | M | Keep after code check. Add "Murmur only sends audio nowhere; if you choose a cloud AI task, only text is sent." |
| 8 | Info.plist | "your audio is not sent to Apple" / SetupView: "never falls back to Apple's servers" | Code sets `requiresOnDeviceRecognition = true` (Transcriber.swift:202, FileTranscriber.swift:116), supporting it. But macOS downloads speech assets from Apple (PRIVACY.md admits) and Apple's own handling of on-device recognition is outside your control. | L-M | "Murmur requests on-device recognition only." Avoid "never" about Apple behavior. |
| 9 | PRIVACY.md | "Dictation into password fields is never sent." | Absolute behavioral claim; relies on `IsSecureEventInputEnabled()` (AppModel.swift:153). That API reports secure input globally, not necessarily the focused field, and some apps/web password fields do not set it. | H | "When macOS reports secure input (for example in most password fields), Murmur does not send that dictation to a cloud AI provider. Some apps do not report this, so do not dictate passwords." |
| 10 | PRIVACY.md/UI | "Every task defaults to on-device." | Verify defaults in AIKit; a default flip later makes this false. | L | Keep; add a unit test asserting defaults. |
| 11 | VoiceProfilesView | "Only voice fingerprints are saved, never audio. Stored on this Mac." | "Fingerprints" is soft; voiceprints are biometric identifiers (code comment at VoiceProfileStore.swift:5 itself says "treat them as biometric data"). Mismatch between internal and user-facing candor is the kind of document an enforcement staffer cites. | M | "Saves a numeric voiceprint (a biometric identifier) for each person you name. No audio is kept with it. Stored only on this Mac. Get consent from people before profiling them. Delete any time in Voice Profiles." |
| 12 | PRIVACY.md | "Gaze data and voiceprints can count as biometric data under laws like the GDPR. Tell people when you record a meeting, and follow your local consent laws." | Honest but puts all burden on user; no biometric-specific purpose/retention statement. OK as far as truthfulness. | M | Expand per section 3; say "can count as biometric data under laws such as GDPR and U.S. state biometric laws". |
| 13 | PRIVACY.md | "Don't take our word for it. The code is short." | Short code claim is unverifiable puffery but invites "verify" scrutiny; repo has many modules. Open-source is a strength: claims about what code does are checkable, and checkers will find mismatches. | L | "The source is public so you can check." Drop "short". |
| 14 | Any copy | (none found) "encrypted", "secure", "anonymous", "HIPAA", "GDPR compliant" | Not found in repo UI/README. Keep it that way. Keychain use is described accurately in code ("encrypted at rest" comment only). | L | Do not add. If needed: "API keys are stored in your macOS Keychain." |

### 4.2 "Free" claims (16 CFR 251)

Text [V]: https://www.law.cornell.edu/cfr/text/16/251.1 . Key points: a purchaser may believe the merchant will not "directly and immediately recover" the cost of free merchandise; "all of the terms, conditions and obligations should appear in close conjunction with the offer of 'Free'". Guides are advisory (violation can be treated as deceptive if the practice is, no civil penalties by themselves; the FTC can use Section 5 and, for rule violations, 16 CFR 465 etc.). Pay-what-you-want ($5 minimum) means the product is not free; the DMG file is.

| # | Where | Claim | Issue | Risk | Replacement |
|---|---|---|---|---|---|
| 15 | Gumroad | "download for free" | Download is free; use needs a $5+ key. Headline "free" + disclosure elsewhere = classic Free Guide problem. Also pay-what-you-want with a minimum is not "free". | H | Headline: "Humanity: from $5 (pay what you want, minimum $5). The installer download is free, but the apps require a license key to run." Put it in the first line, not below the fold. Do not use "Free" as a standalone word or in the title/tags/thumbnail. |
| 16 | README | "The download costs nothing, but the apps need a paid license key to run (from $5)." | Good: condition adjacent. Slight pivot: "costs nothing" invites the headline reading. GitHub Releases page title/notes should not say "Free". | L | "The installer is a free download, but you need a license key (from $5) to use the apps." |
| 17 | README | "The source stays MIT licensed." + "git clone ... make run" | Truthful: users can build free. But if build-from-source also requires a key (does the source build enforce LicenseKit?), say so; if it does not, the "need a paid key" statement is true only for the DMG. Clarify to avoid the opposite deception. | M | "The DMG requires a key. The MIT-licensed source can be built yourself (see Requirements); builds from source are unsupported." (Match actual code behavior; check LicenseKit gating.) |
| 18 | Gumroad/README | "buying one funds development" | Fine; not a charity claim. Do not imply nonprofit/charity. | L | Keep. |
| 19 | Both | "One key unlocks every Humanity app" | Verify licence product ID gating; lifetime vs. updates? State terms (lifetime? device limit? version?). Omitted material terms = Free Guide + general Section 5. | M | State: "One-time payment, key works on N Macs, includes version 1.x updates" (fill in). |
| 20 | Gumroad/README | Unnotarized: "macOS blocks the first launch. Open Anyway" | Not strictly Section 5, but telling consumers to override Gatekeeper without disclosing the risk (not notarized by Apple) is a material fact for a security-sensitive app that holds camera, mic and Accessibility. Disclosed in README; not necessarily in Gumroad. | M | Gumroad: "Not yet notarized by Apple; macOS will warn on first launch. Verify the SHA-256 (published) before opening." Link to the dist/*.sha256 files. |

### 4.3 AI claims

| # | Where | Claim | Issue | Risk | Replacement |
|---|---|---|---|---|---|
| 21 | README | "Optional bring-your-own-key AI ... for summaries and more" ; Murmur: "Get a short summary and action items from Apple's on-device model" / "summaries are written by its on-device model" | No accuracy claim, good. "Apple's on-device model" claim true only on Apple Intelligence-eligible Macs; UI already says "or built-in rules instead". | L | Keep. Add "Summaries can be wrong; check important details." |
| 22 | Any marketing | Avoid: "AI-powered", "smart", "intelligent", "understands you", "perfect transcription", "100% accurate", "recognizes speakers automatically" | Not in repo; guard against adding to Gumroad. Operation AI Comply / Workado / IntelliVision. | L | If used: "Uses Apple's on-device speech recognition and a local speaker-separation model. Accuracy varies with audio quality." |
| 23 | OculOS UI | "Clicking where you look teaches it to be more accurate." / "Clicking ... refines accuracy over time." (HumanityApp.swift:423, SetupPage.swift:51) | Performance claim. Need evidence that it improves accuracy (test data). Currently mild. | M | "...adds calibration samples that can improve accuracy" or remove until tested. Keep internal eval results (research note 18-evaluation) as substantiation file. |
| 24 | OculOS UI | "About 45 seconds..."; "five held-out dots that measure accuracy"; displays "accuracy" in degrees | Per-session measured value: fine. Do not publish a general "accuracy of X degrees" in marketing without a testing protocol across users (glasses, skin tones, lighting). | M | "OculOS shows your measured accuracy after each calibration." |
| 25 | OculOS UI | "Glasses are fine, but reflections reduce accuracy." | Honest limitation. Good. | L | Keep. Add more such limitation statements (lighting, head motion, eye conditions). |

### 4.4 Accessibility and medical-type claims

Repo scan: README, PRIVACY.md, UI strings contain no "disability", "assistive", "medical", "therapy", "RSI" claims. Only research/README.md lists "Users with motor disabilities" as a research topic. The risk is in future marketing (Gumroad, social posts, Product Hunt, outreach to disability communities).

| # | Possible claim | Issue | Risk | Guidance |
|---|---|---|---|---|
| 26 | "For people with disabilities" / "accessible computing" / "hands-free" / "control your computer without a mouse" | Efficacy claim about a vulnerable population; needs competent evidence (testing with target users) per Substantiation Policy and accessiBe/Workado reasoning. "Hands-free" is wrong for ManOS (it needs hands). "Eyes only" claims wrong for OculOS without clicks (dwell click exists; verify). Eye tracking by webcam is imprecise; a user who relies on it and fails is harmed more than a casual user. | H if used | Use factual descriptions of function: "Webcam gaze cursor with dwell click", "Hand-gesture mouse using the camera". If targeting accessibility: "Designed with accessibility in mind; not a replacement for medical or assistive-technology devices; performance varies. Try the demo / ask before purchase." No refund-policy gap: state a refund window (Gumroad allows). |
| 27 | "Reduces RSI / carpal tunnel / eye strain / treats ..." | Health claim; FTC requires "competent and reliable scientific evidence", typically RCTs for disease/health benefit claims (FTC Health Products Compliance Guidance, Dec 2022 [U: https://www.ftc.gov/business-guidance/resources/health-products-compliance-guidance]). FDA device jurisdiction arises if marketed to diagnose/treat/mitigate a condition (FDCA; not researched here, attorney flag). | H if used | Do not make health outcome claims. Do not use "therapy", "treatment", "medical", "clinical". |
| 28 | "ADA/WCAG compliant", "accessible" (as a label for the apps' own UI) | accessiBe lesson: compliance claims are objective, need audit. Apps are macOS native; no conformance testing documented. | M | Say "Works with VoiceOver: [only if tested]" or say nothing. |
| 29 | Using the word "disabilities" in marketing to attract buyers and then offering "pay what you want, min $5" | Not a violation; but any false suggestion that insurers/Medicare cover it, or "FDA-registered" would be. | L | Avoid. |
| 30 | Eye "health"/"attention"/"emotion" inference from gaze (heatmaps, "gaze analytics") | Inferring health/attention/mood from eye data triggers sensitive-data rules in some states and invites substantiation demands. | M | Describe heatmaps as "where on screen you looked", not as measures of attention, fatigue or cognitive state. |

### 4.5 Reviews, endorsements, promo keys (16 CFR 255 and 465)

Endorsement Guides, 16 CFR Part 255 (revised 2023): material connections must be disclosed, including "provision of free or discounted products", even if no endorsement was required, if audiences would not expect it [V: https://www.law.cornell.edu/cfr/text/16/255.5]. Advertisers are responsible for endorsers' statements and for monitoring/training endorsers (255.1; [U], not fetched).

Reviews and Testimonials Rule, 16 CFR Part 465, effective Oct 21 2024, with civil penalties (about $51,744 per violation as stated in a secondary source; check current inflation-adjusted figure) [S: https://www.govinfo.gov/content/pkg/FR-2024-08-22/html/2024-18519.htm ; Q&A https://www.ftc.gov/business-guidance/resources/consumer-reviews-testimonials-rule-questions-answers ]. Prohibits fake or AI-generated reviews, buying reviews conditioned on sentiment, undisclosed insider reviews, review suppression (including suppressing negative reviews from a site you control), and buying fake social indicators. This rule has teeth the Guides lack.

| Practice | Risk | Do |
|---|---|---|
| Giving free promo keys to reviewers/influencers | Free product is a material connection (255.5). | Require clear disclosure in the content itself (not only profile/bio), e.g., "I received a free license key." Put disclosure in the first line/spoken at start of video. Keep a written policy and a log of recipients. |
| Telling reviewers "give a positive review for a free key" or "5 stars = discount" | Violates 465 (conditioning incentive on sentiment) and 255. | Say "honest review, positive or negative; no obligation". Never ask for a rating. Do not edit reviewers' scripts to remove criticism. |
| Reviewers making claims you have not substantiated ("works perfectly for ALS", "100% private") | You are liable for endorser claims (255.1). | Give reviewers a short claim sheet of approved statements; review before publication where practicable; ask them to correct. |
| Self-written testimonials or friends/family reviews on Gumroad, GitHub, Product Hunt | Insider reviews (465) require disclosure; fake reviews prohibited. | No reviews from yourself/relatives/employees without disclosure; no AI-written reviews. |
| Hiding or deleting negative Gumroad reviews or GitHub issues | Review suppression (465) if the site is controlled by you. | Moderate only for spam/abuse by stated policy. |
| Photos/quotes from users on the Gumroad page | Testimonial must reflect actual experience. | Written permission; keep records; typical results not implied. |
| Pay-what-you-want giveaways to disability communities followed by endorsements | Disclosure plus claim-risk (section 4.4). | Same rules. Disclose connection. Avoid health claims. |

## 5. Dark patterns

FTC staff report "Bringing Dark Patterns to Light" (Sept 2022) [U: https://www.ftc.gov/reports/bringing-dark-patterns-light] describes obscured disclosures, forced action, confirmshaming, difficult cancellation, hidden fees, and default consent. Section 5 applies; ROSCA applies to negative-option (subscriptions, trials that convert).

Review of Humanity: no subscription, trial conversion or auto-renewal found, so ROSCA and the Negative Option Rule are probably inapplicable (attorney to confirm for Gumroad's own terms and any "memberships" you add later). Possible dark-pattern exposures:

| Item | Concern | Fix |
|---|---|---|
| "Free download" that stops at a license wall | Bait-and-switch perception; user has already given camera/AX trust and gone through "Open Anyway". | State the key requirement before download (Gumroad and GitHub release notes) and on the first launch screen: link to "Get a key" and a refund policy line. Offer a clear "Quit" path. |
| Pay-what-you-want pricing UI | Default suggested price, anchoring: not deceptive if minimum is clear. | Show "Minimum $5" prominently; no pre-selected tip beyond the minimum without clear labeling. |
| Permission prompts (Camera, Mic, Accessibility, Screen Recording) | Asking for Accessibility/Screen Recording "once" for everything bundled in one app ("Humanity") while only one module needs it can look like overbroad default consent. PRIVACY.md lists each; setup lists per-module purpose (good). | Request permissions at the moment of first use of the module requiring it; explain Screen Recording as optional (already). Do not repeat nags after "Not now". |
| Cloud AI settings | Default on-device (good). | Never pre-enable cloud providers; show a one-time notice naming the provider and what text is sent. |
| Refunds | Gumroad: absent refund statement could be unfair if the app does not work on the buyer's Mac (macOS 14, webcam). | State refund terms and system requirements on the Gumroad page before purchase. |
| Cancellation | N/A (one-time). | Keep it that way; if updates become a subscription, redo this analysis. |

## 6. Applicability summary

| Topic | Applies to Humanity? | Why |
|---|---|---|
| Section 5 deception (privacy/security claims) | Yes, high | Express privacy claims are central selling points. |
| Section 5 unfairness (biometric handling) | Moderate | Developer does not receive data (weakens unfairness theory), but voiceprints of non-users and eye patches are stored by a tool you design; defaults and notices are yours. |
| Biometric Policy Statement | Yes as guidance | No penalties itself; reflects FTC expectations. |
| Free Guide (16 CFR 251) | Yes | "Free" wording; guide is not a rule, enforced through Section 5. |
| Endorsement Guides (255) and Reviews Rule (465) | Yes if promo keys or reviews | 465 carries civil penalties. |
| ROSCA / Negative Option / Click-to-Cancel | Probably no | No recurring billing. Rule vacated anyway. |
| AI claims | Low-moderate | No AI-accuracy marketing found; BYO-key AI is user-configured. Risk is future copy. |
| COPPA | Not researched here | Apps record faces/voices; no age gate seen. Attorney flag: if children could use it, FTC COPPA Rule (16 CFR 312) applies only if the developer collects personal info from children online; developer collects none beyond Gumroad. Likely not triggered; verify. |
| Health claims | Only if added | Avoid. |

## 7. Recommended changes (prioritized)

1. Gumroad page: replace "download for free" and "private by design... nothing is uploaded unless..." with the wording in rows 1 and 15; add limitations (macOS 14+, webcam needed, not notarized, beta, accuracy varies) and refund policy.
2. Fix OculOS LiveView "Nothing leaves your Mac" (row 2) and align Info.plist/PRIVACY wording on eye patches (rows 5-6).
3. Reword the password-field claim (row 9) or add tests demonstrating it.
4. Add Biometric section to PRIVACY.md, expand VoiceProfiles UI text, add first-use consent notice for voice profiles (rows 11-12; section 3).
5. Run and archive a network capture per module/version to substantiate "no telemetry" (row 4). Keep an internal "claims substantiation file": test logs, packet captures, code references, per-claim.
6. Write a one-page influencer/promo-key policy (section 4.5) and sample disclosure text. Keep a recipient log.
7. Marketing guardrails: no health, disability-efficacy, "AI-powered accuracy", "encrypted", "anonymous", "compliant" language without evidence (rows 22, 26-28).
8. Add a pre-launch harm assessment memo (Rite Aid checklist: accuracy across users, misidentification risk, staff/vendor review N/A for solo developer).
9. Add "last reviewed" dates to PRIVACY.md and update on each release; mismatch between code and doc is the main way open-source privacy claims fail.

## 8. Attorney-review flags

- Whether a sole proprietor without an LLC faces personal liability exposure (state law) and whether to form an entity before launch.
- Substantive wording of the Gumroad page, PRIVACY.md biometric section, and consent notice for non-user voiceprints (interplay with state biometric laws and wiretap/consent laws in other notes).
- Whether any Humanity marketing aimed at people with disabilities triggers FDA device regulation or state disability-marketing laws.
- Massachusetts Ch. 93A and 940 CMR 3.00 exposure for the same claims (not researched here).
- Whether the 2023 Biometric Policy Statement remains in force in current FTC leadership posture, and any 2026 biometric/voice cases I could not find.
- Current inflation-adjusted civil penalty figure for 16 CFR 465.
- Gumroad's terms: who is the merchant of record (Gumroad as MoR affects who is the "seller" in free/price claims and tax) and review features.
- Whether source builds bypass the license wall (row 17), which changes how "requires a paid key" must be described.

## 9. Sources verified (2026-10-01)

Fetched or confirmed via search result with FTC/government page [V]:
- 16 CFR 251.1 (Free Guide): https://www.law.cornell.edu/cfr/text/16/251.1
- 16 CFR 255.5 (material connections): https://www.law.cornell.edu/cfr/text/16/255.5
- Rite Aid press release: https://www.ftc.gov/news-events/news/press-releases/2023/12/rite-aid-banned-using-ai-facial-recognition-after-ftc-says-retailer-deployed-technology-without
- Avast press release: https://www.ftc.gov/news-events/news/press-releases/2024/02/ftc-order-will-ban-avast-selling-browsing-data-advertising-purposes-require-it-pay-165-million-over
- Operation AI Comply: https://www.ftc.gov/news-events/news/press-releases/2024/09/ftc-announces-crackdown-deceptive-ai-claims-schemes
- Rytr set-aside (Dec 2025): https://www.ftc.gov/news-events/news/press-releases/2025/12/ftc-reopens-sets-aside-rytr-final-order-response-trump-administrations-ai-action-plan
- Zoom FTC blog: https://www.ftc.gov/business-guidance/blog/2020/11/zooming-zooms-unfair-deceptive-security-practices-more-about-ftc-settlement
- Everalbum press release (Jan 2021): https://www.ftc.gov/news-events/news/press-releases/2021/01/california-company-settles-ftc-allegations-it-deceived-consumers-about-use-facial-recognition-photo ; final May 2021: https://www.ftc.gov/news-events/news/press-releases/2021/05/ftc-finalizes-settlement-photo-app-developer-related-misuse-facial-recognition-technology

Search-summary only [S] (page titles/URLs confirmed in results, content not read directly):
- IntelliVision: https://www.ftc.gov/news-events/news/press-releases/2024/12/ftc-takes-action-against-intellivision-technologies-deceptive-claims-about-its-facial-recognition
- accessiBe: https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-order-requires-online-marketer-pay-1-million-deceptive-claims-its-ai-product-could-make-websites ; case page https://www.ftc.gov/legal-library/browse/cases-proceedings/2223156-accessibe-inc
- Workado final order: https://www.ftc.gov/news-events/news/press-releases/2025/08/ftc-approves-final-order-against-workado-llc-which-misrepresented-accuracy-its-artificial
- Biometric Policy Statement: https://www.ftc.gov/legal-library/browse/policy-statement-federal-trade-commission-biometric-information-section-5-federal-trade-commission
- Reviews rule FR notice: https://www.govinfo.gov/content/pkg/FR-2024-08-22/html/2024-18519.htm ; FTC Q&A https://www.ftc.gov/business-guidance/resources/consumer-reviews-testimonials-rule-questions-answers
- Click-to-cancel vacatur and 2026 reopening: https://www.crowell.com/en/insights/client-alerts/eighth-circuit-cancels-click-to-cancel ; https://www.consumerfinancialserviceslawmonitor.com/2026/03/ftc-reopens-negative-option-rulemaking-after-eight-circuit-vacates-2024-amendments/
- Amazon Prime: https://www.alston.com/en/insights/publications/2025/10/ftc-settlement-prime-subscription-practices

Not fetched [U], cited from general knowledge: 15 U.S.C. 45; FTC Deception and Substantiation Policy Statements; Dark Patterns report; Health Products Compliance Guidance; 16 CFR 255.1-255.2; Evolv, Air AI and Cleo AI actions.

Repo files read: README.md, PRIVACY.md, Humanity/OculOS/ManOS/Murmur Resources/Info.plist, UI strings in Swift sources (grep), Murmur Transcriber.swift and MeetingKit FileTranscriber.swift (on-device flag), LicenseKit License.swift, VoiceProfileStore.swift comment. Not done: network capture, full code review of AIKit audio paths, the live Gumroad page.
