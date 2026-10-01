# 11 - Taxes, Export Controls, OFAC (Humanity suite, individual MA seller via Gumroad)

Research analyst notes, 2026-10-01. **Not legal or tax advice.** Nothing here says the product or seller "is compliant" or "is safe". Items marked **[UNVERIFIED]** could not be confirmed against a primary source in this session. "Secondary" means a law-firm/blog/search summary, not the official text.

## 0. Bottom line

| Topic | Short answer | Confidence |
|---|---|---|
| Gumroad as merchant of record (MoR) | Yes. Gumroad's own Terms (effective Jan 1, 2025; last updated Sept 14, 2026) and Help Center say Gumroad is MoR/reseller and is "treated as the seller" for Indirect Tax (sales/VAT/GST). New in 2025. | High (Gumroad primary text) |
| MA sales tax | Electronic delivery of prewritten software is taxable in MA. If Gumroad is the retailer, Gumroad collects/remits; the seller's duty is mostly to confirm that and keep records. Residual duty exists for any sale made outside Gumroad. | High on law; **MA-specific Gumroad collection UNVERIFIED** |
| 1099-K | Threshold is $20,000 AND more than 200 transactions (statute restored retroactively by Pub. L. 119-21 section 70432, July 4, 2025). Income is taxable whether or not a 1099-K arrives. | High (statute + IRS release) |
| Federal / SE tax | Net profit is income on Schedule C; SE tax 15.3% on 92.35% of net earnings if net SE earnings are $400 or more; quarterly estimates likely. | High |
| MA income tax | Flat 5% on most income (4% surtax over about $1.08M in 2025). MA has no SE tax. | Medium (rate per secondary; statute text shows a formula) |
| Export controls | Most likely EAR99 or, if treated as encryption, 5D992.c mass market. Source on GitHub is "published" and outside the EAR. Probably no BIS report or registration for either path, but classification matters for Russia/Belarus. | Medium; needs written self-classification |
| OFAC | Gumroad blocks comprehensive-sanctions jurisdictions at checkout. Seller keeps strict-liability exposure for anything outside Gumroad's gate (free DMG, comp keys, direct dealings). 10-year recordkeeping. | High on rules; Gumroad's SDN-name screening UNVERIFIED |

---

## 1. Taxes

### 1.1 Gumroad: merchant of record, US sales tax, VAT

**What Gumroad says (primary, fetched 2026-10-01):**

| Source | Statement | URL |
|---|---|---|
| Help: Sales tax on Gumroad | "Gumroad now acts as the Merchant of Record for all sales... we automatically handle all sales tax collection and remittance worldwide." Exception: physical goods shipped into the 27 EU states (no VAT at checkout; import VAT at the border). Digital products unaffected. Also offers a Reseller Certificate (CA, dated 01JAN25) for sellers who already file returns. | https://gumroad.com/help/article/121-sales-tax-on-gumroad |
| Help: EU & UK VAT | "For all sales to EU and UK buyers, Gumroad acts as the 'merchant of record'", collects and remits VAT, no seller forms. Seller cannot opt out or make prices VAT-inclusive. | https://gumroad.com/help/article/10-dealing-with-vat |
| Terms of Service, sec. 6.1, 6.2(e), 10.1-10.8 | Gumroad is the seller's "non-exclusive reseller" and "merchant of record for the resale"; "Gumroad will be treated as the seller of your Products for purposes of any relevant Indirect Tax" and "responsible for the administration, collection, reporting and remittance." "Indirect Tax" includes sales, use, VAT, GST. Sec. 10.6: "It is your personal responsibility to disclose your earnings to your relevant tax authority." Sec. 10.8: Gumroad may deduct Indirect Tax from payouts. Header: "Effective Date: January 1, 2025 / Last Updated Date: September 14, 2026"; existing accounts bound by the Sept 2026 changes on **Oct 14, 2026**. | https://gumroad.com/terms |
| Help: Indirect taxes via Discover | Older page: Gumroad collects as "Marketplace Facilitator" in listed jurisdictions (WI, WA, NC, NJ, OH, PA, Canada). **Stale relative to the MoR model**; MA is not listed. Do not read it as "Gumroad does not collect in MA". | https://help.gumroad.com/article/325-indirect-taxes-on-sales-via-discover (redirects to gumroad.com/help for non-browser clients; text read via https://gumroad.com/help/article/325-indirect-taxes-on-sales-via-discover) |

**Did it change in 2025?** Yes. The Terms carry an effective date of Jan 1, 2025 and create the reseller/MoR structure (sec. 6). Third-party summaries (secondary) date the switch to Jan 2025, e.g. https://gumkit.app/blog/gumroad-sales-tax-vat/ and https://legalclarity.org/how-does-gumroad-handle-sales-tax-for-sellers/. Before 2025, Gumroad collected only as a marketplace facilitator where state law required it (the Discover page above reflects that era). I could not retrieve Gumroad's original 2025 announcement email/post; **[UNVERIFIED]** exact announcement date and wording.

**Caveats for this product:**
- Help page 325 and the "Discover" language show the older facilitator model is still published; the Terms and page 121 control. If Gumroad's position ever differs by state, the Terms (sec. 10.2) say it collects "if Gumroad determines it is responsible"; that is Gumroad's determination, not a legal guarantee for MA. **[UNVERIFIED]** whether Gumroad is registered and collecting in MA. Nothing in the Help Center names MA.
- Sec. 10.8/6.2: you do not invoice buyers yourself ("you shall not issue any invoice or make any demand for payment to any Buyer").
- Seller warranties (Terms sec. 6, clause (d); sub-number not captured): you warrant Digital Products are "provided and licensed in compliance with all applicable laws." That puts export/sanctions on you contractually.
- Gumroad pays out only to supported countries; US sellers get a 1099-K from Stripe (see 1.3). https://gumroad.com/help/article/15-1099s

### 1.2 Massachusetts sales/use tax on electronically delivered prewritten software

**Statute: M.G.L. c. 64H** (https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter64H, section texts fetched 2026-10-01)

| Provision | What it says (paraphrase, with section) | URL |
|---|---|---|
| sec. 2 | Excise at **6.25%** of gross receipts from retail sales of tangible personal property and listed services. | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter64H/Section2 |
| sec. 1 "tangible personal property" | "A transfer of standardized computer software, including but not limited to electronic, telephonic or similar transfer, shall also be considered a transfer of tangible personal property." (This is the hook for taxing downloads.) | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter64H/Section1 |
| sec. 1 "engaged in business in the commonwealth" | Includes soliciting sales via "computer networks... Internet website, software or cookies... or a downloaded application", and "virtual or economic contacts"; "business location" includes owning or leasing real property or having employees in MA. | same |
| sec. 1 "marketplace facilitator" / "retailer" | A marketplace facilitator is a person who, for consideration, facilitates a seller's sales through its marketplace and does listed activities (e.g. payment processing plus setting prices, listing, order taking, customer service); a person who "merely provides payment processing services" is excluded. "Retailer" expressly includes "every marketplace facilitator engaged in facilitating retail sales of tangible personal property or services." | same |

**Regulations (MA DOR, 830 CMR)** (mass.gov returned 403 to automated fetch; text read from Cornell LII mirror, current to LII's copy; confirm on mass.gov)

| Reg | Content | URL |
|---|---|---|
| 830 CMR 64H.1.3 (Computer Software, Hardware, Services) | Defines "prewritten computer software" (includes canned software; software designed to a specific purchaser's specs but sold to others; "delivered electronically" = other than tangible media) and "custom software". "Taxable transfers of prewritten software include sales effected in any of the following ways regardless of the method of delivery, including electronic delivery or load and leave: licenses and leases, transfers of rights to use software installed on a remote server, upgrades, and license upgrades. The vendor collects sales tax from the purchaser." Use tax applies to purchases for use in MA regardless of delivery. | https://www.law.cornell.edu/regulations/massachusetts/830-CMR-64H-1-3 |
| 830 CMR 64H.1.9 (Remote Retailers and Marketplace Facilitators), effective **Oct 1, 2019** | Remote retailers (including marketplace facilitators) must register/collect once they exceed **$100,000** in MA sales (no transaction-count prong). In-state marketplace facilitators collect on own sales regardless of amount and on facilitated sales over $100,000. A marketplace seller that "accepts... in good faith a Form ST-16 collection certificate from an unrelated marketplace facilitator is not required to collect or remit tax with respect to the sales facilitated" (64H.1.9(5)(b)3). Exception: ST-16 from a **related** facilitator leaves the seller liable if the facilitator fails to collect. Liability relief for facilitators who rely on erroneous seller-provided classification (64H.1.9(8)); a seller who gives wrong information can be liable instead. | https://www.law.cornell.edu/regulations/massachusetts/830-CMR-64H-1-9 |

Note: the task prompt cited "830 CMR 64H.25.1"; the marketplace-facilitator regulation I found is **64H.1.9**. I did not locate a 64H.25.1 on this topic (**[UNVERIFIED]** that it exists/applies). The DOR FAQ (https://www.mass.gov/info-details/remote-seller-and-marketplace-facilitator-faqs) was blocked (HTTP 403), so search-snippet summaries of it are secondary. **Not checked: any 2025-2026 amendment to c.64H or the regs on software/marketplaces. [UNVERIFIED]** I found no indication of one; confirm with DOR/counsel. Letter ruling 12-8 (cloud computing, https://www.mass.gov/letter-ruling/letter-ruling-12-8-cloud-computing) exists in this area but was not read.

**Applicability to Humanity:**
- A Humanity license key unlocking a downloaded macOS app is prewritten software delivered electronically: the sale of the right to use it is within c.64H sec. 1 and 830 CMR 64H.1.3. (The DMG being free does not change that the paid license is the taxable transfer. Whether "pay what you want" $5+ affects the base: tax is on the retail price paid; **[UNVERIFIED]** no DOR guidance on PWYW found.)
- Who is the "retailer"? Under Gumroad's Terms, Gumroad resells (sec. 6.1) and is the seller/MoR, so Gumroad is the vendor of the retail sale and you sell to Gumroad for resale (Gumroad supplies a resale certificate; it is a CA certificate, **[UNVERIFIED]** whether MA accepts it as the MA resale documentation, MA uses Form ST-4 for resale). Even under the alternative "marketplace facilitator" characterization, Gumroad would be the retailer collecting. Either way, the seller's own collection duty on Gumroad sales appears to be displaced **if** Gumroad actually collects MA tax, but that is Gumroad's undertaking, not something the seller can verify from public pages.
- You are an in-state person with a "business location" if you operate from owned/leased MA premises or have MA employees; a home office may or may not count (**[UNVERIFIED]**, read the c.64H sec. 1 definition with an advisor). For any **direct sale** (outside Gumroad: gifted/comped keys that are really sales, invoice sales, a future second storefront, Apple App Store sales through Apple is a separate model) you would be the vendor, with a registration and collection duty regardless of amount for in-state vendors. Apple's own sales are collected by Apple as facilitator.
- Free keys given away (reviewers, press) are generally not retail sales (no consideration). Use-tax questions arise only if you buy software for use in MA.

### 1.3 Federal income tax, self-employment tax, Form 1099-K (as of 2026-10-01)

**Federal income tax.** Net profit from selling software as an individual with no entity is business income on Schedule C (sole proprietorship). Gross receipts count even if no 1099-K is issued. I did not fetch the Schedule C instructions; this is general law (**[UNVERIFIED]** by citation here). Verify: https://www.irs.gov/forms-pubs/about-schedule-c-form-1040.

**Self-employment tax.** IRS Topic 554: sole proprietors "usually must pay self-employment tax if you had net earnings from self-employment of $400 or more"; taxable base is **92.35%** of net earnings; rate **15.3%** (12.4% Social Security + 2.9% Medicare), half deductible. https://www.irs.gov/taxtopics/tc554 and https://www.irs.gov/businesses/small-businesses-self-employed/self-employment-tax-social-security-and-medicare-taxes. Social Security wage base for 2026: **$184,500** (SSA): https://www.ssa.gov/oact/cola/cbb.html. (IRS page I fetched still showed the 2024 figure, $168,600; use SSA for 2026.) Additional Medicare tax threshold and the QBI deduction (IRC sec. 199A) are out of scope but relevant at higher profit (**[UNVERIFIED]** this session).

**Estimated taxes.** Individuals with business income generally make quarterly estimates (Form 1040-ES); this is the main practical risk for a first-year seller. **[UNVERIFIED]** by primary citation here; see https://www.irs.gov/businesses/small-businesses-self-employed/estimated-taxes.

**Software development costs (2025 change worth asking a CPA about).** The One Big Beautiful Bill Act (Pub. L. 119-21, July 4, 2025) added IRC **sec. 174A**, restoring immediate expensing of domestic research/experimental costs, which include software development, for tax years beginning after Dec 31, 2024, with election options and transition relief (Rev. Proc. 2025-28; small-business catch-up window noted as closing July 6, 2026). Source: secondary only (PwC, https://www.pwc.com/us/en/services/tax/library/optionality-restored-to-tax-treatment-of-us-research-activities.html; Baker Newman Noyes, https://www.bnncpa.com/resources/one-big-beautiful-bill-act-section-174-research-costs-overhauled/). **[UNVERIFIED] against statute/IRS text.** Relevance: a sole proprietor developing Humanity in 2025-2026 may be able to deduct development costs currently; the deadline for some elections has already passed (July 6, 2026), so ask a CPA now.

**Form 1099-K threshold (verified).**
- IRC sec. 6050W(e) now reads: a third party settlement organization must report only if "(1) the amount... exceeds $20,000, and (2) the aggregate number of such transactions exceeds 200." Amended by Pub. L. 119-21, sec. 70432 (July 4, 2025), 139 Stat. 243. Source: https://www.law.cornell.edu/uscode/text/26/6050W
- IRS: the OBBB "retroactively reinstated the reporting threshold in effect prior to... ARPA... $20,000 and... 200" (IR-2025-107, Oct 23, 2025; Fact Sheet 2025-08): https://www.irs.gov/newsroom/irs-issues-faqs-on-form-1099-k-threshold-under-the-one-big-beautiful-bill-dollar-limit-reverts-to-20000
- So your instinct is correct: the $600 ARPA threshold never took effect; $20,000/200 applies to 2025 and, absent new legislation (none found), 2026. **[UNVERIFIED]** whether any 2026 legislation changed this.
- Gumroad's page repeats the rule: US-based account, more than $20,000 and more than 200 transactions; Stripe issues the 1099-K; 1099-MISC only for affiliates over $600 (this affiliate figure is probably outdated for payments made after Dec 31, 2025, as OBBBA sec. 70433 raised 1099-MISC/NEC to $2,000, **[UNVERIFIED]**; irrelevant unless you are an affiliate). Gumroad: gross amount "includes our fee, sales tax and VAT collected at checkout", PayPal Connect/Stripe Connect sales excluded, year assigned by funds-available date. https://gumroad.com/help/article/15-1099s
- Important practical point: a $5-minimum PWYW product will rarely hit 200 transactions AND $20,000 in early stages, so **expect no 1099-K and still owe tax on all net profit**. Because Gumroad is MoR, the 1099-K gross (which includes tax collected) can exceed what you report as revenue; reconcile with Gumroad's "Tax center" transaction report. **[UNVERIFIED]** whether MoR-model payouts are reported as your gross at all (Gumroad pays you as supplier; ask Gumroad or your CPA how they will report).
- State-level 1099-K thresholds: **[UNVERIFIED]** for MA; not researched.

### 1.4 Massachusetts income tax

- Rate: MA statute c.62 sec. 4 sets Part B income at 5.3% with an annual step-down formula, plus a **4% surtax** on taxable income above a COLA-adjusted $1,000,000 (sec. 4(d), effective 2023): https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter62/section4. The effective rate for recent years is **5.0%** and the surtax threshold was $1,083,150 for 2025; draft 2026 threshold $1,107,750 (secondary: Bloomberg Tax, https://news.bloombergtax.com/payroll/massachusetts-releases-draft-2026-withholding-methods). **[UNVERIFIED]** against DOR (mass.gov blocked). The 4% surtax is irrelevant at this scale.
- Business profit from a sole proprietorship flows from federal Schedule C onto MA Schedule C / Form 1 (TIR 82-1 on Schedule C reconciliation: https://www.mass.gov/technical-information-release/tir-82-1-income-tax-use-of-federal-schedule-c-and-reconciliation-statement-requirement; not read in full).
- MA has **no separate self-employment tax**; the SE tax is federal only.
- Estimated payments: DOR's Form 1-ES says you generally must pay estimates if you expect to owe **more than $400** on income not subject to withholding (secondary; 2026 form PDF, https://www.mass.gov/doc/2026-form-1-es-estimated-tax-payment-vouchers-instructions-and-worksheets/download, returned 403).
- MA does not tax the sale of intangibles to Gumroad buyers elsewhere differently; apportionment is a non-issue for a resident individual (**[UNVERIFIED]**).
- Local: if you operate under a business name, MA cities/towns require a business certificate (DBA) under M.G.L. c.110 sec. 5 (**[UNVERIFIED]**, not researched; relevant to the "no LLC yet" status).

### 1.5 Tax to-dos

1. **Ask Gumroad in writing** (support@gumroad.com or their legal contact) to confirm: (a) it is registered and collecting MA sales tax on software license sales to MA buyers; (b) whether it will give you an MA Form ST-16 collection certificate (64H.1.9(5)(b)) or confirm the MA resale treatment; (c) how your payouts will be reported on 1099-K. Save the reply with your tax records.
2. Do **not** register for MA sales tax or add tax lines yourself while Gumroad is MoR; double-collecting is a problem. Register only if you start selling outside Gumroad (direct invoices, other storefronts that are not MoR).
3. Track gross receipts, Gumroad fees, refunds, and tax withheld per payout from day one. Export monthly "Sales" and "Payouts" CSVs.
4. Open a separate business bank account (a sole proprietor can; not required by law but it makes Schedule C reconcilable).
5. Calendar quarterly estimates: federal 1040-ES (Apr 15, Jun 15, Sep 15, Jan 15) and MA 1-ES. Set aside roughly 25-30% of net profit until your CPA gives a number. **[UNVERIFIED]** dates; confirm each year.
6. Ask a CPA about sec. 174A treatment of the 2025-2026 development costs (some election windows have closed) and home-office, equipment, and software deductions.
7. Update the Terms/EULA and Gumroad product page: prices are "plus applicable tax collected by Gumroad". Do not state "price includes tax" (Gumroad Terms sec. 10.7 says prices are exclusive of Indirect Tax).
8. Re-check the $20,000/200 rule each January and the Gumroad Terms on **Oct 14, 2026** (new Sept 2026 changes bind existing accounts that day). I did not diff the Sept 14, 2026 changes against the prior version; **[UNVERIFIED]** which sections changed.
9. When revenue is meaningful, consider an LLC or S-corp election and a registered business name; this changes SE tax, sales tax registration, and also affects "Humanity contributors" ownership (see the OSS audit).

### 1.6 Tax: attorney/CPA flags
- Whether any MA sales-tax registration is required for a home-based individual who is the supplier to Gumroad (resale) and never sells directly.
- The Gumroad reseller certificate is CA-form; MA acceptance.
- Current MA DOR position on software marketplaces and on PWYW pricing.
- Section 174A elections for 2025-2026 and the July 6, 2026 relief that has passed.
- International: Gumroad handles VAT/GST as MoR, but you remain responsible for income tax in the US; if you ever relocate abroad or hire foreign contractors, new rules apply.

---

## 2. Export controls (EAR)

### 2.1 Facts about the product (from the repo, read 2026-10-01)
- No custom or third-party crypto libraries. `grep` of all source found no CryptoKit/CommonCrypto/OpenSSL/libsodium/AES/ChaCha. The only crypto-related code is Apple's `Security` framework Keychain calls (SecItemAdd/Copy/Update/Delete in `AIKit/Sources/AIKit/KeychainStore.swift`) and `URLSession` over HTTPS (LicenseKit to `https://api.gumroad.com/v2/licenses/verify`; AIKit to OpenAI/Anthropic/Gemini/Groq; local Ollama over plain HTTP). `AIKit/README.md`: "no dependencies beyond the SDK (URLSession, Security, NaturalLanguage)". `SECURITY.md` says requests use HTTPS except local Ollama.
- Third-party code: FluidAudio (Apache-2.0), Rust crates (rustfst, flate2, etc.), CC-BY-4.0 models from Hugging Face; the OSS audit (legal/OPEN-SOURCE-AUDIT.md) found no crypto library linked beyond Apple system libraries (`otool -L` shows only Apple libs). **[UNVERIFIED]** that FluidAudio/Rust crates contain no cryptographic code (flate2/miniz is compression, not encryption; a hashing/crypto crate would need to be searched for in `Cargo.lock`).
- Distribution: free DMGs on GitHub Releases (`dist/*.dmg`); source on GitHub under MIT; apps need a paid Gumroad key; Gumroad license check is the only network call to the seller side. Not on the Mac App Store, not notarized.

### 2.2 Classification analysis (EAR, 15 CFR parts 730-774; eCFR text fetched 2026-10-01)

**Step 1: is the software even controlled for encryption?** ECCN 5D002 covers "software" tied to 5A002 items. Under 5A002.a, an item is covered if "designed or modified to use 'cryptography for data confidentiality' having a 'described security algorithm'" (symmetric > 56 bits; RSA/DH > 512 bits; ECC > 112 bits, last figure UNVERIFIED), where the capability is usable, in categories a.1 (information security is the primary function), a.2 (digital communication or networking), a.3 (computers/items whose primary function is information storage or processing), or a.4 (other items where the crypto "supports a non-primary function" and is performed by incorporated equipment/software that would itself be controlled as a standalone item). TLS to Gumroad/AI providers uses AES-GCM/ECDHE well above these lengths, so the "algorithm" prong is met; classification turns on the "primary function" categories.
Source: Supplement No. 1 to Part 774, ECCN 5A002 (https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-774/appendix-Supplement%20No.%201%20to%20Part%20774; text pulled via the eCFR versioner API).

BIS's own examples under 5A002 Related Control (4) are the closest analogy: an exercise bike whose only controlled crypto is performed by an embedded Note-3-eligible web browser is "not controlled by ECCN 5D002 because it is excluded by the Cryptography Note... (See ECCN 5D992.c)": secure browsing supports a non-primary function of the item. By analogy, Humanity (eye/hand tracking, dictation) has non-information-security primary functions, and its only crypto is OS-provided TLS and Keychain. **My reading (not a determination):** the apps are most plausibly **not** within 5A002.a/5D002 at all, which would make them **EAR99** (subject to the EAR, not listed on the CCL). The weaker alternative reading: BIS FAQ guidance says products that "call" crypto from the OS can still be "designed to use" it (secondary summary of BIS Encryption FAQs, https://www.bis.gov/media/documents/encryption-faqs); under that reading the app is 5D002 but released by the mass-market Cryptography Note (Note 3 to Cat. 5 Pt. 2) to **5D992.c**.

**Step 2: if treated as encryption, does it meet Note 3 "mass market"?** Note 3 requires: (a)(1) generally available to the public by sale without restriction from retail selling points including **electronic transactions**; (2) crypto functionality cannot be easily changed by the user; (3) designed for installation by the user without substantial supplier support; (4) details provided to authorities on request. "Potential interest to a wide range of individuals and businesses" and "price and main functionality available before purchase" also required. A Gumroad-sold, $5+ consumer app plausibly meets this. N.B. to Note 3: key lengths above 64-bit symmetric / 768-bit asymmetric / 128-bit ECC trigger a "classification request or self-classification report" under 740.17(b) **for the items that require one**; see 2.3.
Source: same Supplement (Cryptography Note) and 15 CFR 740.17: https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-740/section-740.17

**Step 3: reporting.** As amended by the 2021 BIS rule (86 FR 16482, Mar. 29, 2021; amendments listed at the foot of 742.15 and 740.17), 740.17(e)(3) self-classification reports are required only for (i) "mass market" encryption **components and 'executable software'** (software in executable form *from an existing hardware component* excluded by the Cryptography Note; it excludes complete binary images) and (ii) non-mass-market items remaining 5A002/5B002/5D002 after self-classification. 740.17(a) separately lists transactions that need no classification request or report. A standalone consumer app is not "executable software" in that defined sense, so the annual **February 1** self-classification report in 740.17(e)(3)(i) appears **not** to apply to a mass-market app. I could not confirm this against BIS written guidance beyond the secondary summaries (https://www.sidley.com/en/insights/newsupdates/2021/04/bis-loosens-controls-on-less-sensitive-mass-market-encryption-items; https://www.bis.gov/learn-support/encryption-controls/mass-market); **[UNVERIFIED]** treat as a counsel confirmation item.

### 2.3 Publicly available exclusion (source code and published software)

| Rule | Text (eCFR, 2026-10-01) | Effect here |
|---|---|---|
| 15 CFR 734.3(b)(3)(i) | "Information and 'software' that: (i) Are published, as described in sec. 734.7" are not subject to the EAR. | Unclassified software published without restriction is outside the EAR. |
| 15 CFR 734.7(a)(4) | Published = "made available to the public without restrictions upon its further dissemination," including "posting on the Internet on sites available to the public." | MIT-licensed source on a public GitHub repo qualifies. |
| 15 CFR 734.7(b) | "Published encryption software classified under ECCN 5D002 remains subject to the EAR unless it is publicly available encryption object code software classified under ECCN 5D002 and the corresponding source code meets the criteria specified in sec. 742.15(b)." | Matters only if the code were 5D002. |
| 15 CFR 742.15(b)(1) | "Subject to the notification requirements of paragraph (b)(2)... publicly available (see sec. 734.3(b)(3)) encryption source code classified under ECCN 5D002 is not subject to the EAR." Applies even with a fee/royalty for commercial products built from it. | 5D002 source posted publicly is outside the EAR. |
| 15 CFR 742.15(b)(2) | Email notice to BIS (crypt@bis.doc.gov) and NSA (enc@nsa.gov) with the URL is required **only** for "non-standard cryptography" (defined in part 772). Notify again if the location changes or crypto functionality changes. | **Not triggered**: no custom/non-standard crypto found in the repo. |

Sources: https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-734/section-734.3, .../section-734.7, .../part-742/section-742.15.

**Applying it:**
- The **source code** (EAR99 or, at most, 5D002 standard crypto) is published and outside the EAR; no BIS email notification is needed under 742.15(b)(2) unless non-standard cryptography is added. Re-check this if you ever add a custom cipher, encrypted-at-rest feature (e.g., encrypting voice profiles or recordings with your own scheme, a likely future feature), or a crypto library. **Encrypting the voiceprint/eye-image store with Apple CryptoKit would still be "standard" crypto but would shift the primary-function analysis; re-run this review before shipping it.**
- The **DMG binaries** are free to download from GitHub, but the product is a paid license. Whether the binary itself is "published" (no restriction on further dissemination vs. paid-use restriction) is arguable. The safest framing is that the DMG is publicly downloadable without restriction on redistribution (the MIT license permits redistribution) **[UNVERIFIED]** that the EULA draft (legal/EULA-DRAFT.md) does not restrict redistribution of the binary; if it does, do not rely on 734.7 for the binary.
- Published status does **not** displace OFAC (see 3).

### 2.4 Why EAR99 vs 5D992.c matters: Russia/Belarus (and embargoed destinations)
- Under 15 CFR 746.8(a)(1) a license is required to Russia/Belarus for items on the CCL (which includes 5D992.c), with a narrow exclusion in 746.8(b)(ii) for 5D992.c items "classified in accordance with sec. 740.17" going only to listed civil end-users (U.S. subsidiaries, certain JVs). EAR99 software is outside 746.8(a)(1) unless it falls in 746.8(a)(8)'s list (ERP, CRM, BI, SCM, EDW, CMMS, PM/PLM, BIM, CAD, CAM, ETO, CNC software); eye-tracking, gesture, dictation apps are not on that list. So **an EAR99 determination would mean no EAR license for consumer sales to Russia/Belarus; a 5D992.c determination would mean a license is required to Russia/Belarus** (apart from OFAC/other limits). Source: https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-746/section-746.8. **[UNVERIFIED]** I read 746.8(a)(1) only via the preamble; verify the full text and any 2026 changes with counsel.
- For comprehensively embargoed destinations (Iran, Cuba, North Korea, Syria's E:1 status noted below), EAR and OFAC overlap; OFAC authority usually controls (734.3(b)(1)(ii) says items "exclusively controlled" by OFAC are not subject to the EAR).
- **Syria changed in 2025**: OFAC removed the Syrian Sanctions Regulations from the CFR (Aug 26, 2025) after E.O. 14312 (June 30, 2025), and BIS (final rule effective Sept 2, 2025) added License Exception SPP for EAR99 items to Syria; Syria remains in Country Group E:1 for other purposes. Sources: https://www.federalregister.gov/documents/2025/08/26/2025-16324/syrian-sanctions-regulations ; https://www.federalregister.gov/documents/2025/09/02/2025-16724/relaxing-export-controls-for-syria . Gumroad's own checkout block list (below) omits Syria, consistent with this.
- Part 744 end-user/end-use controls (Entity List, military end use, etc.) apply to EAR99 too; a seller who learns a buyer is a listed entity must not ship. Gumroad does not tell you in advance (**[UNVERIFIED]** what buyer data you get).

### 2.5 Registration / self-classification report: do you need either?
- **No "registration" regime exists** for encryption exports analogous to FDA; what exists is: (1) classification request (740.17(b)(2)), (2) self-classification report (740.17(e)(3)), (3) semiannual sales report (740.17(e)(1)) for 740.17(b)(2)/(b)(3)(iii) items, (4) 742.15(b)(2) email notice for non-standard crypto in public source.
- On my reading, **none applies** to Humanity as it exists today: EAR99 needs no BIS filing; mass-market 5D992.c standalone software appears excluded from (e)(3) as discussed. **Recordkeeping** (15 CFR part 762, 5 years) applies to any export regardless.
- Apple's guidance for App Store apps (not applicable to your DMG distribution but a useful parallel): apps with encryption "limited to the standard Operating System implementations of protocols like HTTPS" are exempt from the Info.plist export documentation; set `ITSAppUsesNonExemptEncryption` accordingly. https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations (read via summarizer; **[UNVERIFIED]** exact quotes). If you ever submit to the Mac App Store, that key is required.
- **France/other countries**: some countries (e.g., France) have import/use declaration regimes for encryption products; irrelevant until you actively market there; **[UNVERIFIED]**, not researched.

### 2.6 Export-control to-dos
1. Write a one-page **self-classification memo** now (date it, keep it 5 years): list every crypto use (TLS via URLSession, Keychain via Security, any hashing), state that no cryptographic code is implemented by Humanity, state primary function(s), conclude EAR99 (preferred reading) with the 5D992.c / Note 3 fallback analysis. Have counsel or BIS confirm if any Russia/Belarus or high-value sales are expected.
2. If you want certainty, submit a BIS classification request through SNAP-R (CCATS) for the app: the result can be cited later. **[UNVERIFIED]** current SNAP-R process; see https://www.bis.gov/learn-support/encryption-controls.
3. Add an **export/sanctions clause** to the Terms of Sale/EULA (mirror Gumroad's sec. 27.13: not located in an embargoed country, not on a restricted-party list, no prohibited end uses) and a line in README near "Download".
4. Add a **CI/release checklist item**: grep for `CryptoKit|CommonCrypto|SecKey|CCCrypt|OpenSSL|libsodium` and review `Cargo.lock`/`Package.resolved` before each release; if found, redo this analysis. Specifically gate any "encrypt the voice-profile store" work.
5. Do **not** email BIS/NSA under 742.15(b)(2) unless you add non-standard cryptography.
6. Keep the source-code repo public and unrestricted if you intend to rely on 734.7; do not add a login or restricted-access gate.

### 2.7 Export controls: attorney flags
- EAR99 vs 5D992.c determination, especially for the "BIS says calling OS crypto can still be 'designed to use'" point and the mass-market N.B. to Note 3.
- Whether 740.17(e)(3) reporting truly excludes standalone mass-market apps.
- Status of the binary as "published" given the paid-license model.
- Russia/Belarus license exposure if 5D992.c.
- Treat voiceprints/eye imagery: not an export-control issue per se, but "biometric" end-use controls under Part 744 and the Entity List could matter if you ever sell to government end users; **[UNVERIFIED]**.

---

## 3. OFAC sanctions

### 3.1 What Gumroad blocks (primary: Gumroad Help, fetched 2026-10-01)
- Gumroad "Why did my payment fail?": "Not available in your location... the location on the purchase is a jurisdiction under comprehensive United States sanctions. At the moment that means Cuba, Iran and North Korea, along with the Crimea, Sevastopol, Donetsk and Luhansk regions of Ukraine." It checks the **country and state entered** and the **IP/connection location** on new purchases; membership renewals checked against saved billing address; blocked renewals cancel/pause within five days. It says VPN circumvention does not make a purchase permitted. https://gumroad.com/help/article/203-why-did-my-payment-fail
- Terms sec. 4.2: Gumroad may request identity information "to... reduce the risk of... the violation of trade sanctions." Terms sec. 27.13 (Export Control): users "may not use, export, import, or transfer the Services except as authorized by U.S. law"; may not be exported "into any United States embargoed countries" or "to anyone on the U.S. Treasury Department's list of Specially Designated Nationals or the U.S. Department of Commerce's Denied Person's List or Entity List"; users **represent and warrant** they are not located in an embargoed country or on any U.S. restricted-party list. https://gumroad.com/terms
- Not stated in anything I could read: whether Gumroad screens buyer **names/emails** against the SDN list (a US business generally screens, but I found no Gumroad statement; **[UNVERIFIED]**), whether it blocks other jurisdictions or Russia (it does not list Russia), and what Gumroad does about sanctioned **sellers** (payout countries listed at https://gumroad.com/help/article/13-getting-paid exclude Cuba/Iran/N. Korea).
- Syria is no longer on Gumroad's list; consistent with OFAC's removal of the Syrian Sanctions Regulations (Aug 26, 2025) per the Federal Register link in 2.4. Persons remain on the SDN list under other authorities.

### 3.2 Seller's residual duties
OFAC rules apply to **US persons** (you), "wherever located," and are enforced on **strict liability**; being a seller on a platform does not move you out of them. Key authorities (eCFR, fetched 2026-10-01):
- Iran: 31 CFR 560.204 prohibits "exportation, reexportation, sale, or supply, directly or indirectly, from the United States, or by a United States person... of any goods, technology, or services to Iran." https://www.ecfr.gov/current/title-31/subtitle-B/chapter-V/part-560/subpart-B/section-560.204
- Iran general license 560.540 authorizes software "incident to... the exchange of communications over the internet" if EAR99, published under 734.3(b)(3), or 5D992.c. Humanity's functions (eye tracking, gesture control, dictation, meeting transcription) are not obviously "communications software"; do not assume 560.540 covers it. https://www.ecfr.gov/current/title-31/subtitle-B/chapter-V/part-560/subpart-E/section-560.540 (Note how the EAR classification feeds directly into this general license: another reason for the self-classification memo.)
- Informational-materials exemption 560.210(c) is limited and not clearly applicable to functional software; do not rely on it without counsel. https://www.ecfr.gov/current/title-31/subtitle-B/chapter-V/part-560/subpart-B/section-560.210
- Cuba (31 CFR part 515), North Korea (part 510), and the Crimea/DNR/LNR regimes (Ukraine-/Russia-Related Sanctions Regulations, 31 CFR part 589) have analogous prohibitions; I did not read their software general licenses **[UNVERIFIED]**.
- Russia: OFAC's June 2024 determination (effective Sept 12, 2024) prohibits IT consultancy/design and IT support or cloud services for enterprise-management and design/manufacturing software to persons in Russia. Humanity is outside those categories as described; no comprehensive embargo on Russia. Source: Federal Register determination https://www.federalregister.gov/documents/2024/07/18/2024-15709/publication-of-russian-harmful-foreign-activities-sanctions-regulations-determination ; OFAC FAQs 1184-1188 (https://ofac.treasury.gov/faqs/1186). SDN designations of Russian persons are separate and fully apply.
- Record retention: 31 CFR 501.601: records of each transaction "available for examination for at least **10 years**" (extended from 5 years by the Sept 13, 2024 rule, 89 FR 74834). https://www.ecfr.gov/current/title-31/subtitle-B/chapter-V/part-501/subpart-C/section-501.601

**Where gaps remain for you (exposure map):**

| Channel | Gumroad covers? | Residual risk |
|---|---|---|
| Paid key purchase on Gumroad | Yes: country/state/IP block; checkout. | Non-comprehensive SDN-name matches (unverified), and a buyer outside the blocked regions who relocates/shares keys. |
| **Free DMG** on GitHub Releases | No (not via Gumroad). | Software is available to anyone including sanctioned-country users. Unactivated, it does nothing useful (key needed), but providing software to Iran/Cuba etc. is the regulated activity; GitHub applies its own trade-control restrictions (https://docs.github.com/en/site-policy/other-site-policies/github-and-trade-controls, **[UNVERIFIED]** content). Source code is public under MIT, a separate "published" analysis for EAR, but OFAC is not displaced. |
| Key re-use/transfer after sale | Partly (uses count, "increment_uses_count"). | You do not geolocate activations. **[UNVERIFIED]** whether Gumroad's `licenses/verify` response exposes a country field you could check. |
| Comp/free/refund keys you issue manually | No. | You are the direct counterparty. Screen recipients. |
| Support emails to blocked-location users | No. | Providing support services to sanctioned jurisdictions can be a violation. |
| Payments **to you** | Gumroad/Stripe vet payouts. | If a buyer turns out to be an SDN, blocked-property reporting rules (31 CFR 501.603) may apply; Gumroad would normally handle funds, but you hold the license record. |
| Chargebacks/refunds to sanctioned parties | Gumroad. | Needs OFAC authorization if a blocked person is involved. |

### 3.3 OFAC to-dos
1. **Terms of Sale/EULA**: add a sanctions representation matching Gumroad sec. 27.13 (not in Cuba/Iran/North Korea/Crimea/Donetsk/Luhansk or any other comprehensively sanctioned jurisdiction; not an SDN/blocked person; not owned 50% or more by one); a right to terminate and revoke keys; no resale/export. Note Gumroad's Terms do this for the purchase; yours covers the software license.
2. **README/GitHub release notes**: "The software may not be downloaded or used in, or by residents of, Cuba, Iran, North Korea, or the Crimea, Donetsk, Luhansk regions of Ukraine, or by persons on U.S. restricted-party lists." This does not cure strict liability but evidences diligence.
3. Do not manually issue keys to anyone you have not screened against OFAC's Sanctions List Search (https://sanctionssearch.ofac.treas.gov/). Log date, name, result.
4. Keep Gumroad sales exports, payout reports, any screening log, and support emails for **at least 10 years** (31 CFR 501.601).
5. Add a policy: if you learn a customer is in a sanctioned location (support ticket, email domain, IP in a bug report), stop support, revoke the key via Gumroad (or request refund through Gumroad), and consult counsel before refunding or paying anything.
6. Consider asking Gumroad whether it SDN-screens buyer names and whether the verify API response can include a country code you could check at activation; do not collect more buyer data than needed (conflicts with the no-telemetry/privacy posture in PRIVACY.md; the app currently sends only key + product id to Gumroad).
7. Periodically check OFAC's program list for changes (https://ofac.treasury.gov/sanctions-programs-and-country-information); Syria changed in 2025 and the list moves.

### 3.4 OFAC: attorney flags
- Whether the free DMG on GitHub, as an "unactivated" download, is itself a prohibited export/provision of services to sanctioned jurisdictions, and whether geo-blocking at GitHub/Gumroad level suffices.
- Software general licenses for Cuba, North Korea, and Crimea regimes.
- Whether a voluntary self-disclosure posture is wise if a violation is discovered.
- 31 CFR 501.603 blocked-property reports and 501.604 reject reports triggers for a seller who learns of an SDN customer.

---

## 4. Consolidated to-do list (priority order)

| # | Action | Owner/when |
|---|---|---|
| 1 | Written confirmation from Gumroad on MA sales-tax collection and 1099-K reporting under MoR | Before first sale |
| 2 | Add sanctions/export clause to Terms/EULA and README (2.6 #3, 3.3 #1-2) | Before release |
| 3 | Self-classification memo (EAR99 vs 5D992.c), dated and stored | Before release |
| 4 | Business bank account; bookkeeping for gross/fees/refunds | Day one |
| 5 | Quarterly federal (1040-ES) and MA (1-ES) estimates; CPA consult incl. sec. 174A | Before first quarter-end |
| 6 | Record retention policy: 10 years OFAC; 5 years EAR (part 762); tax records 3+ years | Day one |
| 7 | Release checklist grep for crypto libraries; re-review if encryption added | Every release |
| 8 | Decide on notarization/App Store: if App Store, set `ITSAppUsesNonExemptEncryption` and answer export questions | When chosen |
| 9 | Attorney review of items flagged in sections 1.6, 2.7, 3.4 | Before revenue scales or entity formation |
| 10 | Re-check on Oct 14, 2026 (Gumroad Terms), each Jan 1 (1099-K rule), and on any sales to Russia/Belarus | Calendar |

---

## 5. Sources verified (fetched or read on 2026-10-01 unless noted)

**Gumroad (primary):**
- https://gumroad.com/help/article/121-sales-tax-on-gumroad (read via page JSON; MoR statement)
- https://gumroad.com/help/article/10-dealing-with-vat
- https://gumroad.com/help/article/15-1099s
- https://gumroad.com/help/article/325-indirect-taxes-on-sales-via-discover
- https://gumroad.com/help/article/203-why-did-my-payment-fail (OFAC block list)
- https://gumroad.com/help/article/13-getting-paid; https://gumroad.com/help/article/155-things-you-cant-sell-on-gumroad (no sanctions/export content found)
- https://gumroad.com/terms (Effective Jan 1, 2025; Last Updated Sept 14, 2026)

**Taxes (primary):**
- https://www.law.cornell.edu/uscode/text/26/6050W (sec. 6050W(e), Pub. L. 119-21 sec. 70432)
- https://www.irs.gov/newsroom/irs-issues-faqs-on-form-1099-k-threshold-under-the-one-big-beautiful-bill-dollar-limit-reverts-to-20000 (IR-2025-107, Oct 23, 2025)
- https://www.irs.gov/taxtopics/tc554 ; https://www.irs.gov/businesses/small-businesses-self-employed/self-employment-tax-social-security-and-medicare-taxes
- https://www.ssa.gov/oact/cola/cbb.html ($184,500 2026 base, via search result)
- https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter64H/Section1 ; .../Section2 ; https://malegislature.gov/Laws/GeneralLaws/PartI/TitleIX/Chapter62/section4
- https://www.law.cornell.edu/regulations/massachusetts/830-CMR-64H-1-3 ; https://www.law.cornell.edu/regulations/massachusetts/830-CMR-64H-1-9 (LII mirror; mass.gov blocked)

**Export controls (primary, eCFR versioner data dated 2026-09-29):**
- 15 CFR 734.3, 734.7, 734.18, 740.17, 742.15, 746.8; Supplement No. 1 to Part 774 (Cat. 5 Pt. 2, Note 3, ECCN 5A002) via https://www.ecfr.gov/current/title-15/
- https://www.federalregister.gov/documents/2025/09/02/2025-16724/relaxing-export-controls-for-syria (Syria; search result)

**OFAC (primary):**
- 31 CFR 560.204, 560.210, 560.540, 501.601 via https://www.ecfr.gov/current/title-31/
- https://www.federalregister.gov/documents/2025/08/26/2025-16324/syrian-sanctions-regulations (search result)
- https://www.federalregister.gov/documents/2024/07/18/2024-15709/publication-of-russian-harmful-foreign-activities-sanctions-regulations-determination (search result)

**Secondary / not verified against primary (see [UNVERIFIED] tags):**
- 2026 MA surtax threshold (Bloomberg Tax draft), MA Form 1-ES, sec. 174A (PwC, Baker Newman Noyes), BIS Encryption FAQs, Sidley 2021 encryption alert, Apple export-compliance page, Gumroad MoR announcement date (gumkit.app, legalclarity.org).

**Could not retrieve (HTTP 403/404):** mass.gov regulation and FAQ pages, Justia regulations, IRS Pub 334/Schedule C instructions, USPTO-style state resources. Re-verify these on the official sites.
