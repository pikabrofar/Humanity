# 08 - Protecting the individual developer personally

Research analyst notes, not legal advice. Prepared 2026-10-01. Nothing here means the product or seller is "compliant" or "safe" under any law. Items marked **[UNVERIFIED]** were not confirmed against a primary source in this pass. Attorney-review flags are marked **[ATTY]**.

Facts assumed (from the brief): one Massachusetts individual, no entity, sells Humanity (OculOS, ManOS, Murmur, AIKit, LicenseKit) through Gumroad license keys, pay-what-you-want with a $5 minimum, free DMG, not notarized, US first. Source is MIT-licensed; LICENSE says "Copyright (c) 2026 Humanity contributors" and contains the standard "AS IS" paragraph (checked locally).

---

## 0. Bottom line

1. Today the developer is a **sole proprietor by default**. Every contract, refund claim, privacy claim, or injury/data-loss claim reaches personal assets with no entity in between.
2. A Massachusetts LLC is the standard first layer. It costs **$500 to form and $500 every year** (G.L. c.156C s.12). It does not shield the developer from his or her own torts, and a court can disregard it if it is run sloppily.
3. The LLC only helps if the **Gumroad account, the EULA, the privacy policy, the Apple Developer account, and the bank account are all in the LLC's name**. Otherwise the person remains the contracting party.
4. A written **EULA/Terms with warranty disclaimer, limitation of liability, and use restrictions** for the paid binary matters more than the MIT "AS IS" text, which does not bind buyers of a separate commercial distribution in the same way (see s.6).
5. Insurance (tech E&O + cyber) is the layer that pays for defense costs. It is optional at this revenue level but worth pricing once there is a real customer base or any B2B or accessibility-institution sales.
6. The riskiest facts for personal exposure are not CFAA-type. They are (a) a tool that synthesizes mouse/keyboard input (accidental clicks, data loss), (b) biometric-adjacent data (eye images, voiceprints of non-users) which has its own statutory regimes covered in other files, and (c) recording other people's audio. Section 4 and 5 cover (a); (b) and (c) are only flagged here.

---

## 1. Sole proprietor vs Massachusetts LLC

### 1.1 What the Secretary of the Commonwealth charges

| Item | Amount | Source |
|---|---|---|
| Certificate of organization filing fee | $500 | G.L. c.156C s.12: "The fee for the filing of the certificate of organization ... shall be five hundred dollars." https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXXII/Chapter156C/Section12 (fetched 2026-10-01) |
| Annual report fee | $500 per year | Same section: "The fee for the filing of the annual report ... shall be five hundred dollars." Annual report is required by subsection (c). |
| Online expedite surcharge | about $20 | Secondary sources only (e.g. https://www.mystatellc.com/llc/cost/massachusetts); **[UNVERIFIED]** against the Secretary's fee schedule. The sec.state.ma.us fee page would not load via the fetch tool. |
| Annual report due date | Anniversary of formation (generally) | Secondary sources; **[UNVERIFIED]** primary. Check the statute text of s.12(c) and the Corporations Division site before relying. |
| Consequence of missing annual report | Statute text fetched did not state it | Secondary sources say administrative dissolution can follow; **[UNVERIFIED]**. See c.156C s.70 et seq. on dissolution **[ATTY]**. |

Other costs not covered by a fetched source: registered agent (the LLC may be its own resident agent at a Massachusetts address, which publicizes that address, see s.7), Massachusetts income tax treatment of a single-member LLC (disregarded for federal purposes by default; confirm state treatment with DOR **[UNVERIFIED]**), EIN (free from IRS), and a business bank account.

Break-even note: at $500/year the LLC costs more than the app is likely to earn at hobby volume. For a $5 minimum product, the question is whether the protection is worth the roughly $1,000 in the first year. That is a judgment call, not a legal requirement. The LLC is not required to sell on Gumroad.

### 1.2 What the LLC does

- G.L. c.156C s.22 is the statutory limited-liability provision: members and managers are not personally liable for the LLC's debts, obligations, or liabilities solely by reason of being a member or manager "except as otherwise provided" in the chapter. Text: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXXII/Chapter156C/Section22 (fetched; only the framing language was returned, read the full statute **[ATTY]**).
- It shields against **contract and entity-level debts** (refund chargebacks, vendor contracts, a lawsuit that names only the company).
- It does **not** shield against:
  - the developer's own tortious acts (a person who personally writes negligent code can generally be sued personally alongside the company; general agency/tort principle, no primary source pulled **[ATTY]**);
  - personal guarantees, or personal promises in marketing;
  - taxes with personal responsibility rules;
  - statutory claims that name individuals (e.g. unfair-practice claims, privacy statutes) **[ATTY]**;
  - the developer's IP infringement if personally involved.

### 1.3 Veil-piercing basics (Massachusetts)

Massachusetts courts disregard the entity only in "rare" cases. The SJC's leading statement is Attorney General v. M.C.K., Inc., 432 Mass. 546, 736 N.E.2d 373 (2000). The footnote factors reported in secondary summaries: common ownership; pervasive control; confused intermingling of business and personal assets; thin capitalization; nonobservance of corporate formalities; absence of records; no dividends; insolvency; siphoning; non-functioning officers; use of the entity for transactions of the dominant owner; and use of the form to promote fraud or injustice. Factors are weighed, not counted, and the court looks for improper use. Case page: https://law.justia.com/cases/massachusetts/supreme-court/volumes/432/432mass546.html (the page returned HTTP 403 to the fetch tool; factor list taken from search-engine summary, **[UNVERIFIED]** against the opinion text, read it before relying; also at https://www.courtlistener.com/opinion/6578160/attorney-general-v-mck-inc/).

Whether the same test applies to an LLC (as opposed to a corporation) is generally assumed but not verified here **[ATTY]**.

Practical rules that follow from the factors:

| Do | Don't |
|---|---|
| Separate bank account and card for the LLC | Pay personal expenses from LLC account |
| Sign everything as "Humanity LLC, by [name], Manager" | Sign with your own name only |
| Keep a short written operating agreement and annual file of the report | Let the annual report lapse |
| Capitalize enough to cover foreseeable small claims (or buy insurance) | Zero cash and no insurance |
| Pay yourself by documented distributions/draws | Commingle |

### 1.4 Why contracts and Gumroad belong in the LLC's name

- Gumroad is the **merchant of record** in the current model: secondary sources say Gumroad collects and remits sales tax/VAT as the seller of record (https://www.topbubbleindex.com/blog/gumroad-taxes/ and https://gumkit.app/blog/gumroad-sales-tax-vat/, **[UNVERIFIED]**, read Gumroad's own Terms). The seller still has a contract with Gumroad (Terms of Service) and a license relationship with the buyer.
- If the account is under the individual's name and SSN, then the Gumroad ToS indemnity, any chargeback losses, and the buyer's claims run to the person.
- Putting the **Gumroad account, the EULA licensor, the Apple Developer Program enrollment, the domain, and the support email** in the LLC name makes the LLC the counterparty. Moving an existing Gumroad account to a new legal entity needs support/verification steps **[UNVERIFIED]**; check Gumroad's current process. Customers with existing licenses should receive a notice that the licensor has changed (assignment clause in the EULA).
- Apple Developer enrollment as an "Organization" requires a D-U-N-S number and legal entity status; **[UNVERIFIED]**, check https://developer.apple.com/programs/enroll/. This also changes the public seller name shown in Gatekeeper/notarization prompts to the entity name, which is a privacy benefit.
- Tax: Gumroad payouts and 1099 forms will reference whichever legal name/TIN is on the account (see s.7).

---

## 2. DBA / business certificate (G.L. c.110 s.5)

Statute text (fetched 2026-10-01 from https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter110/Section5): anyone "conducting business in the commonwealth under any title other than the real name of the person conducting the business, whether individually or as a partnership" must file with the clerk of each city or town where an office is situated a certificate stating the full name and **residence** of each person conducting the business, the place (street and number) where and the title under which it is conducted, and pay the fee set by c.262 s.34 cl.(20). Duration of four years and penalty of a monthly fine were reported by the fetch summary (**[UNVERIFIED]** against the full text, read the rest of s.5 and the neighboring sections 5-10 **[ATTY]**).

| Question | Answer |
|---|---|
| Applies to "Humanity" as a trade name for an individual? | Yes if "Humanity" is not the individual's legal name. Selling on Gumroad under "Humanity" from a Massachusetts home is "conducting business" under a different title. |
| Where filed? | City/town clerk, not the Secretary of the Commonwealth. |
| What goes public? | The certificate states the owner's **residence** and business street address. Clerk records are public records. This is a direct privacy cost for a home-based seller (see s.7). |
| Fee | Set per municipality; statutory floor of $1 under c.262 s.34(20) per a secondary source; Boston $65, many towns $20-$65. https://www.boston.gov/departments/city-clerk/how-apply-business-certificate (search result only, **[UNVERIFIED]**). |
| Renewal | Every four years per fetch summary and local-clerk pages; **[UNVERIFIED]** primary. |
| Does an LLC need one? | An LLC doing business under its exact registered name generally does not file a c.110 s.5 certificate; one using a different name does (a fictitious name for the LLC). One secondary source states this: https://saveoffice.io/blog/massachusetts-dba-business-certificate-town-clerk. **[UNVERIFIED]**, confirm with the town clerk **[ATTY]**. |
| Practical effect on banks | Banks usually ask for the stamped certificate to open an account in a trade name. |

Recommendation: if staying a sole proprietor, file the business certificate (it is a legal requirement for a trade name, and the certificate is also what lets the person open a bank account under the name). If forming an LLC, name it so the product brand is the LLC's legal name (e.g. "Humanity Software LLC" with brand "Humanity" requires either a DBA or consistent use; choose which). Check the USPTO and the Secretary's name database for conflicts before filing; "Humanity" is a very common word **[UNVERIFIED]**; trademark clearance is outside this file.

Note the privacy tension: the certificate lists a residence. If an LLC is formed, a registered-agent service or a PO box/virtual office can be the public address (s.7).

---

## 3. Insurance: technology E&O and cyber liability

No prices are quoted here because no primary source was pulled.

### 3.1 What these policies typically cover (general market description, **[UNVERIFIED]**: no carrier policy form was fetched; read actual forms)

| Coverage | Typically responds to | Fit for Humanity |
|---|---|---|
| Technology errors and omissions (tech E&O) | Claims that software or services failed, caused financial loss to the customer, or did not perform as represented; defense costs; settlements/judgments; often claims-made | Core cover for "your software clicked the wrong thing and I lost work" or "dictation sent the wrong text" claims |
| Media/IP liability (often bundled) | Alleged copyright/trademark infringement, defamation in content you publish | Moderately relevant (models, icons, marketing) |
| Cyber liability, first party | Breach response costs, forensics, notification, extortion, business interruption | Limited: developer holds no user data and runs no servers (brief). The relevant incident would be compromise of the developer's own machine, signing keys, Gumroad account, or release pipeline |
| Cyber liability, third party | Privacy/security-failure claims, regulatory defense for privacy investigations (sublimits common) | Could matter if an update were hijacked or a bug exposed local recordings |
| General liability (CGL) | Bodily injury, property damage | Usually excludes software errors and professional services; do not assume CGL covers this |

### 3.2 Common features to check in any quote (**[UNVERIFIED]** market knowledge)

- Claims-made basis and retroactive date; extended reporting period.
- Exclusions for bodily injury (relevant: a hands-free pointer used by people with motor impairment, see s.4), biometric/privacy statutes (many forms exclude BIPA-type claims), wiretap/recording claims (relevant to Murmur Meetings), intentional acts, and contractual liability beyond what you would owe without the contract.
- Whether open-source distribution and "free" downloads are covered products.
- Whether a sole proprietor can be the insured; many policies require a business entity and a minimum revenue/application questions.
- Defense costs inside or outside the limit.
- Prior-acts coverage and the application's statements (a misstatement can void cover).

### 3.3 When to buy

Trigger candidates: first paying customer base beyond friends, any institutional/school/healthcare buyer, enterprise or reseller contract requiring certificates, or when the LLC is formed and the Gumroad account is moved. Broker quotes cost nothing; ask three questions: does it cover (1) a failed-performance claim from a consumer, (2) a privacy-statute claim about biometric data and recordings, (3) accessibility-related injury allegations. Many small-software insurers sell online; named vendors not endorsed here. **[ATTY/broker]**

---

## 4. Product liability and negligence for software that controls mouse and keyboard

### 4.1 Theories a plaintiff could try

| Theory | Basic idea | Obstacles for plaintiff | Comment for Humanity |
|---|---|---|---|
| Breach of contract / express warranty | Marketing promised behavior (e.g., "reliable") | Disclaimers, limitation clauses, no reliance | Marketing copy is a warranty source; keep claims modest |
| Implied warranty of merchantability / fitness (UCC Article 2, G.L. c.106) | Software "goods" if sold as a product; courts split on whether software is goods | Disclaimable if conspicuous (c.106 s.2-316); applicability to software uncertain | Disclaimer is what Section 6 below is for |
| Negligence | Failure to use reasonable care in design/testing, resulting in harm | Duty, causation, **economic loss doctrine** (below) | Greatest personal exposure, since the developer can be a defendant individually even with an LLC |
| Strict product liability | Defective "product" causing physical injury or property damage | Software as a "product" is unsettled; usually needs injury/property damage | Relevant mainly to physical harm (e.g., repetitive strain, a motorized device controlled by input). Low for a pure desktop utility; **[ATTY]** |
| G.L. c.93A (unfair/deceptive practices) | Misrepresentation, statutory remedies including multiple damages and attorney fees | Demand-letter requirements; the s.9 consumer claim is not defeated by an exculpatory clause in the usual way | The most dangerous Massachusetts statute for small sellers; keep privacy and capability statements accurate. Statute URL: https://malegislature.gov/Laws/GeneralLaws/PartI/TitleI/Chapter93A (the s.2 URL I tried returned 404; read s.2, s.9, s.11 **[ATTY]**) |
| Negligent misrepresentation | Incorrect statement relied on | Economic loss usually still allowed here in some contexts **[UNVERIFIED]** | "No telemetry / no data leaves device" claims must be true |

### 4.2 What happens if accidental input causes data loss

Scenarios: ManOS clicks "Delete"/"Empty Trash"/"Send"; a gesture misfires during a drag; Murmur's dictation pastes into the wrong app or presses Return; a stuck modifier key, or a CGEvent loop continues after the app hangs.

- Damages claimed would usually be **purely economic** (lost files, lost time, lost work) or data loss, sometimes with consequential claims (a missed deadline, a deleted client file).
- If the user is a consumer, a **personal injury** or **property damage** link is rare; if the lost data was a business's, it is a commercial loss.
- Likely outcome of a small claim: a refund request of $5-$50; Gumroad chargeback; an angry review. Litigation exposure is more theoretical than practical, but defense costs for a single weak suit can still exceed revenue. This is the case for insurance (s.3) and for the LLC (s.1).
- The developer's best facts are product design: hold-to-confirm gestures, dwell timers, an obvious global kill switch, rate limits, "never auto-confirm destructive dialogs", auto-pause when the hand or face is lost. These help both on negligence (standard of care) and on a c.93A "unfair" argument. Document them.

### 4.3 Economic loss doctrine (Massachusetts)

Massachusetts bars recovery in tort for purely economic loss absent personal injury or property damage. Leading case: FMR Corp. v. Boston Edison Co., 415 Mass. 393, 613 N.E.2d 902 (1993). Text: https://law.justia.com/cases/massachusetts/supreme-court/1993/415-mass-393-3.html (listed in search; the summary I read confirms the rule that "purely economic losses are unrecoverable in tort ... absent personal injury or property damage," but I did not read the full opinion, **[UNVERIFIED]** in detail). Points:

- Helps defendants on negligence and strict-liability counts when the harm is lost time, lost files, or lost revenue.
- Does **not** bar contract, warranty, c.93A, or misrepresentation counts, and exceptions exist (e.g., negligent misrepresentation; whether lost data counts as "property damage" is contested nationally; no Massachusetts authority pulled **[ATTY]**).
- A subsequent federal Massachusetts decision on software/consumer goods may refine it; none verified (searched, not found).

### 4.4 Disclaimers and limitation of liability (what they can and cannot do)

- UCC s.2-719 (as enacted in Massachusetts): consequential damages may be limited or excluded unless unconscionable; limiting consequential damages for **injury to the person** in the case of **consumer goods** is prima facie unconscionable; commercial loss limits are not. A limited remedy that fails of its essential purpose lets the buyer pursue UCC remedies. Source: https://malegislature.gov/laws/generallaws/parti/titlexv/chapter106/article2/section2-719 (search result snippet; page itself not fetched, **[UNVERIFIED]** full text).
- UCC s.2-316: warranty disclaimers must mention merchantability and be conspicuous (for the implied warranty of merchantability) and in writing for fitness: https://malegislature.gov/laws/generallaws/parti/titlexv/chapter106/article2/section2-316 (not read; **[UNVERIFIED]**).
- Whether Article 2 reaches software licensed (not sold) is unsettled **[ATTY]**; draft the disclaimer to work under either view.
- Disclaimers will not reliably stop: claims for gross negligence/willful conduct, c.93A consumer claims based on deception, statutory privacy claims, or physical injury. Massachusetts courts tend to read exculpatory clauses narrowly **[UNVERIFIED]**.
- A cap tied to the amount paid (e.g., the greater of fees paid in 12 months or $X) is the common clause. With a $5 minimum, the cap can be very low, which courts may or may not accept for a consumer; mark **[ATTY]**.
- Click-through assent matters: enforceability needs reasonably conspicuous notice and a manifestation of assent. First-launch EULA acceptance inside the apps (not only on the Gumroad page) is the safer design. First Circuit authority on online assent exists (e.g. Cullinane v. Uber, 893 F.3d 53 (1st Cir. 2018)); **[UNVERIFIED]**, read it before relying.

### 4.5 Product-specific safety text to add

A "Safe use" section in the first-run flow and docs: do not use with unsaved critical work; do not use while operating machinery or in safety-critical settings; this is not a medical device or a certified assistive technology; always keep a physical mouse/keyboard available; know the kill switch. Avoid wording that markets it as a medical or accessibility solution with promises of reliability (FDA/ADA claims are outside this file; see accessibility file 12). **[ATTY]**

---

## 5. CFAA (18 U.S.C. 1030) and state computer-crime laws

### 5.1 Does a mouse/keyboard automation tool fall within the statute?

- 18 U.S.C. 1030(a)(2) bars intentionally accessing a computer "without authorization" or "exceeding authorized access" to obtain information from a protected computer; (a)(5) covers knowingly transmitting code causing damage, and unauthorized access causing damage or loss. A "protected computer" includes any used in or affecting interstate commerce (s.1030(e)(2)(B)), which in practice covers ordinary computers. Civil actions under s.1030(g) require, among other things, loss of at least $5,000 in a one-year period. Criminal penalties range up to 1 to 20 years depending on subsection. Text: https://www.law.cornell.edu/uscode/text/18/1030 (fetched 2026-10-01).
- Humanity runs **on the user's own computer, with the user's permission** (Accessibility permission, camera, mic). On those facts the developer is not "accessing" anyone's computer; the user authorizes the software. This is the strongest structural point.
- **Van Buren v. United States**, 593 U.S. 374 (2021): "exceeds authorized access" covers a person who accesses areas of a computer (files, folders, databases) that are off limits to them, not someone who misuses access they already have for an improper purpose ("gates up or down"). https://www.law.cornell.edu/supremecourt/text/19-783 (fetched; decided June 3, 2021). That narrowed exposure for users running automation on systems they may legitimately use.
- Misuse risk: a user could aim ManOS or an automation feature at a computer or account they have no right to use (a coworker's unlocked machine, a remote desktop) or at a third-party service's terms (bots clicking through websites). Those are the user's acts; the developer's exposure is mainly **civil aiding/inducement theories or a secondary-liability claim** if marketed for that purpose **[ATTY]**. No primary source pulled on contributory CFAA liability.
- Anti-circumvention (DMCA s.1201) and anti-cheat/online-game ToS violations are separate and not covered here. If marketed for games (aim assist, macros), platform bans and ToS disputes follow; **[ATTY]**.
- Whether emitting synthetic CGEvents to bypass a security prompt or password field would be "circumventing" anything: macOS blocks secure-input fields from synthetic events in some contexts **[UNVERIFIED]**; do not market any bypass of OS security prompts. Check Apple's API docs (file 14).

### 5.2 Massachusetts law

- G.L. c.266 s.120F: knowingly accessing a computer system without authorization (or staying after learning access is unauthorized) is punishable by up to 30 days in a house of correction, a fine up to $1,000, or both; requiring a password or other authentication is notice that access is limited. https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter266/Section120F (fetched 2026-10-01 via summary tool; read full text **[ATTY]**).
- Other states (California Penal Code s.502, etc.) have broader, sometimes civil, remedies; none pulled **[UNVERIFIED]**. As international and multi-state sales grow, the user's state law governs the user's conduct, but it matters to a seller's marketing language.

### 5.3 Reduce misuse exposure

| Control | Reason |
|---|---|
| EULA "Acceptable Use": only on devices and accounts you own or are authorized to use; no unauthorized access, no circumvention of security measures, no use to violate others' terms or laws, no covert surveillance or recording of people without lawful consent | Sets the contractual line; supports "no intent" in a secondary-liability case |
| Do not market for bots, game cheating, scraping, "bypass", "undetectable" | Marketing is the evidence a plaintiff uses |
| No remote-control, no network listener, no keylogging beyond dictation | Keeps the tool local and not a remote access trojan; a feature that remote-controls other machines is a different risk class |
| Dictation: no capture of passwords (respect secure input) | Avoids "keylogger" characterization |
| Meetings/voice profiles: consent prompts and a recording-law notice (two-party consent states, e.g. Massachusetts wiretap statute G.L. c.272 s.99) | Recording others is a likely user-misuse path; covered in privacy files, **[ATTY]**; statute not fetched here |
| Takedown/abuse contact and a right to terminate licenses | Lets the developer show he or she did not condone abuse |
| Notarization and hardened runtime when available | Reduces "malware" characterization; unsigned apps that inject input can look like malware |

---

## 6. Open-source "AS IS" disclaimer vs the paid binary

| Point | Analysis |
|---|---|
| What the MIT text does | The LICENSE (checked locally) provides the software "AS IS, WITHOUT WARRANTY OF ANY KIND" and says the authors or copyright holders are not liable for any claim, damages, or other liability. It is a license from the copyright holder to **anyone who gets the source (or a copy with the notice)**. |
| Who is the licensor? | LICENSE names "Humanity contributors," not the developer or an LLC. If contributors exist, the named licensor and copyright holder are unclear; if the LLC later sells, its relationship to the copyright must be documented (contributor license agreement or DCO; assignment of the developer's own copyright to the LLC) **[ATTY]**. |
| Does MIT cover the paid binary? | The binary is built from MIT code, so a binary recipient may also receive MIT rights, but the **sale** adds a separate commercial relationship (Gumroad purchase, license key, support, marketing statements). Contract and warranty claims arise from that relationship, not from the repository. A court is not obliged to read a bare "AS IS" paragraph in a repo as the terms of the Gumroad sale. Treat the MIT disclaimer as a backup, not the primary shield. |
| Conspicuousness | Under UCC s.2-316, disclaimers of the implied warranty of merchantability must mention merchantability and be conspicuous. The MIT text is all-caps and mentions merchantability, which helps if it is the operative document. It is not shown at purchase or in app. |
| Does the MIT license cover keys / DRM? | MIT lets anyone compile and remove license checks. Selling keys is a convenience-and-support model, not a technical control. This is a business consequence, not a liability issue, but it affects what you promise (e.g., do not call keys "license enforcement"). |
| Recommended | Add a separate **EULA/Terms of Sale** for the paid binary and key: licensor = the LLC (or the individual if no LLC); grant; the MIT source license remains for source; warranty disclaimer in conspicuous caps; limitation of liability (cap, exclusion of consequential damages with a carve-out language review); acceptable use (s.5.3); safe-use text (s.4.5); governing law Massachusetts and venue; refund policy consistent with Gumroad's; assignment right; notice of changes; severability. Show it on the Gumroad product page, at first launch with a required checkbox, and in the repo. **[ATTY]** Consumer-protection law overrides some terms (c.93A, UCC unconscionability); international buyers add EU/UK consumer rules (out of scope; later file). |
| Third-party licenses | THIRD_PARTY_NOTICES.md already exists (not audited here). Attribution (CC-BY-4.0 models from Hugging Face) must travel with the binary; failing that is an IP exposure on the person or LLC. |

---

## 7. Privacy of the seller's own name and address

### 7.1 What Gumroad shows (from Gumroad Help Center search results, **[UNVERIFIED]**: the help-center pages redirected or returned empty to the fetch tool, so confirm in your own account)

| Surface | What a search summary of Gumroad help says |
|---|---|
| Customer receipt / customer email | The creator's **support email** appears; if blank, the account email (user details) is used. Source: https://help.gumroad.com/article/67-the-settings-menu and https://help.gumroad.com/article/77-interacting-with-customers (listed in search; not read in full). |
| Address | Gumroad help states customers "will never see your banking information, payout information, or address" (https://help.gumroad.com/article/120-protecting-your-privacy-on-gumroad, listed in search, snippet only). |
| Public profile and product pages | Display name, bio, avatar, and social links the creator chooses (https://gumroad.com/api describes the profile fields exposed via API; it said the API does not expose email, balance, or tax data). |
| Invoices | The customer-facing invoice generator asks for the **customer's** name/address. Whether the seller's name or address appears on an invoice or receipt, and what Gumroad shows for a merchant-of-record sale (receipts often show Gumroad as the seller), must be checked by completing a test purchase and reading the receipt and invoice. **[UNVERIFIED]** |
| License key API | Not seller identity related; see LicenseKit. |

Test action (no cost): buy your own product from a second email, open the receipt, the invoice link, the checkout page, the profile, and any "contact creator" page; record what shows.

### 7.2 Tax forms

- Gumroad reports to the IRS; secondary sources say it issues **Form 1099-K** to US creators who exceed the reporting threshold, which one source gave as $20,000 gross and more than 200 transactions per year: https://www.topbubbleindex.com/blog/gumroad-taxes/ (**[UNVERIFIED]**; also Gumroad's help page at https://help.gumroad.com/article/15-1099s which redirected during fetch). The federal threshold for third-party settlement organizations changed repeatedly in 2021-2025; confirm the current figure on https://www.irs.gov/newsroom/understanding-your-form-1099-k (page not available to the fetch tool, 404 on the URL I tried) **[UNVERIFIED]**.
- The 1099 and Gumroad's account verification require the **legal name, TIN (SSN or EIN), and a mailing address**. These go to Gumroad and the IRS, not to buyers, but they are Gumroad-held personal data. Under an LLC, use the LLC's legal name and EIN, removing the SSN from the account (a single-member LLC can use its own EIN; confirm the account's W-9 fields).
- Gumroad as merchant of record means the creator receives payouts net of tax collected; sales tax handling is covered elsewhere; **[ATTY/CPA]**.
- Income is taxable regardless of whether a 1099 arrives.

### 7.3 Where the personal address leaks even when Gumroad hides it

| Source | Public? | Mitigation |
|---|---|---|
| MA business certificate (c.110 s.5): residence of the proprietor | Public record at town clerk | Use an LLC/trade name only after considering the LLC route; but note the certificate requires a "residence" statement for each person; check whether a business address can be listed separately **[ATTY]** |
| LLC certificate of organization and annual reports (Secretary of the Commonwealth) | Public online business search | Use a commercial registered agent and a business mailing address; the LLC filings list manager and business office addresses. Content requirements are in c.156C s.12(a) (fetched; mentions office address, resident agent, managers); check whether a residential address is mandatory for managers **[UNVERIFIED]** |
| Apple Developer account (seller name in macOS dialogs) | Seller name visible | Organization enrollment shows the LLC |
| WHOIS/domain | Often masked | Use registrar privacy |
| GitHub repo commits | Git author name/email is public | Use a noreply address; the LICENSE currently reads "Humanity contributors," which does not name a person |
| PRIVACY.md / support page | Whatever you publish | Use a role address (support@) |
| PDF invoice/CPA/US sales-tax registration | Not public by default | n/a |
| App privacy policy: GDPR/UK Art. 13 identity and contact of controller | Required identity/contact for EU users later | Out of scope now; use an LLC and registered-agent address **[ATTY]** |

---

## 8. Recommended setup order

| # | Step | Why this order | Cost basis |
|---|---|---|---|
| 1 | Settle the legal name and brand; run a name search in the Secretary's database and a trademark knockout search | Everything else uses it | Free |
| 2 | **Attorney consult (1 hour)** on: LLC vs not, EULA/Terms, ownership of "Humanity contributors" copyright, insurance fit | Resolves the **[ATTY]** items before filing | Not quoted |
| 3 | Form the Massachusetts LLC (certificate of organization; $500 per c.156C s.12); pick a registered agent/business address with privacy in mind; get an EIN; write a short operating agreement | The entity must exist before contracts move | $500 + agent fees if any |
| 4 | Open a business bank account (and card) in the LLC's name | Keeps veil-piercing factors favorable | Bank dependent |
| 5 | If using a brand that differs from the LLC's legal name, file the town business certificate (c.110 s.5) | Legal requirement for a trade name; banks ask for it | Per town fee |
| 6 | Calendar the LLC annual report ($500, c.156C s.12(c)) on the formation anniversary | Prevent lapse; supports good standing | $500/yr |
| 7 | Move or recreate the **Gumroad account** under the LLC name/EIN; update support email to a role address; run a test purchase and record what the receipt and profile show | Makes the LLC the seller and reduces SSN/address exposure | Free |
| 8 | Enroll Apple Developer as an Organization (needs the entity and D-U-N-S) and notarize | Seller name becomes the LLC; reduces malware warnings | Per Apple |
| 9 | Publish the EULA/Terms, Acceptable Use, Safe-use text, and Privacy Policy with the LLC as licensor; add first-launch acceptance; align the Gumroad page and refund policy | The paid-binary shield (s.6) | Attorney drafting |
| 10 | Product safeguards: kill switch, confirmation on destructive actions, input rate limits, auto-release of held keys on hang/exit, and tests for them | Evidence of reasonable care (s.4.2) | Dev time |
| 11 | Get broker quotes for tech E&O/cyber; bind when thresholds in s.3.3 are met | Defense-cost layer | Not quoted |
| 12 | Move repo identity: noreply commit email, copyright line naming the LLC for new work, contributor policy (DCO/CLA) | Clarifies who licenses what | Free |
| 13 | Revisit annually: revenue, claims, any B2B contracts, international launch (EU consumer, GDPR, VAT), state-by-state tax | Triggers new obligations | Time |

If budget is tight, the minimum sensible stack is steps 2, 9, 10 (documents and product safeguards), then add the LLC (steps 3-8) before meaningful revenue or any non-friend customer base. The business certificate (step 5) is required whenever a trade name is used, with or without the LLC.

---

## 9. Attorney-review checklist

1. Whether a single-member Massachusetts LLC plus insurance is proportionate at $5-minimum pricing; alternatives (sole proprietor plus umbrella insurance and strong EULA).
2. Whether individual developers remain personally liable for their own negligent code despite the LLC, and how Massachusetts treats this for software.
3. Whether the c.156C s.12 filing requires a residential address for managers, and registered-agent options.
4. Business certificate: need for a c.110 s.5 filing by an LLC trading under a brand different from its name; residence disclosure.
5. EULA drafting: disclaimer, cap, acceptable use, class waiver/arbitration under Massachusetts law, assent mechanics.
6. Whether Article 2 of the UCC applies to licensed software in Massachusetts (and the unconscionability presumption for consumer personal injury).
7. Contributory/secondary exposure for misuse (unauthorized access, recording, surveillance), including c.272 s.99 and biometric statutes in other files.
8. Chain of title: "Humanity contributors" copyright, assignment to the LLC, MIT relicensing posture.
9. Gumroad contract terms (indemnity, merchant-of-record, account transfer to an entity).
10. Insurance form exclusions (biometric, wiretap, bodily injury).

---

## 10. Sources verified (fetched 2026-10-01 unless noted)

| Source | URL | Status |
|---|---|---|
| G.L. c.156C s.12 (formation and annual report fees $500 each) | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXXII/Chapter156C/Section12 | Fetched, fee language confirmed |
| G.L. c.156C s.22 (member/manager liability) | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXXII/Chapter156C/Section22 | Fetched, summary only |
| G.L. c.156C s.4 (name reservation) | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXXII/Chapter156C/Section4 | Fetched; irrelevant to DBA |
| G.L. c.110 s.5 (business certificate) | https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter110/Section5 | Fetched, text confirmed in part |
| 18 U.S.C. 1030 | https://www.law.cornell.edu/uscode/text/18/1030 | Fetched, summary |
| Van Buren v. United States (2021) | https://www.law.cornell.edu/supremecourt/text/19-783 | Fetched, summary |
| G.L. c.266 s.120F | https://malegislature.gov/Laws/GeneralLaws/PartIV/TitleI/Chapter266/Section120F | Fetched, summary |
| FMR Corp. v. Boston Edison | https://law.justia.com/cases/massachusetts/supreme-court/1993/415-mass-393-3.html | Search result only; holding confirmed by summary |
| Attorney General v. M.C.K. | https://law.justia.com/cases/massachusetts/supreme-court/volumes/432/432mass546.html | 403 on fetch; factors from search summary |
| G.L. c.106 s.2-719 / s.2-316 | https://malegislature.gov/laws/generallaws/parti/titlexv/chapter106/article2/section2-719 | Search snippet only |
| Gumroad help pages | https://help.gumroad.com/article/120-protecting-your-privacy-on-gumroad ; /article/67-the-settings-menu ; /article/15-1099s | Redirected or empty to fetch; snippets only |
| Local files | /Users/taylorpan/Cloud/Humanity/LICENSE | Read |

**Not verified at all:** Secretary of the Commonwealth fee page and online surcharge, annual report due date and dissolution rules, current 1099-K threshold, Apple organization enrollment requirements, MA c.93A section text, MA c.272 s.99, Cullinane v. Uber, insurance forms. No 2025-2026 amendments to c.156C s.12, c.110 s.5, or 18 U.S.C. 1030 were found in this pass, but no legislative-history check was run **[UNVERIFIED]**.
