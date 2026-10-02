# 05 - US state privacy laws vs. Humanity (solo MA developer selling via Gumroad)

Research analyst notes, not legal advice. Nothing here says the product is "compliant" or "safe". As of 2026-10-01.

Verification tags used below:
- **[P]** = text or status page read from an official or primary source this session.
- **[S]** = taken from a law-firm or news summary read this session (primary text not read).
- **[M]** = from my background knowledge, NOT re-verified this session. Treat as unverified until checked.

## 1. Bottom line

1. **No comprehensive state privacy law identified here clearly reaches this developer today.** The count-based laws need tens of thousands of consumers' data, or a revenue floor, or sale of data. A solo seller with small sales volume, who only holds Gumroad buyer records, is far below every number found. The developer does not sell personal data.
2. **Texas (TDPSA) and Nebraska (NDPA) have no consumer-count threshold.** They cover anyone doing business or serving residents who processes or sells personal data and is not an SBA "small business". A small developer is expected to fall in the exempt group, but the two laws still impose one rule on small businesses: do not sell sensitive data without consent. Minnesota and Louisiana are reported to have a similar small-business rule [S]. Humanity does not sell data, so this rule should not be triggered.
3. **Open edge: biometrics.** Colorado's biometric amendment (HB24-1130, effective 2025-07-01) is reported to apply to any controller handling any amount of biometric data, regardless of thresholds [S]. Humanity (eye patches, voiceprints) keeps this data on the user's Mac. If the developer never receives it, the developer is arguably not a controller or processor of it. That is a legal judgment call, so it is flagged for an attorney (section 8).
4. **Massachusetts has no comprehensive privacy law as of 2026-10-01.** The bill passed each chamber unanimously, but the two versions differ and the bill sat in a conference committee. No enactment found (section 5).
5. **MA G.L. c.93H and 201 CMR 17.00 are the Massachusetts rules that do apply to everyone.** But "personal information" there means name plus SSN, driver's license/state ID number, or financial account/card number. Names and emails alone are not "personal information" [P]. On the facts given, they are probably not triggered, but this depends on what the developer actually stores (section 6).
6. **Gumroad's role matters.** Its terms say it is merchant of record [S/P-fetch]. Its privacy policy says it processes buyer data on behalf of sellers and that the seller is the controller of buyer data for the sale [S/P-fetch]. So the developer is likely the "controller" of the buyer records they can see in the Gumroad dashboard, and that is the data in play (section 4).

## 2. Master table: enacted laws as of 2026-10-01

"Small-biz" = express small-business exemption. "Sens. consent" = opt-in for processing sensitive data (all laws below except where noted). Effective dates are for the base law unless stated.

| Law | Eff. | Applicability threshold | Small-biz exemption | Sensitive-data note | Tag |
|---|---|---|---|---|---|
| **CA** CCPA/CPRA, Civ. Code 1798.100 ff | 2020 / 2023 | Does business in CA AND any of: gross revenue over $26.625M (CPI-adjusted from 2025-01-01); buys/sells/shares PI of 100,000+ consumers or households; 50%+ revenue from selling/sharing PI | Revenue/volume test acts as the exemption. No separate SBA test | Opt-out / right to limit use of sensitive PI (not opt-in) | [S] thresholds; CPPA page |
| **VA** VCDPA, Va. Code 59.1-575 ff | 2023-01-01 | Controls/processes data of 100,000 consumers, or 25,000 plus over 50% revenue from sale | None express; thresholds only | Opt-in consent | [M] |
| **CO** CPA, C.R.S. 6-1-1301 ff | 2023-07-01 | 100,000 consumers, or 25,000 plus any revenue/discount from sale. **Biometric part (HB24-1130, 2025-07-01) applies to any controller handling any biometric data regardless of those thresholds** | None express. Biometric rule reaches below-threshold entities | Opt-in consent; biometric: written retention policy and consent | [S] biometric; [M] base |
| **CT** CTDPA, Conn. Gen. Stat. ch. 743jj; SB 1295 (2025) | 2023-07-01; amended **2026-07-01** | After SB 1295 (eff. 2026-07-01): 35,000 consumers (was 100,000), OR processes sensitive data (any number), OR offers personal data for sale | None. Sensitive-data and sale prongs reach tiny businesses | Opt-in; sale of sensitive data needs consent; minimization now "reasonably necessary **and proportionate**" | [S] |
| **UT** UCPA, Utah Code 13-61 | 2023-12-31 | Over $25M revenue AND (100,000 consumers, or 25,000 plus over 50% revenue from sale) | Revenue floor | Notice and opt-out (weaker than others) | [M] |
| **TX** TDPSA, Tex. Bus. & Com. Code ch. 541 | 2024-07-01 | **No count threshold.** Conducts business in TX or makes product/service consumed by TX residents; processes or sells personal data; AND not an SBA "small business" [P 541.002(a)] | **Yes: SBA small business exempt, except 541.107** | Opt-in consent for processing [P 541.101]. **Small business may not sell sensitive personal data without consent [P 541.107]** | [P] |
| **OR** OCPA, ORS 646A.570 ff | 2024-07-01 (nonprofits 2025-07-01) | 100,000 consumers, or 25,000 plus 25%+ revenue from sale. 2025 amendment (HB 2008) bans sale of data of under-16s and of precise geolocation (1,750 ft) | None | Opt-in; | [S] amendment; [M] base |
| **MT** MCDPA, SB 297 (2025) | 2024-10-01; amended 2025-10-01 | 25,000 consumers (was 50,000), or 15,000 if 25%+ revenue from sale (was 25,000). Minor-protection sections apply regardless of volume. Cure period removed | None | Opt-in | [S] |
| **IA** ICDPA, Iowa Code ch. 715D | 2025-01-01 | 100,000 consumers, or 25,000 plus 50%+ revenue from sale | None express | Notice and opt-out (not opt-in) | [M] |
| **DE** DPDPA, 6 Del. C. ch. 12D; HB 380/381 (signed 2026-09-02, eff. **2027-01-01**) | 2025-01-01 | Base: 35,000 consumers, or 10,000 plus over 20% revenue from sale. Governor says 2026 bills lower to 10,000 consumers; broaden sensitive data (incl. neural, financial credentials, gov't ID, inferences) | None | Opt-in | [S] 2026 bills; [M] base. Details need primary check |
| **NH** SB 255, RSA ch. 507-H | 2025-01-01 | 35,000 consumers, or 10,000 plus over 25% revenue from sale | None | Opt-in | [M] |
| **NJ** NJDPA, P.L. 2023 c.266 | 2025-01-15 | 100,000 consumers, or 25,000 plus revenue/discount from sale | None | Opt-in | [M]; 2026 amendment reported [S] |
| **TN** TIPA | 2025-07-01 | Over $25M revenue AND (175,000 consumers, or 25,000 plus over 50% revenue from sale) | Revenue floor | Opt-in | [M] |
| **MN** MCDPA, Minn. Stat. ch. 325M | 2025-07-31 | 100,000 consumers, or 25,000 plus over 25% revenue from sale | **SBA small business exempt, except it may not sell sensitive data without consent** | Opt-in. Also minimization/ data-inventory duties | [M] verify |
| **MD** MODPA, SB 541 (Ch. 455) | 2025-10-01; enforced for processing from **2026-04-01** | **35,000 consumers (no revenue condition), or 10,000 plus over 20% revenue from sale** [S] | None; nonprofits also covered [S] | **Sale of sensitive data prohibited outright [P synopsis]; sensitive data only if strictly necessary** [S] | [P] partial |
| **IN** | 2026-01-01 | 100,000 consumers, or 25,000 plus 50% revenue from sale | None | Opt-in | [M] |
| **KY** | 2026-01-01 | Same pattern as IN: 100,000 / 25,000 plus 50% | None | Opt-in | [M] |
| **RI** | 2026-01-01 | 35,000 consumers, or 10,000 plus over 20% revenue from sale [S] | None | Opt-in; penalties to $10,000/violation | [S] |
| **NE** NDPA, LB 1074 | 2025-01-01 | **No count threshold.** Does business in NE or serves residents; processes or sells personal data; AND not an SBA small business [P 87-1103] | **Yes, SBA small business exempt, except 87-1118** | **Small business shall not sell sensitive data without prior consent [P 87-1118]** | [P] |

### 2025-2026 additions (new states)

| Law | Signed | Eff. | Thresholds | Notes | Tag |
|---|---|---|---|---|---|
| **OK** SB 546 | 2026-03-20 | 2027-01-01 | 100,000 consumers, or 25,000 plus over 50% revenue from sale | Consent for sensitive data; 30-day cure that does not sunset; AG only; $7,500/violation | [S] |
| **AL** HB 351, Personal Data Protection Act | 2026-04-17 | 2027-05-01 | 25,000 consumers, or 25% revenue from sale | Reported exemption for businesses under 500 employees and nonprofits under 100 (that don't sell); opt-in for sensitive; 45-day cure; up to $15,000/violation | [S] contradictory-looking, verify |
| **LA** SB 386 | 2026-05-29 | 2027-01-01 | Revenue over $25M, or 75,000 consumers/households/devices, or 50% revenue from selling PI | Reportedly a Texas-style rule: small businesses may not sell sensitive data without consent | [S] |
| **VT** S.71, Data Privacy and Online Surveillance Act | 2026-06-16 | 2028-01-01 | 35,000 consumers, or 3,000 with sensitive data, or 3,000 offered for sale | Minimization "reasonably necessary and proportionate"; consent for sensitive; no private right of action; cure to 2029-06-30 | [S]. The source's "fourth state this year" list looked wrong; recount needed |

Notes: 2026 count of new comprehensive laws is OK, AL, LA, VT (four) by my reading [S]. Not verified: any other 2025-2026 enactment (e.g. PA, others). Arkansas has a 2026-07-01 children's-privacy law, which is not comprehensive [S, low confidence]. Several 2025 laws (e.g. CT, MD, MT, OR, VA, NH, NJ, KY) were amended; thresholds above reflect what I found, and a 50-state primary check was not completed.

## 3. The specific rules you asked about

### 3.1 Texas: sale of sensitive data by small businesses
- Scope clause [P, https://texas.public.law/statutes/tex._bus._&_com._code_section_541.002]: applies to a person that (1) conducts business in Texas or makes a product/service consumed by residents, (2) processes or sells personal data, and (3) is not an SBA small business, "except to the extent that Section 541.107 ... applies".
- 541.107 [P via https://texas.public.law/statutes/tex._bus._and_com._code_section_541.107]: a person in the small-business group "may not sell sensitive personal data without first obtaining consumer consent." Penalties via 541.155. In Texas this has no revenue or count floor.
- Sensitive-data consent and minimization (541.101): collection limited to "adequate, relevant, and reasonably necessary" for disclosed purposes; no processing of sensitive data without consent [P via public.law summary; confirm on official text].
- Texas also requires a specific notice for those who sell sensitive data (the "NOTICE: We may sell your sensitive personal data" wording) [M, unverified].
- Official statute: https://statutes.capitol.texas.gov/Docs/BC/htm/BC.541.htm (page is JavaScript-rendered; I read the text via public.law).

### 3.2 Nebraska: no-threshold provision
- 87-1103 [P, https://nebraskalegislature.gov/laws/statutes.php?statute=87-1103]: applies to a person that does business in Nebraska or serves residents, processes or sells personal data, and is not a small business under the federal Small Business Act. Same shape as Texas.
- 87-1118 [P, https://nebraskalegislature.gov/laws/statutes.php?statute=87-1118]: a small-business person "shall not engage in the sale of personal data that is sensitive data without receiving prior consent from the consumer".
- Texas and Nebraska are the only no-count-threshold laws I found, plus Minnesota's small-business structure [M] and CT/VT sensitive-data prongs (which use "any amount of sensitive data" rather than SBA status).

### 3.3 Maryland: data minimization (strongest in the country)
- Source: SB 541 / Ch. 455 [P synopsis: https://mgaleg.maryland.gov/mgawebsite/Legislation/Details/sb0541?ys=2024RS]; operative description from [S] (OneTrust, Potomac Law, etc.).
- Collection of personal data must be reasonably necessary and proportionate to provide or maintain a product/service the consumer requested [S].
- Sensitive data: collect/process/share only if **strictly necessary** to provide or maintain the specific product the consumer requested; **sale of sensitive data is banned**, consent does not cure it [P synopsis states ban; S for "strictly necessary"].
- Applies to 35,000 consumers (no revenue condition) or 10,000 plus over 20% revenue from sale; no small-business exemption; enforcement for processing activities from 2026-04-01; MCPA penalties up to $10,000, $25,000 for repeat [S].
- Relevance: Humanity's design (local processing, no developer-side collection) matches the spirit. If the developer ever received sensitive data (biometrics, voice), Maryland's "strictly necessary" test is the hardest to meet.

### 3.4 Massachusetts bill thresholds: see section 5.

## 4. Which of these could reach this developer

Facts assumed (from the brief and PRIVACY.md): one individual in MA, no entity, small sales, pay-what-you-want from $5; the developer receives only Gumroad sale records; license check sends key + product ID to Gumroad; no telemetry; no servers; sensitive data (face, gaze, voiceprints, audio) stays on the user's device.

| Law type | Reaches the developer? | Why |
|---|---|---|
| CA, UT, TN, LA (revenue-floor laws) | No (very likely) | Needs $25M+ revenue, or 100k/175k/75k consumers, or sale-driven revenue. Small sales volume is far below. |
| VA, CO (base), UT, IA, IN, KY, NJ, OR, MN, MT, OK, AL | No on counts | 25,000-100,000 consumer minimums. Gumroad buyer count is a small fraction. Not selling data. Confirm customer count stays well under 15,000-25,000. |
| MD, DE, NH, RI, CT, VT (35,000 / 10,000 / 3,000-style thresholds) | No on counts today | DE (reported 10,000) and VT (3,000 sensitive/sale prongs, eff. 2028) are the lowest. Volume growth to those levels is the trigger to watch. |
| **CT / VT "any sensitive data" prongs** | **Only if the developer processes sensitive data** | Developer does not receive the biometric/voice data. If a future feature uploads it (crash reports, cloud sync, support attachments), CT (2026-07-01) could apply at any volume. |
| **TX, NE** (no count threshold) | Facially reachable if not an SBA small business; a solo developer is expected to be a small business | Check size standard at 13 CFR 121.201 for the NAICS code (software publishing) [M]. If small business: only duty is no sale of sensitive data without consent. Developer sells nothing. Also note texting "sale" = exchange for money/valuable consideration [P NE 87-1102]. |
| **MN** | Likely small-business exempt, with the same sale limit | [M]; verify. |
| **CO biometric rule** | **Open question** | Applies to any controller that "controls or processes" biometric data regardless of thresholds [S]. Developer's code processes it on-device, but the developer never possesses it. Attorney should decide whether shipping software that processes biometrics locally makes the developer a controller. Does not appear to if no data leaves the device. |
| **MD MODPA** | No on counts; relevant as a design benchmark | Applies at 35,000. Sale of sensitive data banned. |

### Gumroad's role
- Terms of Service (last updated 2026-09-14 per fetch): Gumroad is "the merchant of record for the resale of your Products to the Buyers," while the Product is "licensed by you through Gumroad" [S/fetch: https://gumroad.com/terms].
- Privacy policy (last revised 2026-07-15 per fetch): Gumroad uses buyer data "as directed or authorized by the seller" and states that "the relevant seller is the data controller" for data processed in connection with the sale [fetch: https://gumroad.com/privacy]. Read the policy yourself; the wording is machine-summarized.
- Implication: the developer is the controller (or the equivalent "business") of the buyer name/email/license data they see in the Sales dashboard or CSV export. Gumroad runs checkout, payment, taxes (merchant of record), and the license-key API. The developer sees no card numbers [S].
- Tension to flag: Gumroad calls itself both merchant of record and a processor for sellers. An attorney should confirm who is "controller" for each data flow, particularly the per-seller license verification call from the app.
- Gumroad's own terms make sellers responsible for notices required by law if they deliver products containing others' personal information [fetch] - not directly applicable here, but relevant to Voice Profiles (see section 8).

## 5. Massachusetts Data Privacy Act status (as of 2026-10-01)

**Did it pass? No. Not enacted as of the last status I could verify.**

- Senate: S.2608 reprinted and passed 40-0 on 2025-09-25 (as S.2619) [P: https://malegislature.gov/Bills/194/S2619].
- House: passed an amended version 146-0 on 2026-06-04 (H.5479) [P: https://malegislature.gov/Bills/194/S2619; https://malegislature.gov/Bills/194/H5479].
- Senate non-concurred and appointed conferees 2026-06-11; House insisted and appointed conferees 2026-06-17 [P]. Conference initial meeting 2026-07-07; still meeting around 2026-07-30 [P: https://malegislature.gov/Events/Hearings/Detail/5739; S].
- As of the bill history I fetched, the most recent action was 2026-06-17 and the bill "remains in conference committee, has not been enacted" [P]. I found no later enactment or governor signature. **Gap:** I did not confirm what happened at the 2026-07-31 end of formal sessions. Check https://malegislature.gov/Bills/194/S2619 before relying on this.
- Common name confusion: "Consumer Data Privacy Act" (2023-24 session bills) died with the prior session; the live vehicle is the "Massachusetts Data Privacy Act" (2025-26).

Thresholds in the two versions (read from the bill PDFs, https://malegislature.gov/Bills/194/S2619.pdf and https://malegislature.gov/Bills/194/H5479.pdf) [P]:

| | Senate (S.2619) | House (H.5479) |
|---|---|---|
| Applies to persons that, in preceding year | collected/processed data of **60,000+ consumers** (excl. payment-only); OR **20,000+ consumers and 20%+ gross revenue from sale**; OR collected/processed/transferred **reproductive or sexual health data (any amount)** | do business in MA and target MA residents AND: **100,000+ consumers** (excl. payment-only); OR **$100,000+ gross revenue from sale of personal data**; OR **collected or processed any sensitive data** (excl. payment-only) |
| Sensitive data | Sale banned outright; collect/process only if strictly necessary for a requested product [bill text] | Sale allowed with consent (precise geolocation sale barred per [S]); minimization "reasonably necessary and proportionate" [bill text line 1182] |
| Enforcement | AG only; 60-day cure [bill text] | Private right of action against "large data holders" (2M+ consumers or 200k+ sensitive) [S]; no cure [S] |
| Effective | Section 1 effective 2027-01-01 / 2027-06-01 [bill text] | 2027-07-01 [bill text] |
| Small-business exemption | None found in text | None found in text ("small business" not in House text) |

**Implication if the House version prevailed:** the "any sensitive data" prong would reach a developer who processes any sensitive data of MA residents, including Humanity's biometric/voice data if the developer processed it. Because the data stays on user devices, the developer is probably still not a "controller". That is a reason to keep the no-collection architecture and re-check the final bill text. If the Senate version prevailed, thresholds would not reach the developer, except for reproductive/sexual health data (not relevant).

## 6. MA G.L. c.93H and 201 CMR 17.00

- **c.93H s.1 definition [P: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93H/Section1]:** "Personal information" = resident's first and last name (or first initial and last name) **in combination with** any of: (a) SSN; (b) driver's license or state ID number; (c) financial account number or credit/debit card number (with or without access code). Excludes lawfully public information.
- **s.3 [P: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93H/Section3]:** a person that owns or licenses such personal information must notify the AG, the Director of Consumer Affairs and Business Regulation, and affected residents "as soon as practicable and without unreasonable delay" after a breach of security or unauthorized acquisition/use.
- **201 CMR 17.01 [P via Cornell LII summary: https://www.law.cornell.edu/regulations/massachusetts/201-CMR-17-01; mass.gov page returned 403]:** applies to "all persons that own or license personal information about a resident of the Commonwealth", and 17.03 requires a written information security program (WISP); 17.04 sets computer-system controls (encryption, access, firewalls etc.) [M for 17.03/17.04 specifics; verify].
- The definition of "owns or licenses" in s.1 was not retrieved (page truncated). My recollection is it covers anyone who receives, stores, maintains, processes or has access to personal information in connection with providing goods or services [M, unverified].

**Do they apply when the developer holds customers' names and emails via Gumroad?**
- On the facts given: **probably not triggered**, because a name plus an email is not "personal information" under s.1. Neither SSN, license/ID number, nor financial/card number is held (Gumroad keeps payment data [S]).
- The rule bites if the developer's files ever hold a name together with a card/bank number, SSN, or ID number. Examples: a refund spreadsheet with card numbers, a support attachment with an ID photo, or a tax form (W-9/1099) data for others. The developer's own tax and payout info is the developer's data, not customers'.
- Note: the statute has no revenue or size exemption. Applicability turns solely on the data type. If it were triggered, a WISP would be due, so a short written security note is cheap insurance.
- Attorney question: does a license key plus name/email combination, or the Voice Profiles voiceprint of a named person, ever become "personal information" under a broader reading? Statutory text suggests no.

## 7. Recommended minimal obligations (for attorney review before adoption)

Low-cost steps that match the facts. Not a compliance determination.

1. **Keep the architecture.** Do not add telemetry, crash upload, cloud sync, support attachments with audio/video/face data, or analytics without re-running this analysis. That choice is what keeps the sensitive-data prongs (CT, VT, MA House version, CO biometric) from applying.
2. **Never sell or share buyer data.** No sale, no ad-tech, no list rental. This single rule covers the Texas, Nebraska, Minnesota, Louisiana small-business restrictions and the MD sale ban.
3. **Publish a short privacy notice** (PRIVACY.md is already good). Add: who the developer is (name + contact email), that Gumroad is the merchant of record and holds payment data, that the developer receives buyer name/email/license/sale records from Gumroad and uses them only for support, license verification, and legal/tax needs, retention period, how to request deletion, and that no personal data is sold.
4. **Honor requests anyway.** Answer access/delete requests by email within about 45 days (the common statutory window [M]); use Gumroad's tools to find and delete. Not legally required today at this scale but low effort.
5. **Minimize and secure buyer data.** Do not export CSVs unnecessarily; if exported, keep on an encrypted disk; use a strong unique password and 2FA on the Gumroad account; delete exports when done.
6. **No card/SSN/ID data in files.** If one appears, delete it. This keeps c.93H and 201 CMR 17 out of play. Keep a one-page note of these practices; that doubles as a "WISP-lite" if a regulator asks.
7. **Breach plan, 5 lines.** If the Gumroad account or a buyer export is compromised: change credentials, check Gumroad notices, assess whether personal information (as defined in c.93H) was involved; if yes, call a lawyer and notify per c.93H s.3.
8. **Trigger watchlist.** Re-run this review when: buyers exceed ~10,000 (DE reported threshold, VT sale/sensitive prong 3,000), the developer forms an LLC or starts a company, any feature moves biometric/voice/audio data off device, international sales begin (GDPR is outside this file), or the MA bill is enacted.
9. **Business hygiene.** Consider forming an entity and keeping separate accounts. This is a legal-structure issue, not a privacy requirement; attorney discussion.

## 8. Attorney-review flags

1. Colorado HB24-1130 applicability to a software publisher whose app processes biometrics locally (does "controls or processes" cover a developer who never receives the data?). Read C.R.S. 6-1-1304 and AG rules (https://content.leg.colorado.gov/sites/default/files/2024a_1130_signed.pdf; PDF not decoded this session).
2. Texas/Nebraska SBA size test for an individual developer; correct NAICS code and the size standard (13 CFR 121.201); whether pay-what-you-want revenue matters.
3. Whether Gumroad is controller, processor, or independent business for buyer data; interaction between Gumroad's processor language and merchant-of-record status.
4. **Voice Profiles** of named non-users (voiceprints stored locally). Not developer-held data, but it creates notice/consent issues for users (e.g. biometric laws: Illinois BIPA 740 ILCS 14, Texas CUBI Bus. & Com. Code 503.001, Washington biometric law RCW 19.375 and My Health My Data Act [all M, unverified]). Those apply to whoever "captures" the biometric; whether the developer counts is an open question. They are outside this file's scope but could matter more than the comprehensive laws. Recommend a separate memo.
5. MA bill final text if enacted (House's "any sensitive data" prong).
6. CT SB 1295 and DE HB 380/381 primary text; neural/inference definitions may touch gaze or voice features.
7. Recount of 2025-2026 enactments; I did not complete a primary-source sweep of every state.

## 9. Sources verified (accessed 2026-10-01)

Primary / official [P]:
- TX Bus. & Com. Code 541.002 and 541.107 (read via texas.public.law): https://texas.public.law/statutes/tex._bus._&_com._code_section_541.002 ; https://texas.public.law/statutes/tex._bus._and_com._code_section_541.107 ; official: https://statutes.capitol.texas.gov/Docs/BC/htm/BC.541.htm
- NE Rev. Stat. 87-1102, 87-1103, 87-1118: https://nebraskalegislature.gov/laws/statutes.php?statute=87-1103 ; https://nebraskalegislature.gov/laws/statutes.php?statute=87-1118
- MD SB 541 page: https://mgaleg.maryland.gov/mgawebsite/Legislation/Details/sb0541?ys=2024RS
- MA bill history S.2619 / H.5479 and conference notice: https://malegislature.gov/Bills/194/S2619 ; https://malegislature.gov/Bills/194/H5479 ; https://malegislature.gov/Events/Hearings/Detail/5739
- MA bill texts (decoded locally): https://malegislature.gov/Bills/194/S2619.pdf ; https://malegislature.gov/Bills/194/H5479.pdf
- MA G.L. c.93H s.1 and s.3: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93H/Section1 ; .../Section3
- 201 CMR 17.01 (Cornell LII): https://www.law.cornell.edu/regulations/massachusetts/201-CMR-17-01
- CPPA threshold adjustment page (search result, not opened): https://www.cppa.ca.gov/regulations/cpi_adjustment.html
- Colorado HB24-1130 page and signed act: https://leg.colorado.gov/bills/hb24-1130 ; https://content.leg.colorado.gov/sites/default/files/2024a_1130_signed.pdf

Secondary [S] (law-firm/news, not primary):
- Vermont: https://www.insideprivacy.com/state-privacy/vermont-data-privacy-bill-signed-into-law/
- Louisiana: https://www.troutmanprivacy.com/2026/06/louisiana-enacts-consumer-data-privacy-law/
- Oklahoma: https://www.mayerbrown.com/en/insights/publications/2026/03/oklahoma-enacts-comprehensive-consumer-data-privacy-law
- Alabama: https://www.hunton.com/privacy-and-cybersecurity-law-blog/alabama-becomes-21st-state-with-comprehensive-consumer-privacy-law
- Delaware 2026 bills: https://news.delaware.gov/2026/09/02/governor-meyer-signed-historic-data-privacy-legislation-protecting-delaware-residents-and-businesses/ (official press release)
- CT SB 1295 and other amendments: https://www.morganlewis.com/pubs/2026/07/us-state-consumer-privacy-law-update-notable-changes-across-existing-frameworks
- Overview of 2026 effective dates: https://www.multistate.us/insider/2026/2/4/all-of-the-comprehensive-privacy-laws-that-take-effect-in-2026
- Montana SB 297: https://www.insideprivacy.com/state-privacy/montana-passes-amendments-to-consumer-data-privacy-act/ ; https://dojmt.gov/office-of-consumer-protection/montana-consumer-data-privacy/
- MA bill comparison: https://foleyhoag.com/news-and-insights/blogs/state-ag-insights/2026/june/one-step-closer-to-a-massachusetts-data-privacy-law-comparing-the-current-house-and-senate-bills/
- Gumroad terms and privacy: https://gumroad.com/terms ; https://gumroad.com/privacy ; https://help.gumroad.com/article/120-protecting-your-privacy-on-gumroad
- Gumroad merchant-of-record blog (page content did not load; claim of MoR from Jan 2025 rests on search snippets): https://gumroad.com/blog/p/gumroad-is-becoming-a-merchant-of-record-more-updates

Not verified (marked [M]): VA, UT, IA, IN, KY, NH, NJ, TN, MN, OR, CA base thresholds and small-business details, Texas sale-notice wording, 201 CMR 17.03/17.04 details, 93H "owns or licenses" definition, adjacent biometric statutes. Verify each from the official legislature site before relying on it.
