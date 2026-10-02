# 12. Children and age-related rules (research memo)

Prepared 2026-10-01 by a research analyst, not a lawyer. This is not legal advice and makes no compliance conclusion. Items marked **[UNVERIFIED]** rest on secondary sources or on web-fetch summaries that I could not match to statute text. Several bills moved quickly in 2026, so re-check every status before relying on it.

## 0. Bottom line

| Question | Short answer | Confidence |
|---|---|---|
| Does COPPA apply to Humanity? | Probably not on current facts. The developer is not an "operator": he collects no personal information, and nothing is "directed to children." Gumroad's sale records are Gumroad's own, not the developer's COPPA collection. | Medium-high, but fact-dependent |
| Do the CA AADC or MD Kids Code apply? | Very unlikely. Both are limited to larger "businesses" or "covered entities" under CCPA-style thresholds, and the product is not "reasonably likely to be accessed by children." | Medium-high |
| Do the App Store Accountability Acts (UT, TX, LA, AL) reach an app sold only via Gumroad? | The text is keyed to apps "made available ... through an app store" and to "mobile devices." On a plain reading a Mac app sold via Gumroad is outside them. The open question is whether Gumroad could be argued to be an "app store" (see 3.5). | Medium, with no case law |
| Does California AB 1043 (eff. 2027-01-01) reach Mac apps outside stores? | **This is the one to watch.** The text I could verify has no carve-out for apps obtained outside a "covered application store," and it covers "computer" and "general purpose computing device." The developer duty is to request an age signal from the OS provider. It needs attorney review before 2027-01-01. | Low-medium |
| Is an age gate warranted? | No. Add an age statement to the EULA/Terms and a "not for children" line on the product page. Do not collect birthdates. | Recommendation |

Facts used about the product (from the brief): a single individual in Massachusetts, no entity, sells via Gumroad, and the developer runs no servers and never receives user data except Gumroad's sale records. Apps process webcam images, voice, and voiceprints locally. Voice profiles may be of non-users, who could include children.

## 1. COPPA (15 U.S.C. 6501-6506; 16 CFR Part 312)

### 1.1 Statute and rule

- The statute is at [15 U.S.C. 6501-6506](https://www.law.cornell.edu/uscode/text/15/6501). The Rule is at [16 CFR Part 312](https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312). A Cornell copy is at [16 CFR 312.2](https://www.law.cornell.edu/cfr/text/16/312.2).
- **Trigger** ([312.3](https://www.law.cornell.edu/cfr/text/16/312.3), [312.2](https://www.law.cornell.edu/cfr/text/16/312.2)). An "operator" of a website or online service directed to children under 13, **or** one with actual knowledge that it collects personal information from a child under 13, must give notice and get verifiable parental consent. The same applies to a general-audience operator with actual knowledge.
- **"Operator."** An entity that "operates a website ... or an online service and who collects or maintains personal information from or about the users." For commercial purposes in interstate commerce.
- **"Collects."** Gathering personal information from a child by any means. This includes requesting or prompting a child to submit it and passive tracking.
- **"Personal information"** includes persistent identifiers, a photograph, video or audio file containing a child's image or voice, geolocation, and (since the 2025 amendments) a **biometric identifier** usable for automated or semi-automated recognition. The final rule describes identifiers derived from voice, gait or facial data. The Federal Register summary I read said this; confirm the exact text in 312.2.

### 1.2 The 2025 amendments and compliance dates

| Item | Date or fact | Source |
|---|---|---|
| Final rule published | 2025-04-22 | [Federal Register](https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule), [govinfo](https://www.govinfo.gov/content/pkg/FR-2025-04-22/html/2025-05904.htm) |
| Effective date | 2025-06-23 | same |
| Compliance date | **2026-04-22**, except certain 312.11 (safe harbor) provisions, (d)(1), (d)(4), (g) | same |
| Substance | Separate consent for third-party disclosures; written data retention policy; no indefinite retention; stronger security program; expanded "personal information" (biometrics, government IDs); new "mixed audience" definition | [Latham alert](https://www.lw.com/admin/upload/SiteAttachments/FTC-Publishes-Updates-to-COPPA-Rule.pdf) **[UNVERIFIED]** (secondary) |
| FTC age-verification policy statement | 2026-02-25. It lets operators collect data solely to determine age if they delete it and secure it. | [FTC COPPA page](https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa) (press-release headline only; I did not read the statement) |

All of the above is now in force as of today (2026-10-01).

Federal bills (COPPA 2.0, KOSA/KIDS Act, a federal App Store Accountability Act) are **not enacted** as far as I can tell. Reports conflict: one source says the Senate passed COPPA 2.0 on March 5 and it is stalled in the House. Another says the House passed the KIDS Act on June 29. **[UNVERIFIED]** See [Loeb, June 2026](https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-in-2026-congress-stalls-again-ftc-signals-priorities).

### 1.3 Application to general-audience software that collects nothing at the developer's end

1. **No collection, no COPPA duty.** The FTC FAQ says COPPA "applies only to those websites and online services that collect, use, or disclose personal information from children." The Rule also "does not require operators to ask the age of visitors." Source: [FTC COPPA FAQ](https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions) (from a fetch summary; quotations should be checked on the page).
2. **Local processing is not "collection" by the developer.** Webcam frames, audio and voiceprints stay on the user's Mac. The developer never receives them, and "operator" requires that the entity "collects or maintains" the information. This is my reading of the definition. I found no FTC guidance or case treating on-device-only processing in a downloaded desktop app as non-collection. **[UNVERIFIED as to authority; flag for attorney]**
3. **Is the product "directed to children"?** The factors are subject matter, visual content, characters, music/audio, age of models, language, and so on ([312.2](https://www.law.cornell.edu/cfr/text/16/312.2)). Eye tracking, hand-gesture mouse control, dictation, meeting recording and voiceprints are an adult-productivity and accessibility profile. No factor points to under-13s. Keep marketing free of kid imagery, school-age-child use cases and "for kids" language.
4. **Actual knowledge.** Triggered if the developer learns a child under 13 is using it and he is collecting data from them. Two things bear on this:
   - Gumroad receives buyer name, email and payment data and passes sale records to the developer. If the developer learns from a refund email or a support message that a buyer is 12, that is **knowledge of a child, but the developer still has to "collect personal information from" that child** for COPPA to bite. Email addresses in sale records are "online contact information," so there is a thin argument. Mitigation: do not use buyer emails for anything beyond fulfilment and support, and delete a child's data on request.
   - The license call to Gumroad's API sends key and product id. That is not child data held by the developer.
5. **AIKit (BYO-key cloud transcription).** The user's own key sends transcript text to a third party. The developer is not the recipient. If a child dictated, the AI provider is the operator and the user is the account holder. Provider terms generally require 18+ or 13+ with parental consent **[UNVERIFIED; not checked here]**. Say in the docs that the user is responsible for supplying content.
6. **Third-party platforms.** The FTC FAQ says developers publishing through third-party stores remain liable for third-party data collection and must inquire into every third party's practices. Humanity has no ad or analytics SDKs per the brief; keep it that way.

**Residual risk: voiceprints of non-user children.** Murmur Meetings stores speaker voiceprints locally. If a user records a child (a class, a family call), the data sits only on the user's Mac, and the developer neither collects nor maintains it. It would be a "biometric identifier" of a child if the developer were an operator. Reasoning: no developer access means no operator, but this is a novel fact pattern. **[Attorney-review flag]** A user-facing note ("do not create voice profiles of children without consent of a parent or guardian") is cheap and addresses state biometric laws too (see doc 11 if present).

### 1.4 Gumroad terms (checked 2026-10-01)

Source: [Gumroad Terms of Service](https://gumroad.com/terms) (Last Updated September 14, 2026, per the fetched page; fetch summary only, so quotations should be confirmed on the page).

| Point | What the terms say |
|---|---|
| Minimum age | Section 4.4: "You represent that you are (i) at least thirteen (13) years old" and are "of legal age to form a binding contract." |
| Minors | Account holders must "monitor your Account to restrict use by minors" and accept "full responsibility for any unauthorized use of the Services by minors." |
| Supplier restriction | Suppliers may not "target, or intend to distribute to, children under the age of thirteen (13)." |
| Merchant of record | Gumroad is "merchant of record for the resale of your Products to the Buyers." |

**The "18+ or parental involvement" premise in the request did not match what I found.** The terms I read say 13+ **and** legal age to contract, not a flat 18+ with a parental route. In most US states the age of contract is 18, so the practical effect is similar, but "legal age" is not defined. The terms also bind Gumroad *account holders*; I did not confirm that every buyer must create an account. Possibly a separate buyer-facing policy exists. **[UNVERIFIED]** Practical takeaway: the supplier (developer) is barred from targeting under-13s, which fits the "not directed to children" posture. Avoid wording on the Gumroad page that reads like an invitation to minors.

## 2. State age-appropriate design codes

### 2.1 California AADC (AB 2273; Cal. Civ. Code 1798.99.28 et seq.)

- **Status: still enjoined in part.** *NetChoice v. Bonta*, No. 25-2366 (9th Cir. Mar. 12, 2026), [opinion on Justia](https://law.justia.com/cases/federal/appellate-courts/ca9/25-2366/25-2366-2026-03-12.html). Summaries ([Cooley](https://www.cooley.com/news/insight/2026/2026-03-30-netchoice-v-bonta-ninth-circuit-narrows-injunction-against-californias-ageappropriate-design-code-act), [Holland & Knight](https://www.hklaw.com/en/insights/publications/2026/03/ninth-circuit-issues-mixed-ruling-on-california-age-appropriate-design)):
  - The Ninth Circuit **vacated the injunction as to the coverage definition and the age-estimation provision**, because NetChoice had not met the facial-challenge standard.
  - It **left enjoined** the challenged data-use restrictions and the dark-patterns provision, as likely unconstitutionally vague.
  - The case went back to the N.D. Cal. on age estimation and severability.
  - I did not verify later district-court activity after March 2026. **[UNVERIFIED]** Treat the law as "partly enforceable, partly enjoined, moving."
- **Scope.** Applies to a "business" as defined by CCPA ($25M+ revenue, or data on 100,000+ consumers, or 50%+ revenue from selling/sharing data) that provides an online service "likely to be accessed by children" under 18 (statute text not re-read; thresholds from memory of Cal. Civ. Code 1798.140(d) and the AADC). **[UNVERIFIED]**
- **This product.** A sole proprietor with a small revenue stream and no data collection falls below every CCPA threshold. Not applicable on these facts. Revisit if revenue passes $25M (unlikely) or the developer begins collecting data about 100,000+ consumers (not the architecture).

### 2.2 Maryland Kids Code (Md. Code, Com. Law 14-4801 et seq.; SB 571 / HB 603)

- Effective 2024-10-01. A federal challenge, *NetChoice v. Brown* (D. Md. No. 1:2025-cv-00322), survived a motion to dismiss on 2025-11-24; the statute **remains in effect** and the case is in discovery. Sources: [Goldman blog](https://blog.ericgoldman.org/archives/2025/11/challenge-to-marylands-kid-code-survives-motion-to-dismiss-netchoice-v-brown.htm), [Justia docket doc. 90](https://law.justia.com/cases/federal/district-courts/maryland/mddce/1:2025cv00322/575260/90/). I did not check for a later ruling. **[UNVERIFIED]**
- **Scope.** "Covered entity" = for-profit entity doing business in Maryland that (i) has gross revenue over $25M, or (ii) buys, receives, sells or shares personal data of 50,000+ consumers, households or devices, or (iii) gets 50%+ of revenue from selling personal data. It must offer an online product "reasonably likely to be accessed by children" (under 18). Duties include a data protection impact assessment. Penalties are up to $2,500 per affected child (negligent) and $7,500 (intentional). Source: [Orrick Maryland page](https://onlinesafety.orrick.com/maryland/); statute text not re-read. **[UNVERIFIED]**
- **This product.** Below all three thresholds and not child-oriented. Not applicable on current facts.

Other AADC-style laws exist or were proposed in other states (VT, NE, and so on). I did not research them; none should reach a sub-threshold developer. **[UNVERIFIED]**

## 3. App Store Accountability Acts (and California AB 1043)

### 3.1 Status table (as of 2026-10-01)

| State | Law | Effective / status | Source |
|---|---|---|---|
| Utah | SB 142 (2025), Utah Code Title 13, ch. 75. Amended by **HB 498 (2026)**. | Original dates: app store duties 2026-05-06; developer/enforcement later. HB 498 moved the primary provisions to **2027-05-06**, removed Attorney General enforcement in favor of a **private right of action**, added pre-installed apps, and gave app stores until 2028-05-06 for existing accounts. CCIA's challenge (*CCIA v. Brown*, D. Utah) was voluntarily dismissed 2026-04-21. | [SB 142 text](https://le.utah.gov/Session/2025/bills/introduced/SB0142.pdf) (introduced version only; the enrolled PDF would not parse), [Loeb](https://www.loeb.com/en/insights/passle/2026/05/update-on-utah-app-store-law--another-waiting-game), [CCIA fact sheet](https://ccianet.org/wp-content/uploads/2026/02/CCIA-v.-Brown-Fact-Sheet-Utah-SB142.pdf) |
| Texas | SB 2420, Bus. & Com. Code ch. 121 | Eff. 2026-01-01. PI granted 2025-12-23 (*CCIA v. Paxton*, W.D. Tex.). **Fifth Circuit stayed the injunction (June 2026); the Supreme Court denied the emergency application to vacate the stay (July 2026). The law is currently enforceable.** Fifth Circuit merits briefing and an expedited hearing were expected around August 2026; I found no result. | [Bill text](https://capitol.texas.gov/tlodocs/89R/billtext/html/SB02420F.htm), [CCIA case page](https://ccianet.org/litigation/ccia-v-paxton-w-d-tex/), [CCIA July 2026](https://ccianet.org/news/2026/07/supreme-court-opts-not-to-intervene-and-block-a-texas-app-store-law-that-likely-violates-first-amendment/), [Pearl Cohen](https://www.pearlcohen.com/fifth-circuit-stays-injunctions-against-texas-app-store-accountability-act/) **[exact stay and SCOTUS dates UNVERIFIED]** |
| Louisiana | HB 570 (Act 481 of 2025), **repealed and reenacted by HB 977 (signed 2026-05-15)** | New effective date **2027-07-01**. Developer safe harbor for relying on app-store signals. | [Tech Times](https://www.techtimes.com/articles/319484/20260701/louisiana-app-store-age-law-delayed-2027-id-breach-pattern-grows.htm) **[secondary; UNVERIFIED]**, [Orrick (2025, HB 570)](https://www.orrick.com/en/Insights/2025/07/Texas-and-Louisiana-Join-Growing-Trend-of-State-Age-Verification-Laws-for-App-Stores) |
| Alabama | HB 161, signed 2026-02-17 | Effective 2027-01-01. Four age categories (under 13, 13-15, 16-17, 18+), parent-account affiliation, parental consent for downloads. | [Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/alabama-enacts-app-store-accountability-act-requiring-age-verification) **[UNVERIFIED; statute text not read]** |
| California | AB 1043 (Digital Age Assurance Act), Civ. Code 1798.500 et seq. | Signed 2025-10-13; **effective 2027-01-01**. Different model: the **OS provider** collects an age bracket at account setup and sends a signal; developers must request it. | [Bill text](https://leginfo.legislature.ca.gov/faces/billTextClient.xhtml?bill_id=202520260AB1043) |
| Federal | HR 3149 / S 1586 | Not enacted (per secondary sources). **[UNVERIFIED]** | [Loeb June 2026](https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-in-2026-congress-stalls-again-ftc-signals-priorities) |

### 3.2 Developer duties (Texas, the strictest in force)

- Texas Sec. 121.051: "This subchapter applies only to the developer of a software application that the developer makes available to users in this state **through an app store**."
- Sec. 121.054(a): the developer must "create and implement a system to use information received under Section 121.024 to verify" each user's age category and whether parental consent was obtained.
- Developers must also assign age ratings and notify the app store of "significant changes" (Sec. 121.053). Violations are a deceptive trade practice actionable under DTPA ch. 17, subch. E (Secs. 121.101-.102).
- Texas Sec. 121.002 defines "app store" as a "publicly available Internet website, software application, or other electronic service that distributes software applications." Per the fetch summary, "developer" is not separately defined in Texas. **[UNVERIFIED]**
- Utah (SB 142 Sec. 13-75-101, per search-result quotation, not read in the enrolled text): "developer" = "a person that owns or controls an app made available through an app store in the state"; "app store" = "a publicly available website, software application, or electronic service that allows users to download apps from third-party developers onto a mobile device." **[UNVERIFIED, quoted from a search result, not read in the statute]** Utah and Texas also give a private right of action per secondary sources ($1,000 per violation or actual damages plus fees in Utah). **[UNVERIFIED]**
- Louisiana's reenactment gives developers a safe harbor for relying on app-store signals; I have not read the text. **[UNVERIFIED]**

### 3.3 Do these laws impose duties on developers of apps distributed outside app stores?

- **Texas, Utah, Louisiana (HB 570/977), Alabama: on the text I could verify or confirm, no.** The developer duties attach to a developer whose app is "made available ... through an app store" (Texas 121.051 is explicit; Utah's "developer" definition says the same). An app downloaded from the developer's own site, or from a seller platform that is not an "app store," is outside the developer definition.
- **"Mobile device" limit.** The Utah and Texas "app store" definitions refer to downloading onto a "mobile device" (smartphone or tablet running a handheld OS, per the Texas fetch summary). A Mac is not a mobile device on that wording. **[UNVERIFIED; check the actual definitions in both bills]** Secondary commentary says an aggressive reading might stretch to other devices, but no court has done so.
- **No source I found says direct downloads are covered, and none says expressly that they are excluded.** McDermott: the documents "do not explicitly address" non-app-store channels. FPF's chart (fetched; I treat its summary as unreliable because several of its dates conflicted with other sources) says direct downloads receive "minimal explicit coverage." Overall, silence plus the "through an app store" trigger is the argument, not an express exemption. **[Attorney-review flag]**

### 3.4 Do they apply to Mac apps sold via Gumroad?

Reasoning in order:

1. Mac is not clearly a "mobile device" (3.3).
2. The "developer" duty needs an "app store" intermediary. The DMG is downloaded free, and Gumroad sells only the license key. The app itself is not "made available through" Gumroad in the sense these laws describe, since Apple's Mac App Store is not involved at all.
3. Gumroad is not a signal source. The duties assume the app store sends an age category and consent flag. Gumroad sends none, so the developer would have nothing to "use." This supports the inference that the laws are not aimed at this channel. It is my inference, not a cited rule.

### 3.5 Risks and open questions

- **Is Gumroad an "app store"?** It is a "publicly available ... website ... that distributes" digital goods, and Texas's definition has no explicit "mobile" qualifier in the form I read ("software applications" only). A plaintiff could argue Gumroad distributes software and the developer's DMG is made available "through" it. The counter-arguments are the "mobile device" language in Utah's version and the lack of any app-store function (no age signal, no accounts-based consent flow). **No authority either way. [Flag]** If Texas treated Gumroad as an app store, the duty would fall on Gumroad as the "app store" first; the developer's exposure would be secondary and would mostly require Gumroad to start sending signals.
- **Enforcement posture.** Texas is enforceable now but has litigation pending. Utah and Louisiana duties start in 2027. Alabama and California start 2027-01-01.
- **Pre-installed apps** (Utah HB 498) are irrelevant here.

### 3.6 California AB 1043: the one that might reach a Mac app (eff. 2027-01-01)

From the bill text ([leginfo](https://leginfo.legislature.ca.gov/faces/billTextClient.xhtml?bill_id=202520260AB1043), via a fetch summary; read the full text before relying):

- **"Application"**: "A software application that may be run or directed by a user on a computer, a mobile device, or any other general purpose computing device."
- **"Developer"**: "A person that owns, maintains, or controls an application."
- **Sec. 1798.501**: developers must "request a signal with respect to a particular user from an operating system provider or a covered application store" when the app is downloaded and launched, treat the signal as the primary age indicator, not willfully disregard clear contrary information, and not share it except as law requires. Signal categories are under 13, 13-15, 16-17, 18+.
- **Penalties** (Sec. 1798.503): AG civil actions, up to $2,500 per affected child (negligent) and $7,500 (intentional).
- **No carve-out** in the text I saw for apps obtained outside a covered application store, or for apps that collect no data. The only listed exclusions were broadband, telecommunications and physical-product delivery.
- Apple (macOS provider) is the "operating system provider." Whether Apple will expose an age-range API on macOS by 2027-01-01, and how a non-App-Store app would call it, is **unknown** to me. **[UNVERIFIED]** Apple has shipped a Declared Age Range API on iOS; I have not checked macOS or the developer terms.
- **Why this matters to Humanity:** it is the first law I found whose developer duty is not tied to app-store distribution. It also reaches desktop OSs. A developer with Californian users (including Massachusetts-based sale to a Californian) could be within scope in principle, since it does not turn on revenue size.
- **Recommended action:** put a calendar item for Q4 2026 to (a) read the final statute and any 2026 cleanup bill, (b) check Apple's macOS age-signal API, and (c) have an attorney say whether a free-download, key-gated Mac app has a request-signal duty, and what "request" costs (probably one API call, no data leaving the device).

## 4. State social-media and minor laws

Examples: Utah Minor Protection in Social Media Act, Texas HB 18/SCOPE Act, Florida HB 3, California SB 976, and so on. These are keyed to **"social media platform" / "digital service provider"** definitions (user profiles, feeds, interactions) and to *platform* duties (age verification, parental tools, feed restrictions). Humanity has no accounts, feeds or user-to-user content. **Not relevant** on current facts. I did not research individual statutes or their litigation status; no need unless the product adds sharing or community features. **[Not researched; flag only if features change]**

State comprehensive privacy laws also contain minors' provisions (consent for sale or targeted advertising for under-16s, and so on) but apply only to controllers that process personal data above thresholds; the developer's no-collection architecture keeps him outside, subject to doc 11. **[Not re-verified here]**

## 5. Recommended measures

### 5.1 Age statement in the Terms/EULA (draft language for attorney review)

> **Who may use Humanity.** Humanity is intended for adults. You must be at least 18 (or the age of majority where you live) to buy a license key or use the app. If you are under 18, a parent or guardian must buy the license, accept these Terms for you, and supervise your use. Humanity is not directed to children under 13, and we do not knowingly collect personal information from them. Humanity processes your webcam images, microphone audio and voice profiles on your own computer; we do not receive them. If you record or enroll other people (including voice profiles in Meetings), you are responsible for getting any consent the law requires, including a parent's or guardian's consent for a child.

Notes for the lawyer:
- "18 or parental involvement" tracks the stated Gumroad intent, but note Gumroad's own terms say 13+ and legal age to contract (1.4). Do not state that Gumroad requires 18+.
- Contract-formation with a minor is voidable in most states. Consider whether the minor clause adds anything for a PWYW $5 product. A flat "18+" is simpler.
- Consider a short "if we learn a child under 13 has bought, we will refund and delete" sentence in the privacy policy and support docs.

### 5.2 Is an age gate warranted?

**No, not on current facts.**

- No law found requires a Humanity-style developer to age-gate. COPPA does not require asking age (FTC FAQ). The state design codes and social-media laws do not apply. The ASAAs reach "through an app store" apps, and the signals come from the store, not the developer.
- An in-app birthdate prompt would **create** the data the architecture avoids, produce a "neutral age screen" design obligation under COPPA guidance, and could itself create actual knowledge of under-13 users. The FTC's February 2026 policy statement is about age verification data deleted after use; I did not read it, so I make no claim about whether an in-app prompt would qualify.
- Possible later gate: a one-time EULA checkbox ("I am 18 or older, or a parent or guardian has accepted these Terms") at first launch. This collects nothing, and the checkbox state can be stored locally. It adds contract evidence but not compliance by itself. Low cost; optional. Decide with counsel.

### 5.3 Other product and doc changes

1. Product page and Gumroad listing: "Not for children. For adults." Avoid imagery, school or kid use cases and gamified-for-kids language.
2. PRIVACY.md: add a "Children" section: not directed to under-13s, no personal information collected by the developer, contact for parent or guardian requests, and deletion handling for buyer records on request.
3. Murmur Meetings voice profiles: in-app notice at creation time ("Only create voice profiles of people who have agreed. For a child, a parent or guardian must agree."). Counts as a mitigation, not a legal shield.
4. AIKit: note that third-party AI providers have their own age rules and that the user's content goes to them.
5. Do not add analytics, ad SDKs or crash reporters that transmit device identifiers; any of those would reopen COPPA "operator" and persistent-identifier questions.
6. Keep a dated log of buyer-reported ages or child complaints, and a refund-and-delete routine.
7. Calendar: re-check on 2026-12-01 (California AB 1043 final text and Apple's macOS API; Texas Fifth Circuit merits ruling; Alabama and Louisiana start dates 2027-01-01 and 2027-07-01; Utah 2027-05-06).
8. If an entity or Mac App Store distribution is ever added, re-run this analysis: Mac App Store distribution would put the app "through an app store," and the Apple-provided age-range signal flow would then be directly relevant.

## 6. Attorney-review flags

1. Whether on-device-only processing of children's biometrics (face, voice) by a downloaded app avoids "operator" status under COPPA. No authority found.
2. Whether Gumroad is an "app store" under the Texas/Utah/Louisiana/Alabama definitions, and whether "mobile device" excludes Macs in each.
3. **California AB 1043** applicability to a Mac app distributed outside any store (3.6). Read final text, check later amendments.
4. Enforceability of an 18+ clause against minors and what Gumroad's own "13 + legal age" language means for buyers.
5. Voiceprints of third-party children (state biometric and consent laws, not only COPPA).
6. Whether an individual with no entity is a "person" or "business" under each statute, and personal liability exposure (relevant to LLC planning).
7. Status updates the research could not confirm: Fifth Circuit merits (Texas), D. Md. case after discovery, N.D. Cal. AADC remand.

## 7. Sources verified (2026-10-01)

Read directly (via fetch tool; summaries from a small model, so quotations are best-effort):
- Texas SB 2420 text: https://capitol.texas.gov/tlodocs/89R/billtext/html/SB02420F.htm (Sec. 121.051, .053, .054, .101-.102)
- California AB 1043 text: https://leginfo.legislature.ca.gov/faces/billTextClient.xhtml?bill_id=202520260AB1043
- 16 CFR 312.2: https://www.law.cornell.edu/cfr/text/16/312.2
- COPPA final rule dates (govinfo): https://www.govinfo.gov/content/pkg/FR-2025-04-22/html/2025-05904.htm
- FTC COPPA FAQ: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
- FTC COPPA rule page: https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa
- Gumroad Terms (last updated 2026-09-14): https://gumroad.com/terms

Secondary or search-snippet only (treat as unverified):
- CCIA v. Paxton: https://ccianet.org/litigation/ccia-v-paxton-w-d-tex/ and https://ccianet.org/news/2026/07/supreme-court-opts-not-to-intervene-and-block-a-texas-app-store-law-that-likely-violates-first-amendment/
- Pearl Cohen on the Fifth Circuit stay: https://www.pearlcohen.com/fifth-circuit-stays-injunctions-against-texas-app-store-accountability-act/
- Utah: https://le.utah.gov/Session/2025/bills/introduced/SB0142.pdf, https://www.loeb.com/en/insights/passle/2026/05/update-on-utah-app-store-law--another-waiting-game, https://www.stoel.com/insights/publications/utahs-app-store-accountability-act-goes-into-effect
- Louisiana HB 977: https://www.techtimes.com/articles/319484/20260701/louisiana-app-store-age-law-delayed-2027-id-breach-pattern-grows.htm
- Alabama HB 161: https://www.hunton.com/privacy-and-cybersecurity-law-blog/alabama-enacts-app-store-accountability-act-requiring-age-verification
- McDermott overview: https://www.mcdermottlaw.com/insights/app-store-accountability-acts/
- FPF comparison chart (low reliability): https://fpf.org/wp-content/uploads/2026/06/FPF-Legislation-TX-UT-LA-App-Store-Accountability-Act-Comparison-Chart.pdf
- CA AADC: https://law.justia.com/cases/federal/appellate-courts/ca9/25-2366/25-2366-2026-03-12.html, Cooley and Holland & Knight summaries linked above
- MD Kids Code: https://blog.ericgoldman.org/archives/2025/11/challenge-to-marylands-kid-code-survives-motion-to-dismiss-netchoice-v-brown.htm, https://law.justia.com/cases/federal/district-courts/maryland/mddce/1:2025cv00322/575260/90/, https://onlinesafety.orrick.com/maryland/
- Federal bills: https://www.loeb.com/en/insights/publications/2026/06/childrens-online-privacy-in-2026-congress-stalls-again-ftc-signals-priorities

Not verified: the enrolled text of Utah SB 142 and HB 498, Louisiana HB 977 and Alabama HB 161 statutes, the California AADC and Maryland statute text, the FTC Feb. 2026 policy statement, exact Fifth Circuit and Supreme Court dates, and any macOS age-signal API.
