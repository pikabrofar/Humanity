# 14. Accessibility and medical-adjacent risk (Humanity: OculOS, ManOS, Murmur)

Prepared 2026-10-01 by a research analyst, not a lawyer. This is not legal advice and makes no finding that anything is "compliant" or "safe". Items marked **[UNVERIFIED]** were not checked against a primary source in this pass. Every item in the attorney-review list (section 7) needs a licensed attorney.

## 0. Bottom line

| Question | Short answer |
|---|---|
| Is Humanity a medical device today? | **Probably not on current repo text**, but intended use is decided by the seller's objective intent (21 CFR 801.4), not by a disclaimer. The shipped README, Info.plist strings and app text contain no disease, disability or medical wording (audit, section 5). |
| What would change that? | Marketing to ALS/SCI/CP/tremor users, saying it "treats," "restores," "compensates for" or "replaces" lost function, or promising reliability for people who depend on it. That moves it toward the powered communication system (21 CFR 890.3710) and powered environmental control system (21 CFR 890.3725) neighborhood. |
| Biggest practical exposure | Not FDA. It is **deceptive or unsubstantiated accessibility claims** (FTC Act s.5, Mass. G.L. c.93A s.2, express warranty) aimed at a vulnerable group, plus reliance injury if someone depends on a webcam tracker that is 2-4 degrees accurate (OculOS README). |
| Biggest repo issue | `research/12-accessibility.md` and `research/README.md` say the product's core users are people with ALS/MND, spinal cord injury, RSI, tremor, cerebral palsy. That file sits in a public MIT repo. It is evidence a regulator or plaintiff could cite on intent. |
| ADA/508 | Title III duties attach to the seller's **website/storefront**, not clearly to the software as a product. Section 508 binds federal agencies, not the seller, but creates **procurement pressure** (VPAT/ACR). The Gumroad page is a third-party template the seller only partly controls. |

## 1. FDA: could this count as a medical device?

### 1.1 Statutory frame

| Provision | What it says | Primary source |
|---|---|---|
| FD&C Act s.201(h) (21 U.S.C. 321(h)) | "Device" = instrument/apparatus/article/etc. that is intended for use in diagnosis, cure, mitigation, treatment or prevention of disease or other conditions, or intended to affect structure/function of the body, and does not achieve its primary purpose through chemical action or metabolism. Final sentence: "device" excludes software functions excluded under s.520(o). | https://www.law.cornell.edu/uscode/text/21/321 |
| FD&C Act s.520(o)(1) (21 U.S.C. 360j(o)) (21st Century Cures Act s.3060) | Software excluded from "device": (A) administrative support; (B) "maintaining or encouraging a healthy lifestyle and ... unrelated to the diagnosis, cure, mitigation, prevention, or treatment of a disease or condition"; (C) electronic patient records; (D) transferring/storing/displaying device data without interpretation; (E) certain clinical decision support for clinicians. | https://www.govinfo.gov/content/pkg/USCODE-2023-title21/html/USCODE-2023-title21-chap9-subchapV-partA-sec360j.htm (also https://www.law.cornell.edu/uscode/text/21/360j) |
| 21 CFR 801.4 | "Intended use" = objective intent of those responsible for labeling. Shown by labeling claims, advertising, oral or written statements, circumstances of distribution, and knowledge of actual use. | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-A/section-801.4 |

Takeaway: the statute is intent-driven. "Mitigation ... of ... conditions" can plausibly cover software sold to compensate for a motor impairment. The only software carve-out that fits a general computer-control tool is (B), and (B) requires the product to be unrelated to a disease or condition, so it **fails once marketing targets a disabled population as such** (analyst reading; attorney to confirm).

### 1.2 21 CFR Part 890 (physical medicine devices) classifications that sit nearby

| Section | Definition (paraphrase) | Class | Note |
|---|---|---|---|
| 890.3725 Powered environmental control system | "AC- or battery-powered device intended for medical purposes that is used by a patient to operate an environmental control function" (room temperature, doorbell/phone, alarms for assistance). | II (special controls); exempt from 510(k) subject to 890.9 limitations | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-D/section-890.3725 (fetched via eCFR API 2026-10-01) |
| 890.3710 Powered communication system | "AC- or battery-powered device intended for medical purposes that is used to transmit or receive information" by people with physical impairments who cannot use conventional methods. | II; 510(k)-exempt subject to 890.9 | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-D/section-890.3710 (fetched 2026-10-01) |
| 890.5050 Daily activity assist device | Modified adaptor/utensil assisting a patient with a specific function (dressing, grooming, eating). | I; 510(k)-exempt | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-F/section-890.5050 (fetched 2026-10-01) |

Key observations:
- Each definition turns on **"intended for medical purposes."** Same words as 801.4: the seller's claims decide it.
- Neither 890.3710 nor 890.3725 is limited to hardware by its text, but both say "AC- or battery-powered device." Whether FDA would treat pure software on a general-purpose Mac as inside these is **[UNVERIFIED]** (no FDA classification letter or 513(g) response was found). Hardware gaze-AAC systems from Tobii Dynavox and similar are the obvious regulated comparators; their exact product codes and clearance status are **[UNVERIFIED]**.
- Humanity does not operate "environmental control functions" (thermostat, door, alarm). It moves a pointer and types text on a Mac. The closer analog is 890.3710 (communication) if sold to people who cannot use a keyboard/mouse, and Murmur dictation is the likeliest "transmit information" feature.
- Even Class II "exempt" devices still carry general controls: establishment registration and listing (21 CFR 807), labeling (21 CFR 801), medical device reporting (21 CFR 803), and a quality system. The QS regulation was amended to align with ISO 13485 as the QMSR, effective 2026-02-02 **[UNVERIFIED, check 21 CFR 820]**. Misbranding/adulteration violations are prohibited acts under 21 U.S.C. 331 (https://www.law.cornell.edu/uscode/text/21/331).
- For a one-person pay-what-you-want seller, being a device would be disproportionate. The practical goal is to **keep intended use clearly outside** the device definition, and to be accurate about that.

### 1.3 FDA policy documents

| Document | Relevance | Source / status |
|---|---|---|
| General Wellness: Policy for Low Risk Devices | Enforcement discretion for products intended only for general wellness and low risk. Revised guidance issued **2026-01-06**, replacing the 2019 version (per law-firm summaries and an FDA page listing it as final guidance). Wellness claims = promoting a healthy state/activity without reference to a disease, plus (per summaries) well-established lifestyle-to-disease-risk links and living well with a chronic condition. | https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices ; summary https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products . I did not read the full 2026 text. Check whether any new example mentions assistive or accessibility tools **[UNVERIFIED]**. |
| Clinical Decision Support software guidance | Revised alongside wellness guidance in January 2026 per summaries. Not relevant: Humanity makes no clinical recommendations. | https://www.kslaw.com/news-and-insights/fda-updates-general-wellness-and-clinical-decision-support-guidance-documents (secondary; not read in full) |
| Policy for Device Software Functions and Mobile Medical Applications | FDA's general software policy: regulates software that meets the device definition and whose functionality poses risk if it fails; exercises enforcement discretion for some low-risk functions. | https://www.fda.gov/media/80958/download (PDF; could not be text-extracted in this pass; I did not confirm any passage on assistive or disability software **[UNVERIFIED]**) |

Why wellness does not rescue a disability pitch: the policy and s.520(o)(1)(B) both turn on being unrelated to a disease or condition. "Hands-free control for people with ALS" names a condition. "Control your Mac with your eyes, hands and voice" names none. A marketing line that is a *general productivity or ergonomic feature* ("reduce reaching for the mouse") is the lane the wellness and general-computing framing leaves open.

### 1.4 How marketing language changes the analysis

| Marketing posture | Likely FDA reading (analyst view, not a determination) |
|---|---|
| General computing/input tool: "control your Mac with eyes, hands and voice using a webcam." | General-purpose software. No medical intended use. |
| Accessibility as one use among many: "also helpful if using a mouse is difficult; works alongside macOS accessibility features." | Probably still general-purpose; claims are modest and non-clinical. Gray zone expands if testimonials from patients are featured. |
| Targeting a disability class: "for people with ALS/MND, spinal cord injury or cerebral palsy." | Moves toward "intended for medical purposes" under 890.3710/890.3725 language. Wellness exclusion unavailable. Expect device analysis. |
| Functional-restoration or clinical claims: "restores independence," "alternative to assistive hardware," "replaces eye-gaze AAC devices," "therapy," "rehab," "treats RSI/tremor." | Strongest device indication. Also an unsubstantiated-claims problem. |
| Health inference: "detects fatigue/droopy eyelids/tremor," "monitors your condition." | Diagnostic/monitoring signals. Highest risk. Note `research/12` recommends fatigue tracking and eyelid warnings (see 5.3); do not market these as health functions. |
| Clinician channel: "OT/caregiver setup mode," selling to clinics, HCPCS/insurance codes. | Reinforces medical intended use, and triggers payer and procurement expectations. |

Also relevant under 801.4: statements by the seller in forum posts, README, GitHub issues, replies to disabled users ("yes this will work for my ALS") and knowledge of actual use. Responding to a disabled user who says they depend on it is not itself a violation, but do not encourage reliance.

### 1.5 Wording to avoid and safer wording

| Avoid | Why | Safer alternative |
|---|---|---|
| "Medical-grade," "clinical," "FDA-ready," "assistive device," "assistive technology device" | Device vocabulary | "Software utility"; "input tool" |
| "For people with ALS / paralysis / motor disabilities" | Names a condition | "Some people use alternative input like this when a mouse is uncomfortable. It is not designed or tested as a replacement for assistive technology." |
| "Hands-free control for disabled users" | Targets class, implies function and reliability | "Optional hands-free pointer and dictation features (webcam, about 2-4 degrees gaze accuracy)." |
| "Restores independence," "life-changing," "lets you communicate" | Function restoration; testimonial-style outcome | Describe features and measured limits only |
| "Replaces Tobii / eye-gaze AAC," "better than head pointer" | Comparative performance claim without substantiation | "Free, Mac-native, webcam-based, less accurate than infrared trackers" (the repo's own research says this) |
| "Reduces RSI / tremor / strain," "ergonomic therapy" | Treatment/mitigation claim | "Another way to move the pointer" |
| "Detects fatigue / eye health / blinks indicating X" | Diagnostic claim | Do not market; keep any such UI behavior labeled as a usage reminder |
| "Accessible," "ADA compliant," "WCAG compliant," "508 compliant" | Legal conclusion; hard to substantiate (accessiBe order) | "We test with VoiceOver and Keyboard; known gaps are listed here." Only claim what you tested |
| "Reliable," "accurate," "works for everyone," "research-grade" (OculOS README feature list) | Absolute/substantiation | Quote measured numbers, conditions and device used, and say results vary |
| "Not a medical device" as the *only* safeguard | Disclaimers do not override contrary claims (801.4 objective intent) | Pair with consistent non-medical marketing |

## 2. ADA and Section 508 duties

### 2.1 The product (the macOS apps)

| Law | Applies to the seller? | Analysis |
|---|---|---|
| ADA Title III (42 U.S.C. 12181-12189) | Only if the seller operates a "place of public accommodation," listed at s.12181(7) (sales or rental establishments, service establishments, etc.). https://www.law.cornell.edu/uscode/text/42/12181 | Title III addresses access to the seller's goods and services, not a duty to design every product for disabled users. Whether downloadable software sold online is covered is unsettled and circuit-dependent (see 2.2). No requirement was found that an app itself must be accessible. **[UNVERIFIED for software-as-product]**. Attorney should confirm. |
| ADA Title II web rule (28 CFR Part 35, Subpart H) | No (state/local governments only). | Relevant as **purchaser pressure**: public universities/agencies buying licenses will ask for WCAG 2.1 AA statements. DOJ moved compliance dates by interim final rule on 2026-04-20: April 26, 2027 for entities serving 50,000 or more, April 26, 2028 for smaller entities and special districts (secondary sources; check the Federal Register notice) **[UNVERIFIED]**. Technical standard remains WCAG 2.1 AA. Summary: https://accessibility.arizona.edu/news/doj-issues-interim-final-rule-title-ii-digital-accessibility-compliance-dates |
| Section 508 (29 U.S.C. 794d; Revised 508 Standards, 36 CFR Part 1194) | **No, not directly.** s.794d covers federal departments/agencies; private vendors are reached only through procurement. https://www.law.cornell.edu/uscode/text/29/794d ; https://www.access-board.gov/ict/ | If a federal agency (or a contractor with 508 flow-down) wants to buy a license, expect a request for an Accessibility Conformance Report (VPAT). Section508.gov says agencies must evaluate ACRs for ICT purchases above the micro-purchase threshold: https://www.section508.gov/buy/ **[confirm threshold wording in FAR 39.2]**. A pay-what-you-want $5+ individual license sold via Gumroad is unlikely to trigger this soon. |
| Section 504 (29 U.S.C. 794) | Only if the seller receives federal financial assistance. | No indication in the brief. **[UNVERIFIED]** |
| State law | Massachusetts public accommodation law (G.L. c.272 ss.92A, 98) and the Mass. AG. | **[UNVERIFIED: statute text not fetched]**. Confirm treatment of websites/online sales. |
| EU European Accessibility Act (Directive 2019/882) | Not now (US first). | Applies from 2025-06-28 to certain consumer products/services including e-commerce services and consumer general-purpose computer operating systems; microenterprise exemptions exist for services. Relevant at international launch. **[UNVERIFIED: not fetched; https://eur-lex.europa.eu/eli/dir/2019/882/oj]** |

Practical point: even without a legal duty, the app's own settings and permission flows should work with VoiceOver, Full Keyboard Access and Switch Control. Customers who need alternative input are the most likely to use those, and the product's own pitch is accessibility-adjacent. `research/12` item 6 already recommends this. Treat "make settings fully VoiceOver-labelled" as a launch task if any accessibility positioning is kept.

### 2.2 The seller's website and Gumroad page

| Issue | Analysis |
|---|---|
| Is a website a Title III "place of public accommodation"? | Circuit split. Ninth (Robles v. Domino's, 913 F.3d 898 (2019)) requires a nexus with a physical place but found one; Eleventh (Gil v. Winn-Dixie, 21 F.4th 775 (2021)) held a standalone website is not a place of public accommodation; the First Circuit (which covers Massachusetts) has said public accommodations are not limited to physical structures (Carparts Distribution Ctr. v. Automotive Wholesaler's Ass'n, 37 F.3d 12 (1994)); D. Mass. applied that to Netflix streaming (National Ass'n of the Deaf v. Netflix, 869 F. Supp. 2d 196 (2012)). **[All case citations from memory, UNVERIFIED. Pull opinions on CourtListener/Justia before relying.]** Net: a Massachusetts seller of online goods is in the more plaintiff-friendly circuit. |
| Standard | No DOJ Title III web regulation. Courts and settlements generally use WCAG 2.1 AA as the benchmark. |
| Litigation volume | Secondary sources report about 3,100 federal website-accessibility suits in 2025 (Seyfarth) and about 5,000 Title III filings in H1 2026 **[UNVERIFIED: secondary web summaries; the two figures use different definitions, do not compare]**. Individual sellers with small sites are a known target of serial plaintiffs and demand letters. |
| Remedies | Title III private suits give injunctive relief and attorney's fees, not damages (42 U.S.C. 12188(a); https://www.law.cornell.edu/uscode/text/42/12188). State law may add damages (e.g., California Unruh, not Massachusetts-specific). **[Mass. remedies UNVERIFIED]** |
| Gumroad page | Seller controls: page text, headings, image alt text, video captions, contrast within Gumroad's editor options, contact method. Gumroad controls the checkout, template and overlay. Gumroad publishes an accessibility statement saying it **partially conforms to WCAG 2.1 AA**: https://gumroad.com/help/article/324-accessibiility-statement . That helps but does not shift the seller's own content obligations. Also review Gumroad's terms for the seller's responsibilities **[UNVERIFIED]**. |
| GitHub repo / README | Same Title III question; low cost to keep headings, alt text on images and descriptive link text. |

Recommended seller-side steps (cheap):
1. Gumroad page: plain headings, real text instead of images of text, alt text, captions or transcripts for demo videos, descriptive link text, no flashing media.
2. Publish a short accessibility statement: what has been tested (e.g., VoiceOver pass on settings), known gaps, and an email for help or alternative-format requests with a promised response time. Do not say "compliant."
3. Offer a non-web path to buy or get help (email) for customers who cannot use the checkout.
4. Test the Gumroad page with an automated checker and a manual keyboard/VoiceOver pass; keep dated notes. Avoid overlay "accessibility widgets" (see the FTC accessiBe action, section 3).

## 3. Risks of making accessibility claims the product may not reliably meet

Facts from the repo: OculOS states typical accuracy of **2-4 degrees, about 80-150 pt on a laptop, enough to tell the region but not the word** (`OculOS/README.md` lines 47-49). `research/12` and `research/00-competitors.md` say webcam tracking is less accurate than infrared AAC hardware, that Camera Mouse had an 8.1% dwell error rate, and that Leap-style hand pointing has higher error rates than a mouse. ManOS and OculOS are labeled **Beta**. The apps are not notarized yet. Any hands-free claim should match those facts.

| Risk | Basis | Notes |
|---|---|---|
| FTC deception / lack of substantiation | FTC Act s.5 (15 U.S.C. 45). https://www.law.cornell.edu/uscode/text/15/45 . FTC v. accessiBe: January 2025 complaint and order, final April 2025, **$1 million** for unsubstantiated claims that an AI tool made websites WCAG compliant. https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-order-requires-online-marketer-pay-1-million-deceptive-claims-its-ai-product-could-make-websites | Directly on point: accessibility claims need competent evidence, and "works for disabled users" is a claim about performance. FTC reach over a sole proprietor is real but enforcement against tiny sellers is uncommon; the standard still shapes what a plaintiff or AG would argue. |
| Massachusetts consumer protection | G.L. c.93A s.2(a) prohibits unfair or deceptive acts; courts and the AG look to FTC standards. https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section2 . Consumer private action is s.9 (30-day demand letter, up to double or treble damages for willful or knowing violations, attorney's fees). https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section9 **[s.9 mechanics from memory, UNVERIFIED]** | Likely the most plausible civil claim for a Massachusetts seller; disabled consumers being targeted is an aggravating narrative. |
| Express warranty | UCC s.2-313 (Mass. G.L. c.106 s.2-313): affirmations of fact become part of the bargain. Whether downloadable software is "goods" in Massachusetts is **[UNVERIFIED]**. | Statements like "controls your Mac hands-free" on the Gumroad page can be read as promises. |
| Competitor false advertising | Lanham Act s.43(a) (15 U.S.C. 1125(a)). | Comparative claims against Tobii, Talon, Apple Head Pointer. Keep comparisons factual and sourced. |
| Reliance injury | Negligence / failure-to-warn theories if a user relies on the tool to summon help or to operate essential communication, and it fails (a miscalibrated cursor, a crash that leaves input captured, a false click). | See section 4. The "taking over input with no exit" risk is named in `research/12`; implement the recommended pause/exit paths. |
| Misleading "ADA compliant" / "WCAG compliant" claims | accessiBe order above. | Use evidence-limited statements only. |
| Marketplace/platform rules | Gumroad terms and any app-store or payment-processor policies on health claims. | **[UNVERIFIED]** |
| Testimonials | FTC Endorsement Guides (16 CFR Part 255). https://www.ecfr.gov/current/title-16/chapter-I/subchapter-B/part-255 | Disabled-user testimonials make outcome claims; require typical-results disclosure and material-connection disclosure. Avoid. |

Process controls:
- Keep an **evidence file** for every performance number (device, camera, lighting, n, date). `research/18-evaluation.md` already recommends honest benchmarking; use it.
- Keep claims at the level of "what it does" plus "measured limits," and put limits next to the claim, not in a footer.
- Do not ask or imply that disabled people should buy the product on the basis of unrelated research reports.
- Pay-what-you-want $5 minimum and a free DMG reduce stakes but do not remove consumer-protection exposure.

## 4. Safety disclaimers

A disclaimer is a risk reducer, not a shield. It does not change intended use (801.4), cannot disclaim 93A liability for deceptive conduct, and may not be effective against implied warranty in a consumer sale (Mass. G.L. c.106 s.2-316 and s.2-316A **[UNVERIFIED]**). The MIT license "AS IS" text governs the source code, and its effect on paying DMG customers is an attorney question. Put disclaimers where users see them: on the Gumroad page, at first launch of OculOS/ManOS, and in each README, in plain language, near the feature.

| Disclaimer | Recommended text (draft for attorney review) | Where |
|---|---|---|
| Not for emergencies | "Humanity is not designed for emergencies or safety-critical use. Do not use it to call for help, control medical equipment or operate anything where a missed or accidental input could cause harm. Keep a phone or other reliable way to get help within reach." | Gumroad page, first launch, OculOS/ManOS README |
| Not a medical device | "Humanity is general-purpose software. It is not a medical device, is not intended to diagnose, treat or monitor any condition, and has not been evaluated by the FDA." | Gumroad page footer, About, README. Keep consistent with the marketing. |
| Not your only input method | "Webcam tracking can fail or drift because of lighting, glasses, camera quality, posture, fatigue or software updates. Keep another way to operate your computer (keyboard, trackpad, macOS Dwell Control, Switch Control, Voice Control) and know how to pause or quit Humanity." | First launch (acknowledge once), OculOS/ManOS README |
| Accuracy limits | "Eye tracking accuracy is typically 2-4 degrees on a laptop, enough to tell the screen region but not individual words. ManOS pointing is less precise than a mouse. Results vary." | Next to any claim of hands-free control |
| Beta | "Beta software. It may mis-click, miss gestures or stop responding." | Gumroad page, About |
| Not a substitute for AT | "Not a replacement for assistive technology that was prescribed or recommended for you. Talk to your therapist or AT provider about your needs." | Gumroad page, README |
| Unintended input | "Humanity can click and type for you. Pause it (menu bar or hotkey) before using sensitive apps such as banking or messaging, and anywhere an accidental click could cost you something." | First launch, README |

Product behaviors that make the disclaimers credible (from `research/12`, `research/00-competitors.md`; check whether each is built):
- A pause/kill control that is reachable by a method other than the one being paused (menu-bar item and hotkey).
- Start paused after launch or wake; never lock the user out; recovery after crash; macOS Dwell or Switch Control fallback.
- Undo for unintended selections.
- Clear in-app indication when synthetic input is active, and an explicit "calibration quality: poor" warning.

## 5. Repo audit: wording that could imply medical or assistive-device status

Scope: `README.md`, `ManOS/README.md`, `OculOS/README.md`, `Murmur/README.md`, `PRIVACY.md`, `SECURITY.md`, `AIKit/README.md`, `MeetingKit/README.md`, `Info.plist` files in `Humanity/`, `ManOS/`, `OculOS/`, `Murmur/` Resources, and `research/*.md`. Method: keyword grep (disab*, medical, assist*, clinic*, patient, ALS, paralys*, hands-free, health, therapy, diagnos*, treat*, rehab*, impair*, motor, RSI, injur*, emergenc*, wheelchair, neuro*) plus reading the lead sections. Swift sources were grepped for UI strings and returned no matches, but that grep **errored on the first attempt and was not re-run with a corrected pattern, so source-string coverage is UNVERIFIED**.

### 5.1 README and Info.plist (user-facing): low risk

| File | Text | Assessment |
|---|---|---|
| `README.md` line 3-6 | "Open-source macOS software for controlling your computer with your eyes, hands and voice, using just a webcam and microphone." | General-purpose framing. No disability or medical term. Keep. |
| `README.md` table | "Eye tracking: calibrated gaze cursor, heatmaps, recordings"; "Hand-gesture mouse"; Status "Beta" | Fine. The Beta label supports accuracy limits. |
| `OculOS/README.md` line 5 | "**Research-grade calibration**" | Superlative; accuracy is 2-4 degrees. Rephrase ("Calibration with held-out validation that reports accuracy in degrees"). Substantiation risk, not device risk. |
| `OculOS/README.md` line 8 | "**Robust to human error**" | Unquantified. Consider "retries missed points." |
| `OculOS/README.md` lines 47-49 | "Expect roughly 2-4° ... enough to tell which region ... not which word." | Good, honest limit. Keep and echo on the Gumroad page. |
| `ManOS/README.md` lines 3-5 | "Control your Mac with your hand through the webcam ..." | Neutral. |
| `PRIVACY.md` line 59-60 | "Accessibility (ManOS, Murmur, OculOS): moving the pointer, clicking ..." | This refers to the **macOS Accessibility permission (TCC)**, not a claim of accessibility. A reader could blur the two. Consider "macOS Accessibility permission (lets the app control the pointer and send keys)." |
| `README.md` lines 51-60; `SECURITY.md` line 3 | "Accessibility" permission wording; `README.md` line 60 lists "accessibility" as a research topic | Same TCC point; the line-60 research reference is where accessibility-for-disabled-users first appears publicly. |
| `Humanity/Resources/Info.plist`, `ManOS`, `OculOS`, `Murmur` | Camera, microphone, speech, audio usage strings ("uses the camera to track your eyes and hands ... never saved or uploaded") | No medical or assistive wording. Privacy statements are covered by other research files; "never saved" should be checked against actual behavior (OculOS can store eye patches and recordings, see `PRIVACY.md` line 36). Cross-reference the privacy file. |
| No "Not a medical device," "not for emergencies," or "keep another input method" text anywhere in README/Info.plist | Gap | Add per section 4. |

### 5.2 `research/` files that are the main concern (public in MIT repo)

| File:line | Text | Issue | Recommended fix |
|---|---|---|---|
| `research/12-accessibility.md` line 1 and line 4 | "Accessibility-First Design for OculOS and ManOS"; "The people who need OculOS and ManOS most have ALS/MND, spinal cord injury, RSI, tremor or cerebral palsy." | Names conditions and says the product is for them. Under 801.4, public written statements by the developer can show intended use. | Reframe as "design research informed by assistive-technology literature. Humanity is general-purpose software and not a medical device." Remove "need ... most" language, or move the file out of the public repo. |
| `research/12` item 8 "Fatigue awareness"; item 7 "warn about glare, low light or droopy eyelids"; item 10 "OT/caregiver setup mode" | Health-state inference and clinical-workflow features | These would create diagnostic/monitoring functions and clinical-channel evidence if built. | Build as neutral "take a break" and "poor lighting" prompts. Avoid eyelid or health framing in UI and docs. Do not call anything a caregiver or therapy mode. |
| `research/12` heading "Things to avoid" item 3 | "Taking over input with no exit" | Positive: a safety design intent. | Implement; reference in disclaimers. |
| `research/README.md` line 23 | "Users with motor disabilities" as a topic row | Public index highlights target group. | "Accessibility-oriented design research." |
| `research/README.md` lines 42-77 | Mixed ✅ status marks, e.g. "Camera Reactions disabled via Info.plist (14)" | Not medical. Note: the ✅ list says features are done; make sure it is accurate before any public reliance. | Fine. |
| `research/00-competitors.md` | Compares with Tobii (AAC), Camera Mouse, Head Pointer: "The free baseline to beat" and "Beat Head Pointer on setup speed and precision" | Comparative-performance posture against assistive products. Internal ambition, but wording would be risky if repeated in marketing. | Do not repeat in public marketing without a substantiated test. |
| `research/11-jitter-latency.md` line 47 | Link to MSD Manuals page on tremor | Medical reference for design purposes. | Neutral. |
| `research/17-privacy-security.md` item 9 | "State that Humanity does not identify users, does not infer emotion or health" | Positive and consistent with a non-medical posture. | Keep and actually make true. Note that same file (line 13) says gaze data can reveal health conditions: strengthens the case to never market health inference. |
| `research/02`, `research/05`, `research/07`, `research/13` | Use of terms like "clinical", "Midas touch", "scanpath" in HCI sense | HCI vocabulary, no device implication. | None. |

### 5.3 Related feature design to watch

- Dictation (Murmur): "voice notes," meetings, summaries. Not medical. Do not position as a communication aid for non-speaking or speech-impaired people (890.3710 neighborhood).
- OculOS recordings, heatmaps, scanpaths: framed as UX/research analytics. Avoid wording like "attention disorder," "reading difficulty," or "neurological" anywhere in marketing.
- Eye-image patches and gaze recordings may be treated as sensitive health-adjacent or biometric data under privacy laws. That analysis belongs in the privacy research file, not here.

## 6. Recommended product and document changes

| # | Change | Priority |
|---|---|---|
| 1 | Add the section-4 disclaimers to the Gumroad page, first-run screen in OculOS/ManOS, and each module README. | High |
| 2 | Rewrite or relocate `research/12-accessibility.md` and `research/README.md` line 23 as described in 5.2. Do this before wider promotion. | High |
| 3 | Adopt a written "claims policy": no disease or disability names in marketing, no compliance words, every performance claim traced to a dated test. | High |
| 4 | Replace "Research-grade," "Robust to human error" in `OculOS/README.md`, or back them with citations/data. | Medium |
| 5 | Ensure pause hotkey/menu item, start-paused, and crash recovery exist (from `research/12`). Verify by test. | High |
| 6 | Add VoiceOver and Full Keyboard Access labels/settings pass; publish a dated, factual accessibility note with known gaps. | Medium |
| 7 | Gumroad page and GitHub README: accessible text, alt text, captions; email contact for alternative help. | Medium |
| 8 | Clarify `PRIVACY.md` "Accessibility" line to refer to the macOS permission. | Low |
| 9 | Do not use customer testimonials from disabled users, or do so only after counsel review. | Medium |
| 10 | Keep a short intended-use statement in the repo: "Humanity is a general-purpose computer input and dictation tool." | High |
| 11 | If the seller ever wants to market to disabled users explicitly, run a **513(g) request for information** or seek FDA/regulatory counsel first. 513(g): https://www.fda.gov/medical-devices/device-advice-comprehensive-regulatory-assistance/requests-information-513g **[UNVERIFIED page text]** | Contingent |

## 7. Attorney-review flags

1. Whether FDA would treat pure software on a general-purpose Mac as a "device" within 890.3710/890.3725 if marketed to disabled users, and whether any FDA letter exists on mouse-emulation or gaze-input software.
2. Whether a public research file with disability-focused statements is meaningful evidence of "intended use" for an MIT-licensed open-source project, and how the open-source status affects who is the labeler/manufacturer.
3. Title III coverage for a Massachusetts individual selling downloadable software through Gumroad, and the First Circuit's current authority (verify Carparts, Netflix and any 2025-2026 cases).
4. Mass. G.L. c.93A s.9 exposure, c.106 warranty disclaimers (ss.2-313, 2-316, 2-316A), and whether software is "goods."
5. Wording of the disclaimers, and whether MIT "AS IS" language is adequately incorporated into the paid license terms.
6. Whether the pay-what-you-want model plus a free DMG affects consumer-protection analysis.
7. Plans for EU launch: European Accessibility Act scope and microenterprise status.
8. Whether any state law applies to health-adjacent claims or to biometric/eye data collected from disabled users (cross-reference the privacy memos).

## 8. Sources verified (fetched or searched 2026-10-01 unless noted)

| Item | URL | Status |
|---|---|---|
| FD&C Act s.201(h), 21 U.S.C. 321(h) | https://www.law.cornell.edu/uscode/text/21/321 | Fetched |
| 21 U.S.C. 360j(o)(1) | https://www.govinfo.gov/content/pkg/USCODE-2023-title21/html/USCODE-2023-title21-chap9-subchapV-partA-sec360j.htm | Fetched (2023 edition; 2025-2026 amendments not checked) |
| 21 CFR 890.3725 | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-D/section-890.3725 | Fetched |
| 21 CFR 890.3710 | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-D/section-890.3710 | Fetched |
| 21 CFR 890.5050 | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-890/subpart-F/section-890.5050 | Fetched |
| 21 CFR 801.4 | https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-A/section-801.4 | Fetched |
| FDA General Wellness guidance (Jan 2026) | https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices ; https://www.cov.com/en/news-and-insights/insights/2026/01/fda-issues-revised-guidance-on-general-wellness-products | FDA page summarized; full text not read |
| FDA Mobile Medical Apps / device software policy | https://www.fda.gov/media/80958/download | Located; text not extracted |
| 42 U.S.C. 12181(7) | https://www.law.cornell.edu/uscode/text/42/12181 | Fetched |
| 29 U.S.C. 794d | https://www.law.cornell.edu/uscode/text/29/794d | Fetched |
| Section 508 procurement | https://www.section508.gov/buy/ ; https://www.access-board.gov/ict/ | Search result only |
| DOJ Title II interim final rule (April 2026 date shift) | https://accessibility.arizona.edu/news/doj-issues-interim-final-rule-title-ii-digital-accessibility-compliance-dates | Secondary source; Federal Register notice not located |
| FTC accessiBe order | https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-order-requires-online-marketer-pay-1-million-deceptive-claims-its-ai-product-could-make-websites | Found in search; details from secondary summaries |
| Mass. G.L. c.93A s.2 | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section2 | Fetched |
| Gumroad accessibility statement | https://gumroad.com/help/article/324-accessibiility-statement | Search snippet only |
| Title III litigation counts, circuit-split summary | https://natlawreview.com/article/circuit-courts-split-standing-to-sue-ada-title-iii-website-accessibility-claims ; https://www.americanbar.org/groups/business_law/resources/business-law-today/2025-august/digital-accessibility-under-title-iii-ada/ | Search snippets only; **UNVERIFIED** |

Not verified in this pass: case citations in section 2.2, Mass. G.L. c.272 and c.106 provisions, 15 U.S.C. 45 and 1125 text, 16 CFR Part 255, 42 U.S.C. 12188, QMSR effective date, EU Directive 2019/882 scope, 513(g) page, whether FDA classified any gaze-input software, and any post-June-2026 amendments or cases.
