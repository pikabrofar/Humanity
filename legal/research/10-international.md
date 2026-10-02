# 10 - International sales: what applies (research memo, not legal advice)

Prepared 2026-10-01 by a research analyst, not a lawyer. Nothing here says the product "is compliant" or "is safe".
Product facts come from /private/tmp/.../brief.txt and /Users/taylorpan/Cloud/Humanity/PRIVACY.md: individual developer in Massachusetts, no entity, Gumroad license keys, pay-what-you-want ($5 min), no developer servers, all processing on-device, voiceprints stored locally, only Gumroad sale records reach the developer.

**Verification legend.** [V] = confirmed this session through a search result that quoted or described the point (mostly secondary sources, as noted). [U] = cited from analyst knowledge. The primary-source URL is given but the text was NOT retrieved this session. EUR-Lex and Gumroad help-center fetches returned empty, so every EUR-Lex article citation below is [U] unless it carries a [V]. An attorney must check article numbers and text against the official sources before anything is relied on.

---

## 0. Bottom line

1. **Recommended: US-only at launch.** For a solo, unincorporated seller the heaviest items are the EU Cyber Resilience Act (CRA) and EU consumer law (personal exposure, no liability shield). The voice-profile feature also raises an unresolved AI Act / GDPR Art. 9 question. See section 8.
2. **Gumroad cannot be assumed to offer a hard country block for digital products.** No documentation of one was found [V: search returned only shipping-destination limits for physical products]. Plan on "soft" geo-limiting (terms, product copy, pricing, no EU targeting) plus asking Gumroad support. See section 9.
3. **The CRA is the item most likely to surprise.** It treats a paid, solo-developer app as a "product with digital elements" with a "manufacturer" (the developer). Vulnerability reporting duties have applied since 2026-09-11, and the full regime applies from 2027-12-11. MIT-licensing the source does not take a paid product out of scope.
4. **The developer's own GDPR footprint is small** (license/Gumroad buyer data only), but it exists once EU buyers purchase. Art. 3(2) can apply to it.
5. **Voice profiles are the single biggest product-design risk abroad.** Voiceprints of named non-users are plainly biometric data used for identification. The user is the likely controller (and only escapes via the household exemption for purely personal use). The AI Act classification question (Annex III point 1 "remote biometric identification") is open. See 1.4 and 2.3.

---

## 1. GDPR (Reg. 2016/679) and UK GDPR

Primary: https://eur-lex.europa.eu/eli/reg/2016/679/oj [U]. UK: https://www.legislation.gov.uk/eur/2016/679/contents (retained/assimilated text) [U] and Data Protection Act 2018 https://www.legislation.gov.uk/ukpga/2018/12/contents [U].

### 1.1 Territorial scope, Art. 3(2)
- Art. 3(2)(a) applies GDPR to a non-EU controller/processor that processes data of people in the EU where the processing relates to "offering of goods or services" to them (payment not required). Art. 3(2)(b) is monitoring behaviour in the EU. [U]
- Recital 23: mere accessibility of a website, email address, or use of a language generally used in the seller's country is not enough; look for "envisaging" offering to EU data subjects (EU languages, EU currency, mentioning EU customers). [U]
- EDPB Guidelines 3/2018 on territorial scope (targeting criteria; two-step test) https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_3_2018_territorial_scope_after_public_consultation_en_1.pdf [U: URL from memory].
- **Applicability to this product:** If the developer deliberately sells to EU/UK buyers (accepts orders, lists EU availability, accepts EU VAT-inclusive checkout), the "offering" limb is easy to meet. If the sales page is USD-only, English-only, says "US customers only," and has no EU marketing, the developer has a reasonable argument that it is not targeting the EU. That is evidence, not immunity. Gumroad itself charging EU VAT [V] cuts the other way, because the platform treats EU buyers as in-market.
- **What data is in scope for the developer:** buyer name/email/country/IP/license key visible in the Gumroad dashboard or via webhooks/exports. The on-device data (gaze, audio, voiceprints) is not received by the developer.
- Art. 3(2)(b) "monitoring" does not fit: the developer does not observe anyone's behaviour. (Analyst view.)

### 1.2 Developer as controller for license and Gumroad data only
- Controller test: who determines purposes and means (Art. 4(7)). EDPB Guidelines 07/2020 on controller/processor https://www.edpb.europa.eu/system/files/2023-10/EDPB_guidelines_202007_controllerprocessor_final_en.pdf [U]. CJEU case law on broad "determines" (Wirtschaftsakademie C-210/16, Jehovah's Witnesses C-25/17, Fashion ID C-40/17) [U]. Search for texts at https://curia.europa.eu.
- A software vendor that supplies a tool processed entirely on the user's device and never accesses the data is, on the better reading, not a controller or processor for that processing. Recital 78 only "encourages" producers to consider data-protection-by-design. [U] Analyst view; attorney to confirm. Risk: if telemetry, crash reporting, update checks or cloud features are added later, this changes. Current PRIVACY.md says none exist; AIKit sends text to third parties only on the user's own key (user chooses provider; user is the controller toward that provider).
- **Gumroad and the developer** are probably each controllers (or Gumroad is an independent controller as merchant of record) of buyer data. Gumroad's terms/privacy policy decide this. [U: not fetched] Developer's duties then: Art. 6 lawful basis (contract/legal obligation), Art. 13 notice (privacy notice URL on product page), Art. 30 records (the small-organisation exemption in Art. 30(5) is lost for non-occasional processing, so keep a simple record), Art. 32 security of the buyer export, Art. 15-22 rights handling, Art. 33 breach notice (72h).
- Transfers: EU buyer data reaching a US developer is a restricted transfer if developer is the recipient; the EU-US Data Privacy Framework requires self-certification, and the General Court dismissed the Latombe challenge in 2025 (appeal status not verified) [U]. Practical route: rely on Gumroad's transfer mechanism and keep exports minimal; or use SCCs (Commission Decision 2021/914) [U]. Attorney flag.

### 1.3 Household exemption (Art. 2(2)(c), recital 18)
- Excludes processing "by a natural person in the course of a purely personal or household activity" with no connection to professional/commercial activity. Narrowly construed: Lindqvist C-101/01, Ryneš C-212/13 (camera covering public space not exempt), Jehovah's Witnesses C-25/17 [U].
- EDPB Guidelines 3/2019 on video devices, Section 3.1: household exemption must be interpreted narrowly; a tourist filming holidays and sharing with family is exempt, but footage made accessible to an indefinite audience is not [V: search excerpt of the guidelines]. https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices.pdf
- **Applies to users, not the developer.** A user who dictates, eye-tracks, or records personal calls privately likely falls within it. A user who records client/employee meetings, uses voice profiles for work, or shares recordings, is probably a controller (employer/business). The developer's EU-facing docs should say so, so business users know they carry GDPR duties (notice, lawful basis, Art. 9 condition, DPIA). Recital 18 also says the exemption does not stop GDPR applying to those who provide the "means" for such processing, which is the clause a regulator would cite against the developer. Analyst view: that recital does not make the vendor a controller, but it is a point for counsel.

### 1.4 Art. 9 biometric data and on-device voiceprints
- Art. 4(14): biometric data = data from technical processing of physical/physiological/behavioural characteristics "which allow or confirm the unique identification". Art. 9(1) prohibits processing "biometric data for the purpose of uniquely identifying a natural person" absent an Art. 9(2) condition (typically explicit consent, 9(2)(a)). [U]
- EDPB Guidelines 3/2019: images/video are not biometric data unless technically processed to identify; special-category treatment attaches when processed "for the purpose of uniquely identifying" [V: excerpt]. The guidelines also treat voice as a biometric characteristic [U: paragraph numbers not verified]. See also EDPB Guidelines 05/2022 on facial recognition (law enforcement context, informative on the definition) [U].
- **Applicability:**
  - Voice profiles (speaker embeddings matched to named people to recognise them in later meetings) squarely fit "technical processing ... to allow unique identification". That includes the profiles of non-users (meeting participants), who have not consented. Art. 9 applies to whoever is the controller of that processing. If the user is a private individual acting purely personally, GDPR does not apply (1.3). If the user is a professional, they need an Art. 9(2) condition for each participant, practically explicit consent.
  - The developer does not receive voiceprints, so on its face the developer is not "processing" them and has no Art. 9 duty. That is the best argument, not a settled one: regulators may look to who determined means (the software design) and the "provider of means" language. Attorney flag.
  - OculOS eye patches (10x6 pixel crops) and gaze data: used for calibration/pointing, not identification, so not Art. 9 under the Guidelines 3/2019 logic, unless used to recognise a person. Keep it that way (do not add per-user identification from eye patches).
  - Diarization alone (separating "speaker A/B" without a stored identity) is less clearly identification. The saved named voice profile is the sensitive step.
- PRIVACY.md already states that gaze data and voiceprints "can count as biometric data under laws like the GDPR". Keep, but add an EU-specific paragraph (section 8).
- UK: UK GDPR Art. 9 identical in structure; ICO biometric recognition guidance (2025) [U: not verified] https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/biometric-data-guidance-biometric-recognition/

### 1.5 EU/UK representative, Art. 27
- Art. 27(1): a controller/processor subject to Art. 3(2) must designate an EU representative in writing, unless Art. 27(2): (a) processing is occasional, does not include large-scale special-category data, and is unlikely to result in a risk to rights and freedoms; or (b) public authority. [U] EDPB Guidelines 3/2018 section 5 discuss "occasional" and say it is judged by frequency. UK GDPR Art. 27 requires a UK representative with the equivalent test. [U]
- **Applicability:** if Art. 3(2) applies, ongoing sales mean the developer cannot lean on "occasional" with confidence, but the "unlikely to result in a risk" limb plus no large-scale special-category data is a plausible argument for a tiny buyer-data set. Not guaranteed. Fine for failing Art. 27: up to EUR 10M/2% (Art. 83(4)(a)) [U].
- Options: (i) US-only so Art. 27 never arises, (ii) buy a low-cost representative service before EU opening, (iii) document the Art. 27(2)(a) analysis in writing. Attorney flag.
- Triggers/thresholds: no sales-volume threshold in GDPR; fines are scaled to the infringement (Art. 83); a solo developer is still within scope.

### 1.6 UK specifics
- Data (Use and Access) Act 2025 amends UK GDPR and DPA 2018 (Royal Assent 2025; commencement being staged by regulations; exact dates not verified) https://www.legislation.gov.uk/ukpga/2025/18/contents [U].
- ICO registration and data protection fee: required for controllers unless exempt; a micro-controller fee is small; check https://ico.org.uk/for-organisations/data-protection-fee/ [U].

---

## 2. EU AI Act (Reg. 2024/1689)

Primary: https://eur-lex.europa.eu/eli/reg/2024/1689/oj [U]. Commission guidelines on prohibited practices (Feb 2025, C(2025) 884) https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-prohibited-artificial-intelligence-ai-practices-defined-ai-act [U].

### 2.1 Does it apply?
- Art. 2(1)(a): providers placing AI systems on the EU market, wherever established. Art. 3(1) "AI system" definition. Speech recognition and speaker-embedding models are probably AI systems; gaze/hand tracking models likely too. Humanity would be a provider of the system. Apple's on-device speech model is Apple's. (Analyst view.)
- Art. 2(10): obligations on deployers who are natural persons in a purely personal non-professional activity are carved out; provider duties remain. [U]

### 2.2 Prohibited practices (Art. 5; applies since 2025-02-02; penalties since 2025-08-02)
| Practice | Text | This product |
|---|---|---|
| Emotion recognition in workplace/education, Art. 5(1)(f) | inferring emotions of natural persons in workplace and education institutions (medical/safety exceptions) | No emotion inference exists in described modules. **Do not add** engagement/attention/fatigue/mood inference from face, gaze or voice. Art. 3(39) defines it broadly via biometric data. |
| Biometric categorisation of sensitive traits, Art. 5(1)(g) | categorise individuals by biometric data to infer race, political opinions, union membership, religion, sex life/orientation | Not done. Diarization separates speakers; it does not infer protected attributes. Keep it that way (no gender/age/ethnicity labels from voice). |
| Untargeted facial image scraping, Art. 5(1)(e) | building face databases by scraping | N/A. |
| Real-time remote biometric ID by police, Art. 5(1)(h) | law enforcement | N/A. |
- Penalties up to EUR 35M or 7% (Art. 99(3)) [U].

### 2.3 Is speaker identification "remote biometric identification" (RBI)?
- Art. 3(35) "biometric identification": automated recognition of physical, physiological, behavioural or psychological human features for establishing identity by comparing biometric data of an individual to stored biometric data. Art. 3(41) "remote biometric identification system": identifies natural persons "without their active involvement, typically at a distance" through comparison to a reference database. Art. 3(34) biometric data includes voice-derived data. Recitals 15-17 (RBI vs verification; "at a distance"). [U]
- Annex III point 1(a): RBI systems are **high-risk** (excluding verification systems whose sole purpose is to confirm that a specific person is who they claim). [U]
- **Analysis (analyst view, unresolved):** a Meetings voice-profile match compares a participant's voice to a stored database of named voiceprints, without that participant's active involvement (they are on a call). That fits the literal text of 3(35) and arguably 3(41). Counter-arguments: small private personal database; not deployed in public spaces; "typically at a distance" is not a required element; closed set. No Commission guidance specifically on audio speaker-recognition was found; the Art. 6(5) high-risk classification guidelines were due Feb 2026 and their status was not verified [U].
- If high-risk applied: provider duties (risk management, data governance, technical documentation, logging, conformity assessment, CE marking, registration, QMS). Application date for Annex III systems moved to 2027-12-02 by the Digital Omnibus on AI (2.5). That is heavy for a solo developer.
- **Mitigation options:** (a) disable/hide voice profiles for the EU build or EU buyers until counsel advises; (b) restrict profiles to "enroll yourself" verification (closer to the verification carve-out) rather than identifying others; (c) require recorded consent of each named person. Attorney flag: high priority.

### 2.4 Transparency, Art. 50
- Art. 50(1): systems intended to interact directly with natural persons (chatbots) must tell people they are interacting with AI. Not the case here. [U]
- Art. 50(2): providers of AI systems (including general-purpose) generating synthetic audio, image, video or **text** must mark outputs machine-readably as AI-generated; exception for assistive functions for standard editing or no substantial alteration. Dictation cleanup is plausibly "standard editing". AIKit meeting summaries generated by a third-party LLM on the user's key are a grey area: the LLM provider is the main obligor, but a wrapper that offers the generation feature could be a "provider". Analyst view; flag. [U]
- Art. 50(3): deployers of emotion-recognition/biometric-categorisation systems must inform exposed persons. Not applicable if (and only if) the product does neither. [U]
- Art. 50(4): deepfakes and AI text published to inform the public. Not applicable.
- Art. 4 AI literacy (in force 2025-02-02) applied to providers and deployers; the Omnibus was proposed to soften this; final text not verified. [U]
- Practical: label AI-generated summaries in the UI ("AI-generated") and in exported files. Costs little and aids Art. 50(2) arguments.

### 2.5 Dates as of 2026-10-01
| Date | What | Status |
|---|---|---|
| 2024-08-01 | Entry into force | [U] |
| 2025-02-02 | Chapter I-II (Art. 4 literacy; Art. 5 prohibitions) | [U] |
| 2025-08-02 | GPAI obligations, governance, penalties | [U] |
| 2026-08-02 | General application incl. Art. 50 transparency | Not postponed by the Omnibus [V: secondary sources: Jones Walker, aiactblog.nl, Usercentrics] |
| 2026-12-02 | Art. 50(2) marking grace period for systems already on the market before 2026-08-02 | [V: secondary] |
| 2027-12-02 | Annex III high-risk obligations (delayed) | [V: secondary] |
| 2028-08-02 | Annex I (product-embedded) high-risk (delayed) | [V: secondary] |
- Digital Omnibus on AI: agreed 2026-05-07, Parliament 2026-06-16, Council 2026-06-29, signed 2026-07-08, in force 2026-07-27, per secondary sources only [V: https://www.joneswalker.com/en/insights/blogs/ai-law-blog/yes-august-2-still-matters-the-eu-approved-a-high-risk-ai-delay-but-most-trans.html, https://usercentrics.com/knowledge-hub/eu-ai-act-high-risk-delay-article-50-transparency-consent/, https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/]. Verify in the Official Journal.

### 2.6 Open-source exemption
- Art. 2(12): the Regulation does not apply to AI systems released under free and open-source licences, **unless** placed on the market as high-risk, or falling under Art. 5 or Art. 50. Recital 103 says components are not "free and open-source" where offered for a price or monetised (e.g. paid technical support, or using personal data for non-security purposes). [U]
- **Applicability:** source is MIT, but the product is distributed with a paid license key and the app does not run without it. The exemption is doubtful (the Commission has not been found to have ruled on keyed, paid binaries of MIT code). Even if available, it never covers Art. 5, Art. 50, or high-risk. Do not rely on it. Attorney flag.

---

## 3. EU Cyber Resilience Act (Reg. 2024/2847)

Primary: https://eur-lex.europa.eu/eli/reg/2024/2847/oj [U]. Commission page: https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act [V: appears in search], reporting: https://digital-strategy.ec.europa.eu/en/policies/cra-reporting [V].

### 3.1 Scope for commercial software
- Art. 2: products with digital elements (hardware or software and their remote data processing solutions) made available on the EU market whose intended or reasonably foreseeable use involves a direct/indirect data connection. Humanity apps connect (Gumroad, Hugging Face, AI providers), so likely in scope. [U]
- Art. 3: "manufacturer" is a natural or legal person who develops/manufactures a product, or has it designed and marketed under their name or trademark, for payment or free. A solo individual can be a manufacturer. [U]
- Recital/Art. 3 on "commercial activity": FOSS is in scope only when supplied in the course of commercial activity. Charging a price, charging for support beyond costs, or accepting donations exceeding costs indicates commercial activity; merely non-monetised FOSS is not [V: secondary summaries from search; EC guidance draft]. **Pay-what-you-want at $5 minimum with a license key is a price.** MIT source on GitHub does not change that for the paid, keyed binary.
- Non-EU manufacturers placing products on the EU market are covered; Art. 13/18-20 require documentation, authorised representative option (Art. 18), and conformity.

### 3.2 Open-source steward rules
- Art. 3(14) steward = a **legal person** providing sustained systematic support for FOSS intended for commercial activities. Art. 24 light-touch duties (cybersecurity policy, vulnerability reporting cooperation); Art. 25 voluntary security attestation programmes. [U]
- **Applicability:** the developer is a natural person selling their own product, i.e. a manufacturer, not a steward. The steward regime does not help. Stewards' reporting duties begin 2027-12-11 [V: secondary]. If the developer later forms an entity that only hosts the MIT repo while another entity sells binaries, counsel should analyse the split. Attorney flag.

### 3.3 Classification and obligations
- Default category (self-assessment, conformity "module A") unless in Annex III (important Class I/II) or Annex IV (critical). Annex III Class I includes e.g. identity management software, browsers, password managers (Annex III list not re-verified) [U]. Humanity apps are not obviously in those lists. Confirm with counsel after any change in ManOS (Accessibility/CGEvent control may be argued as "privileged" input control; analyst speculation, flag).
- Obligations (Art. 13, Annex I, Annex VII): secure-by-design requirements (Annex I Part I), vulnerability handling (Annex I Part II: SBOM, coordinated vulnerability disclosure policy, security updates for the support period, free of charge, security patches separate from feature updates where technically feasible), technical documentation, EU declaration of conformity, CE marking (Art. 28-29), retention of documents for 10 years or the support period (Art. 13(13)), support period at least 5 years unless product lifetime is shorter (Art. 13(8)), due diligence on third-party components (Art. 13(5)): FluidAudio/pyannote/WeSpeaker, Hugging Face models. [U]
- Vulnerability/incident reporting (Art. 14): early warning within 24h, notification within 72h, final report within 14 days (vulnerability) or one month (incident) via ENISA's Single Reporting Platform [V: secondary summaries]. Applies to actively exploited vulnerabilities and severe incidents.
- Fines (Art. 64): up to EUR 15M or 2.5% of worldwide turnover for essential-requirement breaches; EUR 10M/2% other obligations; EUR 5M/1% misleading information [U]. Microenterprise relief exists for some duties (e.g. Art. 14? SME simplified documentation under Art. 33) [U: not verified].

### 3.4 Dates (2026-2027)
| Date | Event | Status |
|---|---|---|
| 2024-12-10 | Entry into force | [U] |
| 2026-06-11 | Conformity assessment body provisions apply | [U] |
| **2026-09-11** | Manufacturers' reporting obligations (Art. 14) apply; includes products already on the market | [V: https://digital-strategy.ec.europa.eu/en/policies/cra-reporting; Skadden/Kirkland Sept 2026 alerts in search results] |
| **2027-12-11** | Main obligations (essential requirements, conformity, CE marking); steward reporting | [V: secondary] |
- **Take-away:** since 2026-09-11, an EU-available paid product from this developer would already carry reporting duties for an actively exploited vulnerability. This is the strongest argument for US-only until a vulnerability-handling process exists. SECURITY.md exists in the repo; it needs to be CRA-grade (contact, CVD policy, support period).
- Adjacent: Apple Gatekeeper/notarization absence is a conformity/quality problem under DCD (section 4.2) and weakens any "secure by default" claim. Notarize first.

---

## 4. EU consumer law

### 4.1 Right of withdrawal, Directive 2011/83/EU (CRD)
Primary: https://eur-lex.europa.eu/eli/dir/2011/83/oj [U]; CRD as amended by Directive (EU) 2019/2161 https://eur-lex.europa.eu/eli/dir/2019/2161/oj [U].
- Art. 9: 14-day withdrawal for distance contracts; Art. 10: extends to 12 months if the right was not disclosed. Art. 6(1)(h): must give pre-contract information on the right. [U]
- Art. 16(m) exception: digital content not on a tangible medium, if performance has begun with the consumer's **prior express consent** to begin during the withdrawal period, **acknowledgement** that this loses the right of withdrawal, and (where the contract requires payment) the trader has provided the Art. 8(7) confirmation on a durable medium. [U: text reconstructed from memory of the post-2014 text; confirm verbatim]. Art. 14(4)(b): if the conditions are not met, the consumer owes nothing for the content supplied. [U]
- **Applicability:** a license key delivered instantly is "performance begun". Without a compliant checkout consent/acknowledgement, EU consumers can withdraw within 14 days (and up to 12 months if not informed) and keep using the app free. Because Gumroad is merchant of record [V], whether Gumroad's checkout captures the Art. 16(m) consent and the Art. 8(7) confirmation is unknown: Gumroad's EU checkout flow was not verified. The developer cannot add a custom checkbox on Gumroad unless it offers one (unverified). Attorney flag.
- Withdrawal button (Art. 11a, inserted by Directive (EU) 2023/2673): distance contracts concluded via an online interface need an electronic "withdrawal function" where a right exists. Applies from 2026-06-19 [U: from memory, not verified] https://eur-lex.europa.eu/eli/dir/2023/2673/oj. Not needed where the right is validly waived under 16(m).
- Practical alternative: offer a voluntary 14-day (or 30-day) no-questions refund through Gumroad's refund tool. That sidesteps the waiver mechanics for a $5+ product. Keep the license revocation mechanism (Gumroad refund disables key via LicenseKit check) consistent.
- Other CRD items: Art. 6 price and trader identity disclosures (an individual trader must give name, geographic address, phone/email, Art. 6(1)(b)-(c)); with no LLC, **the developer's home address may have to be disclosed** unless Gumroad as MoR is the trader of record. Flag; creates a reason to form an entity before EU sales.

### 4.2 Digital Content Directive 2019/770 (DCD)
Primary: https://eur-lex.europa.eu/eli/dir/2019/770/oj [U].
- Scope: B2C supply of digital content/services for a price or against personal data (Art. 3). A paid, keyed app is in scope. Free-and-open-source software is carved out only where the consumer neither pays nor provides personal data (recital 32) [U], so MIT code does not rescue the paid binary.
- Conformity: Art. 7 (subjective: description, quality, functionality, compatibility, **updates provided as stipulated**), Art. 8 (objective: fit for ordinary use, normal quality, **updates including security updates for as long as consumer may reasonably expect**, Art. 8(2)). Art. 9 third-party IP, Art. 10-11 liability (2-year minimum for single-act supply, up to the supply period for continuous), Art. 12 burden of proof reversal (one year for single supply), Art. 14 remedies (bring into conformity, price reduction, termination). Art. 19 modifications; Art. 22 mandatory (no contracting out). [U]
- **Applicability:** the developer must supply security/compatibility updates (new macOS versions, Accessibility/camera API changes) for a "reasonably expected" period, and cannot disclaim it. "As is" language in the EULA is ineffective against EU consumers. Missing notarization and Gatekeeper warnings could be non-conformity. Clearly state supported macOS versions and update policy in the product description (subjective conformity).
- Rome I Art. 6 and Brussels Ia Art. 17-19: consumers keep their home-country mandatory protections and can sue at home when the trader directs activities to their country [U]. As an unincorporated individual, that exposure is personal. Attorney flag.

### 4.3 European Accessibility Act (Directive 2019/882)
Primary: https://eur-lex.europa.eu/eli/dir/2019/882/oj [U]. Applies since 2025-06-28 [U].
- Covered products (Art. 2(1)): consumer general-purpose computer hardware **and its operating systems**, payment terminals, e-readers, ticketing machines, routers, smart TV with computing, etc. A third-party desktop app is not in the list. Covered services (Art. 2(2)): e-commerce services, consumer banking, e-books, audiovisual media, electronic communications, passenger transport. [U]
- Analysis: the app itself appears out of scope (analyst view). The **sales channel** (e-commerce service) is covered, but Art. 4(5): microenterprises providing services (under 10 staff and turnover or balance sheet at most EUR 2M) are exempt from service requirements [U]. Gumroad as the checkout provider bears its own duties. Product page content hosted on Gumroad is within the platform's template accessibility.
- Product fit: eye/hand control apps are accessibility tools; that is a positive, but not a legal safe harbor. Do not market as a "medical device" or "assistive technology" without counsel (MDR/FDA issues are outside this memo).

### 4.4 Other EU consumer items to flag
- Unfair Commercial Practices Directive 2005/29 and Unfair Contract Terms Directive 93/13: EULA terms (liability caps, arbitration, governing-law, class waivers) are scrutinised in B2C. A Massachusetts-governed arbitration clause is likely unenforceable against EU consumers. [U]
- Price display for PWYW: Art. 6(1)(e) CRD total price; tax-inclusive pricing is shown by Gumroad [V: Gumroad adds tax on top; confirm EU consumer display is tax-inclusive].
- Data Act (Reg. 2023/2854, applies 2025-09-12) concerns connected products/related services; no obvious application to a standalone on-device app. [U]

---

## 5. VAT / OSS: Gumroad as merchant of record

- Since January 2025 Gumroad acts as merchant of record for all sales, collecting and remitting sales tax/VAT/GST [V: multiple secondary sources: https://gumkit.app/blog/gumroad-sales-tax-vat/, https://legalclarity.org/how-does-gumroad-handle-sales-tax-for-sellers/; Gumroad help page https://gumroad.com/help/article/121-sales-tax-on-gumroad exists, content not retrieved]. Verify wording in Gumroad's Terms of Service before relying on it.
- EU: electronic-interface deemed supplier rule, Council Implementing Regulation 282/2011 Art. 9a (taxable person facilitating the supply is deemed to supply), plus the OSS regime, Directive 2006/112/EC Art. 358a ff. https://eur-lex.europa.eu/eli/reg_impl/2011/282/oj [U]. Non-EU sellers have no EUR 10,000 micro-threshold (that is for EU-established sellers, Art. 59c) [U]; relevance is moot if Gumroad is the supplier.
- UK: non-UK suppliers of digital services to UK consumers must register for UK VAT from the first sale (no threshold) unless a platform is the deemed supplier. UK's deemed supplier rule for e-services is narrower than the EU's [U]. Rely on Gumroad's statement and ask support to confirm UK/EU treatment in writing. Canada (GST/HST/QST on foreign digital sellers) and Australia (GST on low-value/digital supplies from non-resident sellers) similarly collected by Gumroad per its claim [V: secondary].
- **Developer-side residuals:** US income tax on payouts (outside scope); keeping Gumroad's tax reports; any VAT invoice requests from EU businesses (B2B reverse charge) handled by Gumroad's receipts [U]. Ask Gumroad whether VAT-ID entry for B2B buyers is supported.
- **Effect on consumer law:** MoR status does not by itself shift the developer's DCD/CRD duties as the supplier of the digital content. Who is the "trader" toward the consumer depends on Gumroad's terms [U: unverified]. Attorney flag.

---

## 6. Other markets

### 6.1 Canada
- **PIPEDA** https://laws-lois.justice.gc.ca/eng/acts/p-8.6/ [U]: applies to private-sector organisations collecting personal information in the course of commercial activities; s. 4(2)(b) excludes individuals' purely personal/domestic use. Federal Court recognises extraterritorial reach on a "real and substantial connection" (A.T. v. Globe24h.com, 2017 FC 114) [U]. Developer's duty: Canadian buyer data only; fair information principles (consent, safeguards, access). Light.
- OPC biometrics guidance https://www.priv.gc.ca/en/privacy-topics/health-genetic-and-other-body-data/gd_bio_201102/ [U: 2011 guidance; newer guidance not checked]. Biometrics are treated as sensitive; privacy impact assessment advised.
- **Quebec Law 25** (Act respecting the protection of personal information in the private sector, CQLR c. P-39.1, as amended by Law 25) https://www.legisquebec.gouv.qc.ca/en/document/cs/P-39.1 [U]: applies to enterprises carrying on an economic activity that collect personal information of Quebec residents; privacy officer, privacy policy, incident register, PIAs, consent rules; biometric provisions (Act to establish a legal framework for information technology, ss. 44-45: express consent, disclose creation of a biometric database to the CAI) [U]. Applicability to a US individual with minimal buyer data and no data on its own servers: uncertain; the on-device voice-profile database would belong to a business user. Penalties up to CAD 25M or 4% of worldwide turnover (administrative/penal) [U].
- **Charter of the French Language (Bill 96)** https://www.legisquebec.gouv.qc.ca/en/document/cs/C-11 [U]: commercial software and websites sold in Quebec generally must be available in French (s. 51-52 and regulations; in force June 2025 for several rules). A real market-entry blocker for Quebec; attorney flag.
- CASL (anti-spam) for any marketing emails to Canadians [U].
- Verdict: federal Canada ex-Quebec is a lighter lift. Quebec: exclude initially.

### 6.2 Australia
- **Privacy Act 1988** https://www.legislation.gov.au/C2004A03712/latest/text [U]. Small business operators (turnover at most AUD 3M) are generally exempt (s. 6C-6D), but the exemption fails if the operator trades in personal information; Privacy and Other Legislation Amendment Act 2024 (statutory tort for serious invasions of privacy from 2025-06-10; reforms to children's privacy; the small-business exemption review pending) [U: dates not verified]. Biometric information and templates are "sensitive information" (s. 6(1)) requiring consent [U]. Extraterritorial reach: s. 5B (organisation with an Australian link) [U].
- **Australian Consumer Law** (Schedule 2, Competition and Consumer Act 2010) https://www.legislation.gov.au/C2004A00109/latest/text [U]: consumer guarantees (acceptable quality, fit for purpose, s. 54-55) apply to software, cannot be excluded (s. 64), and apply to overseas suppliers carrying on business in Australia (CCA s. 5). Unfair contract terms with penalties since 2023-11-09 [U]. Refund policy language "no refunds" is misleading; use ACL-compliant statement.
- Recording laws: state surveillance device/listening device statutes (e.g. NSW Surveillance Devices Act 2007) restrict recording private conversations without consent; relevant to Meetings users and docs, not to the developer's legal exposure directly. [U]
- GST on digital supplies from non-residents: Gumroad per MoR claim [V: secondary].

### 6.3 United Kingdom (beyond section 1)
- **Consumer Rights Act 2015, Part 1 Chapter 3 (digital content)** https://www.legislation.gov.uk/ukpga/2015/15/part/1/chapter/3 [U]: satisfactory quality, fitness, as described (ss. 34-36); remedies repair/replacement/price reduction (s. 43); no exclusion (s. 47); also s. 46 on digital content damaging devices.
- **Consumer Contracts (Information, Cancellation and Additional Charges) Regulations 2013** https://www.legislation.gov.uk/uksi/2013/3134/contents [U]: 14-day cancellation with the digital content waiver (reg. 37) requiring express consent and acknowledgement.
- **Digital Markets, Competition and Consumers Act 2024** https://www.legislation.gov.uk/ukpga/2024/13/contents [U]: consumer enforcement and unfair practices regime in force from 2025-04-06; subscription-contract rules delayed (not relevant to one-off keys unless keys become subscriptions).
- UK AI: no statute; UK CRA analogue is PSTI Act 2022 for consumer connectable hardware, not standalone software. [U]
- Verdict: UK is lighter than EU (no CRA, no AI Act, no EAA) but still needs a privacy notice, Art. 27 UK-representative analysis, ICO fee, and consumer-law terms.

### 6.4 Not researched (note only)
Switzerland (FADP), Brazil (LGPD), Japan (APPI), India (DPDP Act), South Korea (PIPA), China (PIPL), and US-state biometric laws (separate memo). Sanctions/export (OFAC, EAR encryption classification for an app with network crypto) not covered here; Gumroad blocks sanctioned jurisdictions per its terms [U].

---

## 7. Summary matrix

| Regime | Applies to a paid, EU-available Humanity? | Main driver | Burden for solo dev | Defer by US-only? |
|---|---|---|---|---|
| GDPR (developer role) | Yes if EU buyers (Art. 3(2)) | License/Gumroad buyer data | Low-moderate (notice, ROPA, maybe Art. 27) | Yes |
| GDPR (users' voiceprints) | User is controller if not household | Art. 9 biometric | Docs/design; indirect | Partly |
| AI Act Art. 5 | Yes (provider) | Emotion/categorisation bans | None if features stay out | n/a |
| AI Act Annex III RBI | Open question for voice profiles | Art. 3(35)/(41), Annex III 1(a) | Potentially very high from 2027-12-02 | Yes, or disable feature |
| AI Act Art. 50 | Probably limited | AI-generated summaries labelling | Low | Partly |
| CRA | Yes | Paid product = commercial activity | High (reporting since 2026-09-11; full 2027-12-11) | Yes |
| CRD withdrawal / DCD | Yes | B2C digital content | Moderate (waiver, update duty); personal liability | Yes |
| EAA | App likely no; sales channel exempt as microenterprise | Art. 2, 4(5) | Low | n/a |
| VAT/OSS | Gumroad MoR | Platform duties | Low if confirmed | n/a |
| UK | Yes if UK buyers | UK GDPR, CRA 2015, DUAA | Moderate | Optional |
| Canada ex-Quebec | PIPEDA; light | Buyer data | Low | Candidate for phase 2 |
| Quebec | Law 25 + French language | Language, biometrics | High | Exclude |
| Australia | Privacy Act small-biz exemption likely; ACL yes | ACL guarantees | Low-moderate | Candidate for phase 2 |

---

## 8. Recommendation: before opening international sales

**Phase 1 (now): US-only.** Reason: the CRA reporting regime and EU consumer duties would attach to an individual with no entity and no liability shield; voice profiles are legally unresolved; notarization is outstanding.

**Before opening any non-US market (all markets):**
1. Notarize the app; keep a documented macOS support/update statement.
2. Form an entity (LLC or equivalent) after tax/legal advice, for liability separation and address disclosure issues (CRD Art. 6; EU consumer suits at home).
3. Publish a privacy notice for **buyer data** (what Gumroad shares, retention, rights contact) separate from PRIVACY.md; add a data-subject-request process.
4. Rewrite the EULA/Terms for consumer-mandatory rights: no "as is" disclaimer against consumers, no US-only arbitration for EU/UK consumers, local-law carve-out paragraph.
5. Confirm with Gumroad in writing: MoR scope, VAT handling for EU/UK/CA/AU, whether Gumroad's checkout collects the Art. 16(m) consent/acknowledgement, who is "trader", refund controls, country restriction options.
6. Decide the refund policy: a voluntary 14-day refund is simplest.

**Before EU opening specifically:**
- CRA programme: CVD policy, SECURITY.md upgrade, SBOM, support-period statement (5+ years), supplier due diligence on third-party models, technical file and EU declaration of conformity, ENISA reporting procedure, decision on CE marking process. Get counsel to confirm classification and microenterprise relief.
- AI Act: written classification memo covering voice profiles (RBI/high-risk) and Art. 50; if unresolved, ship the EU build without cross-meeting voice-profile matching, or restrict to self-enrolment. Add "AI-generated" labelling for AIKit summaries.
- GDPR: Art. 27 representative decision, Art. 30 record, transfer mechanism, EU-specific privacy section ("business users are controllers; obtain explicit consent from participants before voiceprints; voiceprints are special-category data").
- Product docs: in Meetings, add an in-app consent prompt/acknowledgement when creating a voice profile of a third party, and an export/delete-per-person function (supports Art. 15-17 for users acting as controllers).
- Accessibility statement (voluntary), even if EAA is likely inapplicable.

**Before UK/Canada ex-Quebec/Australia (phase 2, lighter):** UK Art. 27 and ICO fee decision; PIPEDA notice; ACL and CRA 2015 terms. Keep Quebec excluded until French localization and Law 25 review.

**Attorney-review flags (priority order):** (1) AI Act RBI classification of voice profiles; (2) CRA manufacturer status and Annex III class; (3) Art. 16(m) and Gumroad's trader/checkout mechanics; (4) Art. 3(2) and 27 conclusions for a US-only-but-reachable store; (5) open-source exemption (AI Act Art. 2(12), CRA commercial activity) for MIT + paid keys; (6) Quebec language/Law 25; (7) personal liability and entity formation.

---

## 9. How to limit to US sales on Gumroad (practical, with unknowns)

Facts: Gumroad documentation retrieved by search shows country restriction only for physical-product shipping destinations [V]. No native "block these countries" setting for digital products was found. Treat as **unverified**; check dashboard (Settings, product Share/Checkout tabs) and ask support.

Steps, in order of strength:
1. **Ask Gumroad support** whether buyer-country restrictions exist for digital products and whether EU sales can be disabled account-wide. Keep the reply.
2. **Product page and Terms:** "Available to customers in the United States only. By purchasing you confirm you are a US resident." USD only, English only, no EU/UK payment methods, no EU marketing (EDPB 3/2018 targeting factors; recital 23). This reduces Art. 3(2) and "directed activities" arguments but cannot technically stop a purchase.
3. **Do not run EU-targeted campaigns, translations, or EU-language listings,** and avoid promoting on EU sites/marketplaces.
4. **Refund-and-revoke:** if a non-US purchase appears (Gumroad shows buyer country in sales data, per its dashboard [U]), refund it and revoke the key, citing the US-only terms. The Gumroad license verify API response may include purchase details like country or IP-derived country that LicenseKit could check at activation (unverified: inspect an actual API response in test mode; a client-side check on an unreachable server model is also trivially bypassable, and refusing activation after payment raises its own consumer-law issues, so prefer pre-refund).
5. **Keep the free DMG:** the DMG is free and global; geo-blocking a download is neither necessary nor easy. Because activation needs a paid key, the exposure is only on key sales. State in README/website that licenses are sold to US customers only.
6. **Review quarterly** whether any EU/UK purchases slipped through, and log them for counsel.
7. Reality check: with Gumroad as MoR charging VAT [V], Gumroad's own checkout may accept EU buyers regardless of the seller's wishes; step 1 is decisive.

---

## 10. Sources verified (2026-10-01)

Retrieved via search this session (secondary or regulator pages, content seen in results):
- EC CRA pages: https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act and https://digital-strategy.ec.europa.eu/en/policies/cra-reporting (listed; dates 2026-09-11 and 2027-12-11 per summaries)
- Skadden (Sept 2026) https://www.skadden.com/insights/publications/2026/09/get-ready-reporting-faqs-and-checklist ; Kirkland https://www.kirkland.com/publications/kirkland-alert/2026/09/the-eu-cyber-resilience-act (listed)
- CRA commercial activity/steward summaries: https://best.openssf.org/CRA-Brief-Guide-for-OSS-Developers.html and https://www.cyberresilienceact.eu/explained.html (listed)
- AI Act omnibus: https://www.joneswalker.com/en/insights/blogs/ai-law-blog/yes-august-2-still-matters-the-eu-approved-a-high-risk-ai-delay-but-most-trans.html ; https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/ ; https://usercentrics.com/knowledge-hub/eu-ai-act-high-risk-delay-article-50-transparency-consent/ ; https://www.aiactblog.nl/en/posts/article-50-transparency-deadline-2-august-2026
- EDPB Guidelines 3/2019 on video devices (excerpts via search): https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices.pdf
- Gumroad MoR: https://gumkit.app/blog/gumroad-sales-tax-vat/ ; https://legalclarity.org/how-does-gumroad-handle-sales-tax-for-sellers/ ; https://gumroad.com/help/article/121-sales-tax-on-gumroad (title only) ; https://gumroad.com/help/article/10-dealing-with-vat (listed)
- Local files read: /Users/taylorpan/Cloud/Humanity/PRIVACY.md and the brief.

NOT retrieved (fetch failed or not attempted; all article citations from analyst knowledge): all EUR-Lex texts (GDPR, AI Act, CRA, CRD, DCD, EAA, Directive 2019/2161, 2023/2673, Reg. 282/2011), UK legislation.gov.uk pages, PIPEDA/Quebec/Australian statutes, ICO and OPC guidance, EDPB 3/2018 and 07/2020. Law-firm summaries of the Digital Omnibus and CRA dates should be re-checked in the Official Journal. No amendments or cases dated 2025-2026 were independently verified beyond those listed above.
