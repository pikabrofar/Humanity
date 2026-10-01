# 07 - MA Consumer Contracts, Consumer Protection, EULA / Terms Enforceability

Prepared 2026-10-01. Research analyst notes, not legal advice; nothing here says the product "is compliant" or "safe." Items marked **[UNVERIFIED]** were not confirmed against primary text in this pass (several official sites returned 403/404 to the fetch tool, so some points rest on secondary summaries of primary text).

Product facts assumed (from brief): individual MA developer, no entity; $5+ pay-what-you-want via Gumroad license keys; free DMG, key required; US consumers first; MIT-licensed source on GitHub; not notarized yet.

---

## 0. Bottom line (for the person drafting Terms)

1. **Chapter 93A section 9 is the dominant risk, not the EULA.** A sole proprietor has unlimited personal liability (no LLC), and a consumer can recover actual damages (or $25 minimum), double/treble damages for willful/knowing violations or bad-faith refusal to settle, plus attorney fees. At a $5 price, actual damages are tiny, but the fee-shifting and class vehicle are what matter.
2. **Warranty disclaimers: assume they will not work against a MA consumer** if a court treats the software as "consumer goods" under c.106 sec. 2-316A (which voids "as is"/disclaimer language for implied merchantability and fitness). Whether a downloaded license is "goods" is unsettled; do not rely on the argument either way. Draft the disclaimer anyway (useful elsewhere, and outside MA), but design the product and the refund path so the implied warranty is not the thing you are betting on.
3. **Enforceability of the Terms in MA turns on Kauders v. Uber (2021) and Good v. Uber (2024):** reasonable notice plus reasonable manifestation of assent. A true clickwrap (checkbox or "I agree" button, link right next to it, uncluttered screen, cannot proceed without acting) is the strongest form and was upheld in Good. Section 3 below gives a concrete spec.
4. **Arbitration + class waiver: probably not worth it at $5** for this seller (no company, no legal budget, arbitration fees and mass-arbitration risk, 93A fee-shifting, and a legal-drafting cost). A simpler path: MA law, small-claims friendly, a prompt refund policy, and a 93A-friendly dispute process. See section 4.
5. **Limitation-of-liability caps** are enforceable at most against "relatively innocent" violations and cannot reliably cap 93A multiple damages for willful/knowing conduct; in the consumer context courts are skeptical of waivers of 93A rights. A cap of "amount paid (min $5)" is fine as a drafting default, but expect it to bind only ordinary contract/negligence claims.
6. **Refunds:** no general MA statutory cooling-off right for digital downloads was found, but 940 CMR 3.13(4) requires the refund policy to be clearly and conspicuously disclosed before purchase, accurate, and honored. Gumroad also forces a 30-day policy on accounts with high dispute rates. Recommend a stated 30-day no-questions refund (cheap at $5; avoids chargebacks and 93A demand letters).

---

## 1. Chapter 93A and 940 CMR

### 1.1 Statute

| Point | Rule | Source |
|---|---|---|
| Prohibition | G.L. c.93A sec. 2(a): unfair methods of competition and unfair or deceptive acts or practices in trade or commerce are unlawful. | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section2 |
| Consumer private action | Sec. 9: any person injured by a violation may sue. Seller of consumer software is "trade or commerce"; one individual is a "person." | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section9 |
| Demand letter | Sec. 9(3): at least **30 days** before filing, claimant mails/delivers written demand identifying claimant, reasonably describing the act and the injury. (Exception where respondent has no MA place of business/assets - not relevant to a MA resident.) | same |
| Response / tender | Sec. 9(3): respondent has **30 days** to make a written tender of settlement. If tender is rejected and court finds it reasonable relative to the injury, recovery is limited to the tender. | same |
| Damages | Sec. 9(3): actual damages **or $25, whichever is greater**; **double to treble** if violation was willful or knowing, or if refusal to grant relief on demand was in bad faith with knowledge or reason to know the act violated sec. 2. | same |
| Fees | Sec. 9(4): reasonable attorney fees and costs to a prevailing claimant (with limits for fees after a reasonable tender was rejected). | same |
| Class action | Sec. 9(2): class actions allowed for similar injury to numerous persons; court-approved settlement/dismissal. | same |
| Business plaintiff | Sec. 11 applies to business-vs-business (no demand-letter requirement, different damages rules). A consumer buyer is sec. 9. A business buyer (e.g., a clinic using OculOS for work) could sue under sec. 11, where limitation-of-liability clauses fare somewhat better (see 5). | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section11 |

Practical consequence: **the demand letter is the settlement window.** Whoever handles support email should recognize a 93A demand letter (look for "93A" / "demand for relief"), calendar 30 days from receipt, and consider a prompt reasonable tender (full refund plus a modest amount) which caps exposure. Attorney consult recommended on receipt of any demand letter.

### 1.2 Regulations (940 CMR, AG)

| Reg | Relevance | Source |
|---|---|---|
| 940 CMR 3.02 (false advertising) / 3.05 (general misrepresentations) | Marketing claims for eye tracking accuracy, "no data leaves your Mac," "no telemetry," etc. are 93A-regulated representations; they must be literally true. PRIVACY.md and the Gumroad listing must match actual behavior (AIKit sends transcript text to third parties on the user's own key; LicenseKit calls Gumroad; Hugging Face downloads). | https://www.mass.gov/doc/940-cmr-3-consumer-protection-general-regulations/download |
| 940 CMR 3.08 (repairs/services incl. warranties and service contracts) | Warranty-related practices; check whether it reaches software. **[UNVERIFIED applicability to software; text not retrieved]** | same |
| 940 CMR 3.13(4) (pricing; refund, return and cancellation privileges) | Unfair/deceptive to (a) fail to clearly and conspicuously disclose, **before the transaction is consummated**, the exact nature and extent of the refund/return/cancellation policy; (b) misrepresent it; (c) fail to perform promised privileges. | https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-13 |
| 940 CMR 3.16 | Act is a 93A violation if oppressive/unconscionable, if it fails to disclose facts that may have influenced the buyer's decision, or if it violates laws meant to protect public health, safety or welfare. **The nondisclosure prong matters:** unnotarized app (Gatekeeper warnings), webcam/mic/accessibility permissions, voiceprints of third parties, AIKit third-party transfer, and "key required" despite free download are facts a buyer might consider material; disclose them pre-purchase. | https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-16 |
| **940 CMR 38.00** (unfair and deceptive fees; trial offers; negative option), effective **Sept 2, 2025** | Requires "Total Price" (all mandatory fees) to be clearly disclosed when price is shown; sets rules for free trials and negative-option features (auto-renewal etc.). Applies to advertising/offers targeted to or resulting in a sale in MA for personal/family/household use. Humanity: one-time pay-what-you-want key with no subscription, so negative-option rules are likely not triggered **unless you add a trial, subscription, or upgrade plan**. Price display: show "$5 minimum" and any extra fee/tax up front (Gumroad as merchant of record adds tax at checkout; confirm it is displayed before final click). **[UNVERIFIED: full text of 38.00 not retrieved; AG guidance doc returned 403. Read the regulation before launching any trial/subscription.]** | https://www.mass.gov/regulations/940-CMR-3800-unfair-and-deceptive-fees ; https://www.law.cornell.edu/regulations/massachusetts/940-CMR-38-03 |
| 940 CMR 3.00 on "online sales" | No MA-specific distance-selling cooling-off rule was found in 3.00; online sales fall under the general rules above. **[UNVERIFIED negative; attorney to confirm]** | |

Also relevant: sec. 2 safe harbor and "unfairness" are fact-driven; AG enforcement (sec. 4) is separate from private suits and carries civil penalties. A sole proprietor with no LLC would be personally liable for both.

### 1.3 Recommendations
- Treat every public statement (README, Gumroad page, in-app copy) as a 93A "representation." Make privacy and capability claims narrow and true; align with PRIVACY.md.
- Put a pre-purchase "Before you buy" block on the Gumroad page: requires Accessibility/Camera/Mic permissions, not notarized (Gatekeeper override steps) until that changes, third-party transfer only via AIKit, refund policy.
- Maintain a one-page internal 93A-demand procedure (30-day clock, tender approach, who to call).
- Strongly consider forming an LLC before sales scale (liability shield does not stop a 93A claim based on one's own deceptive act, but limits contract/product exposure). Attorney flag.

---

## 2. Do warranty disclaimers hold up for consumer software?

### 2.1 UCC Article 2 and software
- MA Article 2 is G.L. c.106, art. 2, applying to "transactions in goods" (sec. 2-102). Courts split on whether software is a "good." The Third Circuit in Advent Systems v. Unisys, 925 F.2d 670 (3d Cir. 1991) treated software as a good (https://openjurist.org/925/f2d/670/advent-systems-limited-90-1069-v-unisys-corporation-90-1070). Secondary sources report a MA court applying Article 2 to software without discussion **[UNVERIFIED; no specific MA SJC holding located]**. Licenses (vs sales) and SaaS fare worse for the "goods" characterization; a one-time purchased key for a downloaded app is the case most likely to be treated as a sale of goods.
- Uncertainty cuts both ways: a MA consumer will plead implied warranty (c.106 sec. 2-314 merchantability, sec. 2-315 fitness) and 93A together. Article 2 warranty claims may be brought by household members and guests under sec. 2-318 (MA's broad version) **[UNVERIFIED text]**.
- MA has no UCITA. (UCITA adopted only in MD and VA.) **[UNVERIFIED in this pass; commonly stated.]**

### 2.2 G.L. c.106 sec. 2-316A
Text (verified): sec. 2-316A(2): "Any language, oral or written, used by a seller or manufacturer of consumer goods and services, which attempts to exclude or modify any implied warranties of merchantability and fitness for a particular purpose or to exclude or modify the consumer's remedies for breach of those warranties, shall be unenforceable." Subsection (1): sec. 2-316 does not apply to the extent provided. Source: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter106/Article2/Section2-316A
Also (from search summary, **[UNVERIFIED in full]**): a manufacturer's limits on remedies for breach of *express* warranty are unenforceable unless the manufacturer maintains facilities in MA sufficient for reasonable performance.

Application:
- If Humanity's key/app is "consumer goods," a conspicuous "AS IS" clause **does not disclaim** the implied warranty and cannot cut off remedies for it; the implied warranty of merchantability (fit for ordinary purposes) would attach. Plausible breach theories: app crashes, gesture control misfires, dictation inaccurate, unnotarized build blocked by Gatekeeper, eye tracking not working on a given camera.
- Mitigation is *scope and expectation-setting*, not disclaimer: what is "ordinary purpose" for beta-quality accessibility/assistive software is shaped by what you represent. Accurate system requirements, accuracy caveats (not a medical/assistive device), and trial-before-buy (refund) reduce breach claims. Express-warranty-by-marketing is separate (sec. 2-313) and not disclaimable.
- Still keep an "as is / no warranty to the extent permitted by law" clause, with a savings sentence: "Some jurisdictions, including Massachusetts, do not allow exclusion of implied warranties, so this may not apply to you." This honest savings language avoids a 93A misrepresentation-of-rights argument (an unenforceable clause presented as binding can itself be argued deceptive; **[UNVERIFIED as to MA authority]**).
- MIT source license is a separate no-warranty license for the code; it does not control the sale of keys/binaries. Terms must say which governs what.

### 2.3 Magnuson-Moss (15 U.S.C. sec. 2301 et seq.)
- Covers written warranties on "consumer products" = tangible personal property normally used for personal/family/household purposes (verified via search summary; statute https://uscode.house.gov/view.xhtml?req=granuleid:USC-prelim-title15-chapter50 and 16 CFR Part 700 https://www.ecfr.gov/current/title-16/chapter-I/subchapter-G/part-700).
- A pure download/license key is likely not "tangible" personal property; FTC position on software on disks vs downloads is unsettled **[UNVERIFIED; check FTC Rule 702/703 materials]**. Likely not applicable unless you ship physical media (you do not).
- Key rule if applicable: sec. 2308 bars a supplier who gives a written warranty (or sells a service contract) from disclaiming implied warranties (limited to the warranty duration). **Avoid the word "warranty" in marketing** ("works great, guaranteed") and instead say "30-day refund." Do not grant a written "limited warranty"; that would invite MMWA formalities (pre-sale availability, "full/limited" designation) if a court deemed it applicable.

### 2.4 Recommended clause (to be reviewed by attorney)
"THE SOFTWARE IS PROVIDED 'AS IS' TO THE EXTENT PERMITTED BY APPLICABLE LAW. We make no promise that it will meet your needs or run without interruption. Some places, including Massachusetts, do not allow limits on implied warranties, so some of this may not apply to you, and you may have other rights. The refund policy below is your main remedy if the software does not work for you." (Conspicuous: bold or caps is a UCC sec. 2-316 convention, but 2-316A makes it moot for MA consumers.)

---

## 3. Clickwrap / browsewrap in MA (Kauders v. Uber, and Good v. Uber)

### 3.1 Cases
| Case | Holding | Source |
|---|---|---|
| **Kauders v. Uber Techs., Inc., 486 Mass. 557 (2021)** (SJC) | Enforceability of an online contract requires (1) **reasonable notice** of the terms and (2) **reasonable manifestation of assent**. Uber's account-creation flow failed both: terms link at bottom of the "Link Payment" screen competing with payment fields; the sentence about agreement and link were visually de-emphasized; a user could complete the flow without focusing on the link; the button said "DONE," not "I agree," and did not signal acceptance of contract terms. The court contrasted Uber's driver flow with multiple "YES, I AGREE" clicks. A clickwrap (user clearly informed of existence and location of terms and required to click "I agree" or equivalent) is clearest. | https://caselaw.findlaw.com/court/ma-supreme-judicial-court/2105839.html ; summary https://bostonbar.org/journal/enforceability-of-online-contracts-under-massachusetts-law-kauders-v-uber-technologies-inc/ |
| **Good v. Uber Techs., Inc., 494 Mass. 116 (2024)** (SJC, 5-1) | Upheld arbitration in a **blocking pop-up clickwrap**: focused, uncluttered screen, multiple references to terms, standard blue underlined hyperlinks, check the box then click "Confirm," language saying agreement required to proceed. Reasonable notice does not require highlighting particular provisions; the offeror may make terms "readily available." Delegation: arbitrator decides enforceability challenges not aimed at the arbitration clause itself. Dissent: hyperlinks alone don't convey surprising liability waivers. | https://law.justia.com/cases/massachusetts/supreme-court/volumes/494/494mass116.html (page 403'd; summary via https://caselaw.findlaw.com/court/ma-supreme-judicial-court/116245938.html) |

Browsewrap (terms only linked in a footer, assent by use): weak under the Kauders test; avoid. "Sign-in-wrap" (button + proximate notice "By clicking X you agree to Terms") is in between; Kauders criticized a button that did not itself signal agreement. Choose full clickwrap.

Check for any 2025-2026 MA appellate follow-ons (none found in this pass). **[UNVERIFIED: no search for Appeals Court 2025-26 decisions applying Kauders/Good]**

### 3.2 Gumroad checkout - what you control and what you don't
- Gumroad is merchant of record since Jan 1, 2025 and has its own buyer-facing terms/checkout (https://gumroad.gumroad.com/p/gumroad-is-becoming-a-merchant-of-record-more-updates). The checkout page layout is **Gumroad's, not yours**; you likely cannot add a mandatory "I agree to Terms" checkbox. **[UNVERIFIED: whether Gumroad offers a required-checkbox/terms field or custom fields.]** Check product settings for a required custom field (some Gumroad "custom fields" can be marked required, which can serve as a checkbox-like acknowledgement) and the "Content/receipt" text.
- Practical stance: do **not** make Gumroad checkout the sole assent point. Use it for (a) pre-purchase disclosure (price, refund, permissions, privacy summary, link to Terms) and (b) a required checkbox if available; make the **in-app license activation screen the binding clickwrap**, with an express refund path if the user declines (see 3.4).
- Gumroad refund policy: creator sets it; Gumroad may impose a 30-day money-back policy where disputes exceed ~1% (secondary sources; **[UNVERIFIED against Gumroad's own policy page]**). Gumroad keeps fees on refunds.

### 3.3 Gumroad product page / checkout - recommended spec
1. Product description top block, plain text, 14-16 px or larger, high contrast:
   - "Price: $5 minimum (pay what you want). Tax shown at checkout." 
   - "Refunds: 30 days, email [address], no questions asked."
   - "Requires: macOS [version], camera/microphone/Accessibility permission as relevant. Not yet notarized: you must approve it in System Settings > Privacy & Security. [Steps]"
   - "Data: processed on your Mac; no telemetry; optional AI features send transcript text to the provider whose API key you enter."
   - "By purchasing you agree to the Terms of Sale and License: [link]. You'll confirm again when you activate."
2. If a required checkbox/custom field exists: label "I have read and agree to the Terms of Sale and License [link]" (link text exactly matching document title, opens in same page or new tab, blue underline).
3. Put the same terms link on the Gumroad receipt/email and on the download page (belt and braces).
4. Do not bury refund policy in the Terms alone; 3.13(4) wants it clear and conspicuous **before** consummation.

### 3.4 In-app license activation screen - recommended spec (clickwrap)
Apply Kauders/Good factors literally:
- **Dedicated screen** (no payment fields, no competing form clutter). Title: "License Agreement." Short plain-English summary box (5-7 bullets: license scope; refund; no warranty to the extent allowed; liability cap; disputes/MA law; data privacy in-app summary; your responsibilities with webcam/recordings of other people).
- **Visible full text** in a scrollable text view *or* a prominent standard hyperlink "Read the full Terms (Terms of Sale and License, v1.0)" opening the document in-app. Do not require two or more link hops; do not rely on a "Privacy" link to carry contract terms.
- **Agreement sentence directly above the button**, full-contrast, same or larger font than surrounding text: "By clicking 'I Agree and Activate,' you agree to the Terms of Sale and License [link]. If you do not agree, click 'Decline' for a refund." 
- **Affirmative control**: a checkbox ("I have read and agree...") that enables a button labeled **"I Agree and Activate"** (not "Continue," "Done," "OK," "Next"). Separate **"Decline"** button that explains refund/uninstall. Checkbox unchecked by default; button disabled until checked (Good upheld checkbox + Confirm).
- Make license-key entry *follow* assent on the same screen or the next one, so a key cannot be activated without clicking the agreement. Do not auto-activate on key paste.
- **Record assent** locally: terms version, timestamp, key hash (Gumroad key already sent to Gumroad; do not add a new server). Local log helps only if you can also show it (you receive no data, so evidence of assent will be the design screenshots + code version). Keep dated screenshots of each released version of the screen; plan to produce them in litigation.
- **Re-assent** on material term changes: version number in the Terms; show the screen again, with a summary of changes. Include a "we may change these terms; material changes require your re-acceptance in the app" clause rather than "continued use = acceptance."
- Accessibility: the screen must work with VoiceOver and keyboard only (these are accessibility-adjacent apps; ironically many users may use gaze/gesture control and need larger click targets; make the checkbox and button large).
- Language: provide the same Terms in the repo (`TERMS.md`) and on a static web page; the MIT LICENSE continues to govern source code only.
- Heightened items: because the dissent in Good warned about surprising terms hidden behind a link, **surface unusual terms in the in-screen summary** (liability cap, arbitration if any, class waiver if any, MA governing law, recording-of-others responsibilities).

### 3.5 Other document placement
- Keep Terms short and plain; Kauders emphasizes ordinary contract principles, and 93A "unfairness" can reach one-sided or confusing terms.
- Link Terms from the app's About menu and the first-run permissions flow.
- Separate consents (webcam, mic, system audio, voiceprints of third parties, AI provider transfer) belong in their own just-in-time prompts addressed in other research files (privacy/biometrics); do not rely on the EULA clickwrap for them.

---

## 4. Arbitration and class waivers

### 4.1 Law
- **FAA preempts state rules that bar class-arbitration waivers**: AT&T Mobility v. Concepcion, 563 U.S. 333 (2011) (https://supreme.justia.com/cases/federal/us/563/333/). MA's earlier rule (Feeney v. Dell, 454 Mass. 192 (2009) and Feeney v. Dell, 465 Mass. 470 (2013), that class waivers in consumer contracts violate MA public policy under 93A) was abrogated in the arbitration context; the SJC acknowledged this on rehearing. Sources: https://law.justia.com/cases/massachusetts/supreme-court/volumes/465/465mass470.html ; https://www.wagehourlitigation.com/2013/08/the-massachusetts-supreme-judicial-court-reluctantly-agrees-that-its-june-2013-decision-on-class-arbitration-waivers-is-no-longer-good-law/ . **[UNVERIFIED: later MA treatment; Feeney II cite for the "no longer good law" order not confirmed.]**
- A **class waiver standing alone** (in a non-arbitration clause) is not protected by the FAA and remains vulnerable in MA under Feeney I-type reasoning and 93A sec. 9(2). Attorney flag.
- Arbitration clauses must still pass Kauders/Good formation; Good (2024) shows a clickwrap does it. Delegation clauses will send unconscionability challenges to the arbitrator.
- Federal law has no consumer-arbitration ban. The CFPB's 2017 arbitration rule was repealed by Congress (2017). EFAA (2022) concerns sexual harassment only. **[UNVERIFIED: no 2025-26 consumer-arbitration statute found; not searched thoroughly.]**

### 4.2 Is it worth it at $5?
| Factor | Assessment |
|---|---|
| Class exposure | Real but modest: at $5 price, class damages are small; the worry is statutory $25 minimum x number of buyers, plus fee-shifting. A **class waiver + arbitration** (FAA-protected) is the only way to meaningfully avoid class exposure. |
| Cost of arbitration | Under AAA/JAMS consumer rules the business pays most fees (AAA consumer fee schedule: roughly $200+ business filing, $300+ case management, arbitrator compensation thousands). **[UNVERIFIED current figures.]** A single claim could cost you more than lifetime revenue. Mass-arbitration risk (coordinated filings by firms) is the main downside; MA 93A claims add fee-shifting. |
| Alternatives | Small claims in MA district/Boston Municipal court (low filing fees) fits $5 disputes; an **opt-out small-claims carve-out** is customary. |
| Drafting cost | Needs attorney drafting, designation of a provider, fee provisions, mass-arbitration protocol, opt-out mechanism. |
| Reputation | Open-source, indie, privacy-forward audience; arbitration clauses may cost trust. |

**Recommendation:** For launch, **skip mandatory arbitration and class waiver.** Use: MA governing law, venue in MA state/federal courts in the seller's county, a right to sue in small claims, a clear informal dispute-resolution step (email support first, 30 days), and the refund policy. Revisit arbitration only if (a) you form an entity, (b) revenue and class exposure justify it, or (c) counsel recommends. If you do add it: separate summary box in the clickwrap screen, 30-day opt-out, small-claims carve-out, business pays fees for claims under a threshold, and public injunctive relief carve-out. **Attorney review required.**

---

## 5. Limitation-of-liability caps under 93A

- **Consumer (sec. 9):** In H1 Lincoln, Inc. v. South Washington Street, LLC, SJC-13088 (Jan. 24, 2022), the SJC held a contractual limitation cannot preclude multiple damages for **willful or knowing** 93A sec. 11 violations (business context); it may be enforceable for "relatively innocent" violations. The court indicated a consumer's waiver of rights under sec. 9 would ordinarily not be effectuated. Summary source: https://www.potomaclaw.com/news-Massachusetts-SJC-Says-No-Contractual-Exclusion-of-Willful-or-Knowing-Chapter-93A-Liability (primary opinion not retrieved; find at https://www.mass.gov/ or Justia under H1 Lincoln). **[UNVERIFIED cite pages.]**
- Therefore: a cap of "amount you paid" is **likely enforceable** for ordinary contract/negligence/warranty claims **by a business or in a non-93A claim**, **not reliable** against a consumer's 93A claim, 940 CMR violations, or personal-injury claims.
- c.106 sec. 2-316A bars limits on remedies for implied warranty breach by consumers; sec. 2-719(3) says limiting consequential damages for **personal injury in the case of consumer goods** is prima facie unconscionable (UCC text; verify MA version). Your product's injury risk: RSI/eyestrain from gesture control and eye tracking, a mouse-control app clicking things unintended, dictation typing in sensitive contexts (data loss, financial transactions, deleted files). Real consequential-loss risk exists from ManOS: unintended clicks via CGEvent in banking apps etc. Consider a safety notice and a UI kill-switch (hotkey) as the primary mitigation.
- Draft: (a) cap at greater of amount paid or $5 (not "$0"; a $0 cap looks unconscionable); (b) exclude consequential damages "to the extent permitted by law"; (c) carve-outs: does not limit liability for death/personal injury caused by negligence, fraud, willful misconduct, or anything law doesn't allow to be limited; (d) conspicuous, in the in-screen summary.
- Business buyers (sec. 11): caps are likelier to hold for innocent breaches; add a short "business use" clause. Consider whether to allow business use at the $5 tier at all (SOHO users will).

---

## 6. Refund-law minimums

| Source | Rule | Notes |
|---|---|---|
| MA statute | **No general MA statute found giving a right to return or refund for online/digital purchases** (MA has limited cooling-off rights: door-to-door sales (c.93 sec. 48), health club, etc.). Source guide: https://www.mass.gov/info-details/massachusetts-law-about-shopping-and-returns | Door-to-door law not applicable. **[UNVERIFIED c.93 sec. 48 coverage for online]** |
| 940 CMR 3.13(4) | Must disclose refund/return/cancellation policy clearly and conspicuously before sale, not misrepresent it, and honor it. | https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-13 |
| Implied warranty / 93A | If the software is defective in a way that breaches merchantability or fitness, the buyer may reject/revoke acceptance or claim damages (UCC secs. 2-601, 2-608, 2-711) if Article 2 applies; refund is the natural remedy. | |
| Gumroad | Creator sets policy, but Gumroad enforces a minimum 30-day policy at high dispute rates; fees not returned on refunds. Chargebacks cost extra fees and risk account. | **[UNVERIFIED]** https://gumroad.gumroad.com/p/gumroad-is-becoming-a-merchant-of-record-more-updates |
| Federal | No federal refund right for digital goods; FTC Act sec. 5 bars deceptive refund claims; **FTC click-to-cancel (negative option) rule was vacated by the 8th Circuit in July 2025** (not applicable anyway absent subscriptions). **[UNVERIFIED current status 2026]** | |
| International (later) | EU/UK 14-day withdrawal for digital content (waivable only with express consent and acknowledgement of loss of the right) etc. Out of scope; flag for the international rollout. | |

Recommended refund text (pre-purchase, in-app, and Terms): "30-day refund, no questions asked. Email [address] with your purchase email. We refund through Gumroad within 5 business days. After a refund, your license key is deactivated." Treat the refund promise as binding. Because LicenseKit validates with Gumroad, a refunded key will stop validating; say so.
Because the sale is pay-what-you-want with a $5 minimum, state that the refund covers the amount paid.

---

## 7. Concrete Terms of Sale and License outline (for attorney drafting)

1. Parties: seller named individually (until LLC); contact email; effective date and version.
2. Plain-English summary box (see 3.4).
3. License scope: personal use, devices, no resale of keys; source code under MIT separate; third-party components (Hugging Face models CC-BY-4.0; see THIRD_PARTY_NOTICES.md).
4. Price, tax (Gumroad as merchant of record), pay-what-you-want, refund (6).
5. Your responsibilities: recording laws (two-party consent states; MA c.272 sec. 99 "all-party" - covered in other research), consent of people recorded, voice profiles of named people, not for emergency/medical/safety-critical use; ManOS: user is responsible for what gets clicked.
6. Third-party services (AIKit): your API key, their terms, text leaves your Mac.
7. Disclaimer (2.4) and limitation (5).
8. Termination/revocation: license revoked for breach; refunded keys deactivated.
9. Governing law: Massachusetts; venue; small-claims right; informal dispute step. No arbitration at launch (4).
10. Changes to terms: re-accept in-app for material changes; no unilateral "continued use" trick.
11. Notices: email; 93A demand address.
12. Severability; entire agreement; **no waiver of consumer rights that cannot be waived** statement.

---

## 8. Attorney-review flags
1. Whether the app/key is "consumer goods" under c.106 sec. 2-316A and whether Article 2 applies (no controlling MA SJC case located).
2. Drafting of disclaimer/cap so it is not itself a 93A deceptive "illusory rights" clause.
3. Class waiver outside arbitration (Feeney) and whether to use arbitration at all.
4. 940 CMR 38.00 full text if you add trial/subscription; pricing display on Gumroad.
5. Whether Gumroad lets the seller present a required terms checkbox, and whether Gumroad's own checkout terms conflict with yours.
6. Personal liability/LLC formation timing; insurance (cyber/tech E&O) cost-benefit.
7. ManOS personal-injury/consequential-loss exposure; biometrics and recording laws (see other research files).
8. Handling of 93A demand letters and tender strategy.
9. International: EU consumer law, GDPR interplay.

---

## 9. Sources verified (2026-10-01)

Fetched/seen in this pass (content confirmed to the extent noted; official-site pages marked 403/404 were not read directly):
- G.L. c.93A sec. 9 (summary of text confirmed via official page): https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section9
- G.L. c.106 sec. 2-316A subsection (1)-(2) text confirmed: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter106/Article2/Section2-316A
- 940 CMR 3.13 (read): https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-13
- 940 CMR 3.16 (search summary): https://www.law.cornell.edu/regulations/massachusetts/940-CMR-3-16
- 940 CMR 3.00 full text (not read; 403 on some mirrors): https://www.mass.gov/doc/940-cmr-3-consumer-protection-general-regulations/download
- 940 CMR 38.00 (search summaries only): https://www.mass.gov/regulations/940-CMR-3800-unfair-and-deceptive-fees ; https://www.law.cornell.edu/regulations/massachusetts/940-CMR-38-03
- Kauders v. Uber (read summary of opinion): https://caselaw.findlaw.com/court/ma-supreme-judicial-court/2105839.html ; Boston Bar summary https://bostonbar.org/journal/enforceability-of-online-contracts-under-massachusetts-law-kauders-v-uber-technologies-inc/
- Good v. Uber, 494 Mass. 116 (2024) (summary via FindLaw; Justia 403): https://caselaw.findlaw.com/court/ma-supreme-judicial-court/116245938.html
- Feeney v. Dell (search results): https://law.justia.com/cases/massachusetts/supreme-court/volumes/465/465mass470.html
- H1 Lincoln (secondary summary): https://www.potomaclaw.com/news-Massachusetts-SJC-Says-No-Contractual-Exclusion-of-Willful-or-Knowing-Chapter-93A-Liability
- Magnuson-Moss definition (search summary): https://www.ecfr.gov/current/title-16/chapter-I/subchapter-G/part-700
- Advent Systems v. Unisys (search): https://openjurist.org/925/f2d/670/advent-systems-limited-90-1069-v-unisys-corporation-90-1070
- Gumroad merchant of record: https://gumroad.gumroad.com/p/gumroad-is-becoming-a-merchant-of-record-more-updates (refund-policy specifics from secondary sources, unverified)

Not verified / gaps: 2025-2026 MA appellate decisions on clickwrap or software-as-goods; Gumroad's checkout terms and refund policy on its own pages; FTC click-to-cancel status in 2026; current AAA consumer fee schedule; MA c.93 sec. 48 and sec. 2-318/2-719 text.
