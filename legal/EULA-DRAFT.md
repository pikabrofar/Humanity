# DRAFT — requires attorney review; not legal advice

# Humanity Terms of Sale and End User License Agreement (DRAFT v0.1, 2026-10-01)

> **How to read this draft.**
> - Text outside brackets is proposed customer-facing language.
> - `[Reviewer note: …]` flags enforceability or jurisdiction questions for counsel. Delete these notes before publishing.
> - `[PLACEHOLDER]` marks a value to fill in. Do not insert real names or emails into this repo copy.
>
> **Presentation.** Gumroad is merchant of record and "will present" the seller's end-user terms "in a manner that creates a binding contract between you and each such Buyer" ([Gumroad Terms §6.7](https://gumroad.com/terms)). Also show these terms, with an "I agree" control, in the in-app activation window (`LicenseKit/ActivationWindow.swift`) before the key is accepted.
>
> [Reviewer note: Massachusetts enforces online terms only when there is reasonable notice of the terms and a reasonable manifestation of assent ([*Kauders v. Uber Techs.*, 486 Mass. 557 (2021)](https://law.justia.com/cases/massachusetts/supreme-court/2021/sjc-12933.html)). A clickwrap checkbox at activation, plus a conspicuous link on the Gumroad product page, is the safest pattern. Browsewrap ("by using you agree") alone likely fails.]

---

## 1. Who and what

- These terms are between you and **[SELLER LEGAL NAME / DBA]**, an individual developer in Massachusetts, USA ("we"). They cover:
  - your purchase of a Humanity license key ("Key") through Gumroad;
  - your use of the official, pre-built Humanity, OculOS, ManOS and Murmur apps that we distribute ("Official Apps"); and
  - any support we provide.
- **Gumroad, Inc.** is the reseller and merchant of record for the payment. Gumroad's own terms govern the payment itself.

[Reviewer note:
- Confirm the seller identity a consumer will see. Some states require a seller's name and address in consumer contracts.
- If the developer forms an LLC, substitute it to limit personal exposure. A sole proprietor is personally liable without limit, and a liability cap (§12) is no substitute for an entity plus insurance.]

## 2. What the Key is, and how it relates to the open-source code

1. **Open source first.** Humanity's source code is published under the MIT License. **Nothing in these terms limits any right you have under the MIT License or under any third-party license listed in `THIRD_PARTY_NOTICES.md`.** You may build Humanity from source, without a Key, at no charge.
2. **What you pay for.** Your payment ($5 minimum, pay what you want) buys:
   - a Key that unlocks the Official Apps on your Macs;
   - the convenience of our builds;
   - updates we choose to release; and
   - best-effort support.
   It also funds development. It is not a fee for the source code.
3. **License to the Official Apps.** Subject to these terms, we grant you a non-exclusive, worldwide, non-transferable [Reviewer note: see §2.5] license to activate and use the Official Apps with your Key on Macs that you own or control, for personal or business use. Each Key is for **[one person / up to N Macs]**.
4. **Key rules.** Keep your Key private. Do not publish, sell or share it, or use it to unlock copies for other people. We may deactivate Keys that are publicly posted or used in ways that clearly exceed §2.3.
5. **What is not restricted.** We do not restrict copying or redistributing the free DMG or the MIT source. Those are governed by the MIT License. You may not use our names or logos for builds you distribute (§15).

[Reviewer note:
- §2.1 is the coherence clause. It must appear early and plainly. Without it, the EULA could be read to restrict rights MIT already grants. That would be confusing and possibly deceptive (FTC Act §5, [15 U.S.C. §45](https://www.law.cornell.edu/uscode/text/15/45); [M.G.L. c. 93A §2](https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section2)).
- Restrictions on the third-party CC BY 4.0 models are prohibited by [CC BY 4.0 §2(a)(5)(B)](https://creativecommons.org/licenses/by/4.0/legalcode.en).
- §2.3 "non-transferable": EU or UK consumers may have resale rights for downloaded software licenses (*UsedSoft v. Oracle*, CJEU C-128/11). It is low stakes at $5, but consider allowing transfer on request.
- Decide the device or person limit and match it to the `increment_uses_count` handling in `License.swift`, which currently counts activations but never enforces a cap.]

## 3. Open-source and third-party components

- The Official Apps include components from third parties under their own licenses, including:
  - FluidAudio (Apache-2.0);
  - fastcluster (BSD-2-Clause);
  - NVIDIA NeMo text-processing grammars (Apache-2.0); and
  - various Rust libraries (MIT/Apache-2.0).
- The apps also download speaker-diarization models from Hugging Face, licensed CC BY 4.0 by Fluid Inference, pyannote and BUT Speech@FIT.
- These licenses are listed in the app's About window and in `THIRD_PARTY_NOTICES.md`. **Where these terms conflict with an open-source license, the open-source license controls for that component.**
- Third-party licensors give you no warranty and have no obligations to you under these terms.

[Reviewer note:
- Apache-2.0 §9 lets us offer warranty or support only "on Your own behalf" and requires us to indemnify contributors for any warranty we offer. The disclaimers in §11 keep that exposure minimal.
- The optional OculOS gaze-model script is not part of the Official Apps. Gaze360-trained weights are non-commercial only; see §5.6.]

## 4. Privacy summary

- Camera and audio are processed on your Mac.
- The Official Apps contact the internet only to:
  - verify your Key with Gumroad (`api.gumroad.com`) at activation and about weekly;
  - download diarization models from Hugging Face the first time you process a meeting; and
  - send **text** (transcripts, never audio) to an AI provider **you** configure with your own API key.
- Details: `PRIVACY.md` [link].
- We do not receive your recordings, transcripts, voice profiles or gaze data.

[Reviewer note:
- Keep §4 literally true. The FTC treats broken privacy promises as deception; see its [AI privacy commitments guidance (Jan 2024)](https://www.ftc.gov/policy/advocacy-research/tech-at-ftc/2024/01/ai-companies-uphold-your-privacy-confidentiality-commitments) and its [Biometric Policy Statement (May 2023)](https://www.ftc.gov/legal-library/browse/policy-statement-federal-trade-commission-biometric-information-section-5-federal-trade-commission-act).
- The current `NSSpeechRecognitionUsageDescription` says "Nothing is sent to Apple or anyone else". That is inaccurate once cloud AI is enabled; reword it. The MA AG's [AI advisory (Apr 2024)](https://www.mass.gov/doc/ago-ai-advisory-41624/download) applies 93A to AI misrepresentations.
- Gumroad holds buyer data as merchant of record. Through the Gumroad dashboard we receive buyer emails, so [201 CMR 17.00](https://www.mass.gov/regulations/201-CMR-1700-standards-for-the-protection-of-personal-information-of-ma-residents) (a written information security program) may apply to the developer.]

## 5. Acceptable use: recording, voiceprints, surveillance

You are responsible for how you use the Official Apps. In particular:

1. **Get consent before recording.** Recording calls or conversations is illegal in many places without the consent of **everyone** taking part. This includes Massachusetts ([M.G.L. c. 272 §99](https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter272/Section99)), California ([Penal Code §632](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?sectionNum=632.&lawCode=PEN)) and about a dozen other U.S. states, plus many countries. Before you start a Meetings recording:
   - tell everyone you are recording; and
   - get their consent wherever the law requires it, including for participants located in other states or countries.
   Other participants' meeting apps will **not** show that you are recording.
2. **Voice profiles of other people.** A voice profile is a voiceprint, which is biometric data under laws such as Illinois BIPA ([740 ILCS 14](https://www.ilga.gov/Legislation/ILCS/Articles?ActID=3004&ChapterID=57)), Texas ([Bus. & Com. Code §503.001](https://statutes.capitol.texas.gov/Docs/BC/htm/BC.503.htm)), Washington ([RCW 19.375](https://app.leg.wa.gov/RCW/default.aspx?cite=19.375)) and the EU GDPR (Art. 9). Only save a voice profile of someone who has agreed to it. Where the law requires it, that agreement must be in writing. Delete profiles when you no longer need them.
3. **No surveillance.** Do not use the Official Apps to:
   - record, track or identify anyone covertly;
   - monitor employees, partners, family members or others without the notice and consent the law requires; or
   - capture another person's gaze, face or hand data without their knowledge.
4. **Sending transcripts to AI providers.** If you send transcripts to a cloud AI provider, you are sharing what other people said with that provider. Make sure you have the right to do so.
5. **No unlawful, harmful or high-risk use.** The Official Apps are not medical devices or certified assistive technology. Do not use them where an error could cause injury, financial loss or legal consequences without independent safeguards.
6. **Optional gaze model.** The OculOS `make cnn-model` script downloads third-party weights trained on the Gaze360 dataset. Those weights are licensed for **non-commercial research only**. Do not load them into the Official Apps for commercial use, and do not redistribute them.

[Reviewer note:
- The developer's own exposure: MA §99 reaches anyone who "aid[s] another to secretly … record" (§99 B.4, C.6). [18 U.S.C. §2512](https://www.law.cornell.edu/uscode/text/18/2512) bars selling devices "primarily useful" for surreptitious interception. The FTC has acted against covert-surveillance software (e.g. its [SpyFone order, 2021](https://www.ftc.gov/news-events/news/press-releases/2021/09/ftc-bans-spyfone-ceo-surveillance-business-orders-company-delete-all-secretly-stolen-data)).
- These clauses help only together with product design: a visible recording banner and no stealth mode. See `RECORDING-CONSENT-UX.md`. The clauses alone are not a shield.
- BIPA defines "private entity" to include any **individual**, so an Illinois user may be directly liable. Our app collects nothing centrally, which helps the developer.
- EU AI Act: matching meeting voices against stored profiles may meet the definition of "remote biometric identification" (Art. 3(41); Annex III 1(a) high-risk). Counsel should assess this before EU sales, or offer voice profiles only where it is clearly out of scope.]

## 6. Automation and accidental actions

- OculOS, ManOS and Murmur control your mouse and keyboard and can paste text into other apps.
- Gaze, gesture and speech recognition are imperfect. They can **click, drag, scroll, type or paste in the wrong place**. That can send messages, delete files, submit forms or trigger purchases you did not intend.
- Dictated text may be wrong, and clipboard contents may be replaced or restored.
- Keep backups.
- Use the pause controls and hotkeys.
- Do not leave pointer control active while you are away.
- Review AI-generated summaries and cleaned-up text before relying on them.

[Reviewer note:
- A conspicuous, specific risk disclosure strengthens the §11 and §12 defenses and the assumption-of-risk argument.
- In MA consumer contexts it does not defeat 93A or an implied-warranty claim (§11). The product should also have safe defaults: a confirmation for destructive gestures and an emergency stop hotkey.]

## 7. Third-party services

- **Gumroad.**
  - Gumroad processes your payment, issues your Key, and verifies it for us. Gumroad's [terms](https://gumroad.com/terms) and privacy policy apply to those steps.
  - If Gumroad is unavailable, activation and weekly re-checks may fail. The Official Apps keep working offline for **60 days** after the last successful check.
- **AI providers** (e.g. Groq, Google, OpenAI, Anthropic, OpenRouter, Mistral, DeepSeek, Together, xAI, Ollama).
  - Optional and off by default.
  - You use your own account and API key. You pay any provider charges, and the provider's terms and data practices apply.
  - We are not responsible for provider outputs, outages, pricing or data handling.
- **Hugging Face** hosts the diarization models.
- **Apple** provides the on-device speech, Vision and Apple Intelligence frameworks; Apple's terms apply.

[Reviewer note:
- Our commitment to Key holders: if Gumroad's license API goes away, or we stop selling Keys, we will publish an update that does not require a Key (`License.required = false`). Put that promise in §10. Without it, a Key that stops working through no fault of the buyer is a 93A unfairness risk, and possibly a "defective/unusable" claim under the MA AG AI advisory.]

## 8. Price and payment

- Pay what you want, with a $5 minimum, in the currency Gumroad shows.
- Gumroad collects and remits applicable sales tax and VAT as merchant of record.
- A Key is a one-time purchase. There is no subscription.

## 9. Refunds

1. You may request a refund within **[14 / 30] days** of purchase through Gumroad or by emailing **[CONTACT EMAIL]**. We grant first-time refund requests within that window without questions.
2. Gumroad has final say over refunds, chargebacks and disputes ([Gumroad Terms §7.1](https://gumroad.com/terms)). Gumroad does not return its fees on refunds; we absorb them.
3. **A refunded, charged-back or disputed Key stops working.** The Official Apps detect this at the next weekly check. You may still build Humanity from source.
4. **EU/EEA/UK consumers.** By activating your Key you ask us to supply digital content immediately, and you acknowledge that you lose your 14-day right of withdrawal once activation succeeds. This does not affect our voluntary refund window in §9.1 or your statutory rights if the Official Apps are faulty.

[Reviewer note:
- Gumroad's refund setting is store-wide: none, 7, 14, 30 or 183 days. Per-product policies ended March 31, 2025. §9.1 must match the dashboard exactly.
- Consumer Rights Directive [2011/83/EU Art. 16(m)](https://eur-lex.europa.eu/eli/dir/2011/83/oj) takes away the withdrawal right only with the consumer's **express prior consent and acknowledgement** and a confirmation on a durable medium (Art. 8(7)). A checkbox at activation, plus the Gumroad receipt, is the minimum. Because Gumroad is merchant of record, counsel should confirm whether Gumroad or we bear these duties.
- The digital-content conformity rules ([Directive 2019/770](https://eur-lex.europa.eu/eli/dir/2019/770/oj), Art. 22) and the UK [Consumer Rights Act 2015](https://www.legislation.gov.uk/ukpga/2015/15/part/1/chapter/3) ss. 34–47 cannot be waived.]

## 10. Updates, support and end of sale

- Updates are released at our discretion. They are free to Key holders for **[the life of the 1.x line / N years / as long as we sell Keys]**.
- There is no auto-updater. You choose when to install.
- Support is best-effort by email at **[CONTACT EMAIL]**.
- Features may change or be removed, including features that depend on third-party services.
- **If we stop selling Keys, or Gumroad's license verification stops working, we will release a version of the Official Apps that does not require a Key.**

[Reviewer note:
- Under EU 2019/770 Art. 8(2), consumers are owed security and conformity updates for a reasonable period. That duty cannot be fully disclaimed for EU sales.
- The EU Cyber Resilience Act ([Reg. 2024/2847](https://eur-lex.europa.eu/eli/reg/2024/2847/oj)) has applied vulnerability-reporting duties (Art. 14) to products sold in the EU since **11 Sept 2026**. Full obligations start 11 Dec 2027. A paid binary is a commercial "product with digital elements". Counsel should advise whether the seller is the "manufacturer" despite Gumroad acting as merchant of record.]

## 11. Warranty disclaimer

- **To the fullest extent permitted by law, the Official Apps and Keys are provided "as is" and "as available", without warranties of any kind.** This includes implied warranties of merchantability, fitness for a particular purpose, title, non-infringement, accuracy of transcription, gaze, gesture or speaker identification, and uninterrupted or error-free operation.
- **This section does not limit any warranty or remedy that cannot be excluded under the law that applies to you. That includes, for Massachusetts consumers, M.G.L. c. 106 §2-316A. In jurisdictions that do not allow exclusion of implied warranties, those warranties are limited to the shortest period the law allows and to the remedy in §12.**

[Reviewer note: this is the weakest clause for a Massachusetts seller.
- [M.G.L. c. 106 §2-316A](https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter106/Article2/Section2-316A) makes any attempt by a seller or manufacturer of consumer goods "to exclude or modify any implied warranties of merchantability and fitness … or to exclude or modify the consumer's remedies" unenforceable, and the section "may not be disclaimed or waived by agreement".
- Whether downloadable software is "goods" under Article 2 is unsettled. Assume it may be.
- [940 CMR 3.08](https://www.mass.gov/regulations/940-CMR-300-general-regulations) makes misrepresenting warranty rights a 93A violation. Do not tell MA consumers they have *no* warranty. The savings sentence above is deliberate.
- Other states that restrict consumer implied-warranty disclaimers:
  - Maine, [11 M.R.S. §2-316(5)](https://legislature.maine.gov/statutes/11/title11sec2-316.html)
  - Maryland, [Com. Law §2-316.1](https://mgaleg.maryland.gov/mgawebsite/Laws/StatuteText?article=gcl&section=2-316.1)
  - Vermont, [9A V.S.A. §2-316(5)](https://legislature.vermont.gov/statutes/section/09A/002/02-316)
  - Kansas, K.S.A. 50-639
  - Mississippi, Miss. Code §11-7-18
  - West Virginia, W. Va. Code §46A-6-107
  - D.C. Code §28:2-316.1
- New Jersey's [TCCWNA](https://law.justia.com/codes/new-jersey/title-56/section-56-12-16/) (N.J.S.A. 56:12-16) penalizes vague "may not apply in some jurisdictions" savings language unless the contract says whether the provision applies in NJ. Consider a short state-specific annex.
- Magnuson-Moss ([15 U.S.C. §2308](https://www.law.cornell.edu/uscode/text/15/2308)) bars implied-warranty disclaimers only if we give a written warranty or service contract. We give none, so do not call support a "warranty".
- The MIT license disclaimer covers the free source. For the paid Key, Gumroad (reseller) is arguably the "seller" and we are the "manufacturer"; 2-316A covers both.]

## 12. Limitation of liability

- **To the fullest extent permitted by law, we are not liable for indirect, incidental, special, consequential or punitive damages, or for lost data, profits or business.** This includes damages from:
  - unintended clicks, keystrokes or pastes;
  - recordings you make or fail to make;
  - transcription or summary errors; and
  - third-party services.
- **Our total liability for all claims relating to the Official Apps or your Key is limited to the greater of the amount you paid for your Key or US$[50].**
- **These limits do not apply to liability that cannot be limited by law, including liability for:**
  - death or personal injury caused by negligence;
  - fraud;
  - gross negligence or willful misconduct; and
  - claims under consumer-protection statutes that cannot be waived, including M.G.L. c. 93A.

[Reviewer note:
- 93A §9 gives consumers actual damages or $25, whichever is greater, doubled or trebled for willful or knowing violations, plus attorney's fees. It requires a 30-day demand letter ([c. 93A §9](https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section9)). Assume a contract cap will **not** limit 93A recovery for unfair or deceptive conduct.
- A cap also cannot limit remedies for implied-warranty breach that §2-316A protects, nor personal-injury remedies (2-316A(4)).
- EU/UK: exclusions of liability for death or injury from negligence are void (UK CRA s.65; EU Unfair Terms Directive [93/13/EEC](https://eur-lex.europa.eu/eli/dir/1993/13/oj) Annex 1(a)). The new EU Product Liability Directive [2024/2853](https://eur-lex.europa.eu/eli/dir/2024/2853/oj) covers **software** placed on the market after **9 Dec 2026**, imposes strict liability including for data loss, and forbids contractual exclusion (Art. 15).
- The cap at "greater of amount paid or $50" is meant to look reasonable rather than illusory.]

## 13. Your responsibility for misuse (business users)

- If you use the Official Apps on behalf of a business or organization, you will indemnify us against third-party claims arising from:
  - your recordings, voice profiles or other monitoring of people; or
  - your breach of §5.

[Reviewer note:
- Consumer indemnities are often unenforceable or unfair terms (93A; EU 93/13). It is limited to business users for that reason.
- Recovery against an individual user is impractical in any case. The value of this clause is mostly allocating responsibility on paper.]

## 14. Termination

- These terms last until ended.
- We may deactivate a Key that was obtained fraudulently, refunded, charged back, or publicly shared, or that is used in material breach of §5. Where practical we will give notice and a chance to cure.
- You may stop using the Official Apps at any time.
- Termination does not affect your rights under the MIT License or other open-source licenses.
- §§3, 5, 11–13, 17–19 survive.

[Reviewer note:
- Deactivating for breach of §5 without a refund could be challenged as a penalty. Reserve it for clear, documented cases.
- We cannot monitor use, by design, so enforcement is effectively limited to shared or published Keys.]

## 15. Intellectual property and trademarks

- We and our contributors keep all rights not expressly granted.
- The source code is licensed under MIT. **The names "Humanity", "OculOS", "ManOS" and "Murmur" and their icons are not licensed by MIT.**
- If you build or distribute your own copy, give it a different name and icon, and do not imply that it is official or endorsed by us. See `TRADEMARKS.md`.

[Reviewer note:
- Trademark rights here are common-law only unless registered. "Humanity" is a common word, so the mark is weak.
- See the audit's finding 1: the current Humanity, ManOS and Murmur icons use Apple SF Symbols, which Apple forbids in app icons. Replace them before asserting any rights in the icons.]

## 16. Export and legal compliance

- You will not use or export the Official Apps in violation of U.S. export-control or sanctions laws.

[Reviewer note:
- Standard clause.
- Gumroad's sanctions screening sits upstream. The app uses only standard OS-provided encryption (HTTPS), which is likely EAR99 or mass-market; confirm this.]

## 17. Governing law

- These terms are governed by the laws of the **Commonwealth of Massachusetts, USA**, excluding its conflict-of-laws rules and the U.N. Convention on Contracts for the International Sale of Goods.
- **If you are a consumer, you keep the protection of mandatory laws of the place where you live.**

[Reviewer note:
- Under [Rome I Art. 6(2)](https://eur-lex.europa.eu/eli/reg/2008/593/oj), a choice of law cannot strip EU consumers of protections in their home law, so the savings sentence is required.
- U.S. consumers in other states may also invoke their home statutes; California, for example, applies its own law to recordings of CA residents (*Kearney v. Salomon Smith Barney*, 39 Cal. 4th 95 (2006)).
- Gumroad's own terms choose California law for the platform relationship. That does not conflict, because those terms govern a different contract.]

## 18. Disputes

1. **Talk to us first.** Email **[CONTACT EMAIL]** with a description of the problem. We will try to resolve it within 30 days. Most issues can be fixed with a refund or a new Key.
2. **Courts.** Unresolved disputes may be brought in the state or federal courts located in **[Suffolk / Middlesex] County, Massachusetts**. Consumers may instead sue in the courts where they live, where the law allows. **Either party may use small-claims court.**
3. **No mandatory arbitration.** [Option B in the reviewer note.]

[Reviewer note: **recommend no arbitration clause.**
- Arbitration clauses are generally enforceable under the FAA (*AT&T Mobility v. Concepcion*, 563 U.S. 333 (2011)).
- But for a $5 product they create net risk:
  - consumer arbitration rules shift most fees to the business (AAA Consumer Rules fee schedule; JAMS minimum standards);
  - mass-arbitration filings can cost far more than the claims are worth; and
  - MA requires clear notice and assent for such terms (*Kauders*).
- The EU forbids pre-dispute consumer arbitration that deprives consumers of court access (93/13/EEC Annex 1(q)).
- A class-action waiver without arbitration is of doubtful enforceability against MA consumers bringing 93A claims.
- **Option B (if counsel insists):**
  - individual arbitration under AAA Consumer Rules, seller pays all fees;
  - small-claims and IP carve-outs;
  - a 30-day opt-out;
  - a mass-filing batching protocol; and
  - a stated exclusion for EU/UK consumers.]

## 19. General

- **Changes to these terms.** We may update these terms for future purchases and future versions. We will post the date and a summary of changes. Changes do not apply retroactively to a Key you already bought unless you accept them, for example by installing a new version that shows the new terms.
- **Entire agreement.** These terms are the entire agreement on the subjects they cover. They sit alongside the open-source licenses and Gumroad's terms.
- **Severability.** If a provision is unenforceable, it will be limited to the minimum extent necessary, and the rest remains in effect.
- **Assignment.** You may not assign these terms except as §2 allows. We may assign them to a successor that maintains the Official Apps.
- **No waiver.** Failure to enforce a provision is not a waiver.
- **Notices.** We send notices to the email on your Gumroad purchase. You send notices to **[CONTACT EMAIL]**.

[Reviewer note:
- Unilateral-modification clauses are disfavored for consumers. Keep changes prospective and versioned in git. `CHANGELOG` plus a tagged `legal/EULA.md` gives an audit trail.]

## 20. Contact

**[SELLER LEGAL NAME / DBA]**, Massachusetts, USA, **[CONTACT EMAIL]**. Postal address for legal notices: **[ADDRESS OR REGISTERED-AGENT ADDRESS]**.

[Reviewer note:
- The EU Consumer Rights Directive (Art. 6(1)(c)) requires the trader's geographic address and contact details before the contract is formed. Gumroad, as merchant of record, may satisfy part of this.
- A PO box or registered agent protects the developer's home address.]

---

### Open questions for counsel (summary)
1. Is downloadable software "goods" under M.G.L. c. 106 for §2-316A? What warranty language is safe for MA consumers?
2. With Gumroad as merchant of record, who carries the EU consumer, CRA and PLD duties: Gumroad or the developer?
3. EU AI Act status of voice-profile speaker identification. Should voice profiles be disabled for EU buyers?
4. Should the seller form an LLC and buy E&O/cyber insurance before scaling sales?
5. Is a state-specific annex (NJ, MA, CA) worth it at this price point?
