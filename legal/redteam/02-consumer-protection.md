# Red team 02: Consumer-protection regulator (FTC Act s.5; M.G.L. c. 93A / 940 CMR 3.00)

Persona: FTC staff plus MA AG Consumer Protection. Reviewer is not a lawyer; nothing here says the product is "safe" or "compliant". Read-only review of commit 1f611aa (code, README, TERMS.md, PRIVACY.md, release.yml, LicenseKit) plus the Gumroad draft text in the brief. Items marked ATTORNEY need counsel. Legal cites from memory; verify before relying on them.

Ranking = likelihood x impact. Fixes are minimal, one file each where possible.

## Summary table

| # | Finding | L | I |
|---|---|---|---|
| 1 | Linked Terms say "Not yet in effect" and contain blanks; Gumroad says "By buying, you agree" | H | H |
| 2 | Refund promise vs Terms (blank window, "first-time", Gumroad final say, no email) | H | M |
| 3 | Silent, over-broad license revocation (any `success:false`, no notice, no HTTP check) | M | H |
| 4 | Terms-version gate locks paid users out until they re-assent (retroactive change in effect) | M | M |
| 5 | Clickwrap: post-payment, mutable link target, no refund-if-decline line, no seller-side record | M | M |
| 6 | "Free download" framing: paid gate disclosed late; Releases page silent on price | M | M |
| 7 | Quantified accuracy claim ("within a few degrees") vs own research (2-5 deg) | M | M |
| 8 | Accessibility positioning vs "not assistive" disclaimers; inconsistent wording | M | M |
| 9 | Unnotarized 5-step Open Anyway: trains users to bypass Gatekeeper; ad-hoc signing consequences | M | M |
| 10 | Hidden conditions: Apple silicon / macOS 26 feature split / 14.4 meeting audio / 60-day offline / keys-per-Mac blank | M | L-M |
| 11 | "Never leaves your Mac" strings vs AI-provider path and third-party downloads | L | M |
| 12 | Seller identity, contact, and promise-to-release-keyless-build unenforceable | M | M |

## 1. Terms are expressly "not in effect" yet are what buyers and the clickwrap point to (ATTORNEY)
- Scenario: Gumroad page says "By buying, you agree to the Terms of Sale". The app checkbox links to `TERMS.md` on GitHub `main`. That file opens with "Not yet in effect... pending review by a lawyer" and contains `[SELLER LEGAL NAME / DBA]`, `[CONTACT EMAIL]`, `[14 / 30]`, `[one person / up to N Macs]`, `[Suffolk / Middlesex]`, "Option B in the reviewer note". A buyer, or the AG, would say the consumer was bound to a document that disclaims being binding, with no identifiable seller. Gumroad checkout generally has no assent checkbox for custom terms, so purchase-time assent is browsewrap at best.
- L/I: H/H.
- Mitigation: banner is honest (TERMS.md:1-3); `termsVersion` gate (License.swift:14,49); Gumroad is merchant of record.
- Remaining risk: unfair/deceptive term representation (c. 93A s.2; 940 CMR 3.00); unenforceable terms; no named seller for 93A s.9 demand letters; no contact for refund-by-email (TERMS.md:97).
- Fix: before first sale, fill every bracket, delete banner, set Gumroad "contact email". In `License.swift:11-12` link to an immutable URL (tag or commit SHA, or a static page) not `blob/main`. Treat as a release blocker in `legal/RELEASE-CHECKLIST.md`.

## 2. Refund promise vs Terms (ATTORNEY)
- Scenario: Gumroad: "30-day money-back guarantee, no questions asked." Terms: window is `[14 / 30]` (TERMS.md:97); "first-time refund requests" only (repeat buyers excluded; "no questions asked" is unqualified); Gumroad "has final say" (s.9.2); refund by email needs an address that does not exist yet. 16 CFR 251 and 940 CMR 3.00 treat a headline guarantee narrowed by fine print as a net-impression problem. Also, if the Gumroad product refund-window setting is not 30 days, the page is false on its face.
- L/I: H/M.
- Mitigation: s.9.3 discloses "refunded key stops working" in the Terms and on the page; s.12 carve-out for 93A.
- Remaining risk: "no questions asked" with "first-time" qualifier; terms silent on what happens to a refunded user's local recordings (they remain on disk, app locked).
- Fix: TERMS.md s.9.1: set "30 days", delete "first-time" or write "per Key", and state "a refund is available through Gumroad's Refund button or by email". Confirm Gumroad refund-policy setting equals 30 days. Gumroad copy: add "(first refund per buyer)" only if that stays.

## 3. License revocation: silent, over-broad, unannounced (ATTORNEY on remedy)
- Scenario A (over-broad): `failure(in:)` returns `.rejected` for any decodable reply with `success:false` (License.swift:120-121). The "unreadable = offline" safeguard (comments at 105-107) covers only undecodable bodies. HTTP status is never checked (line 86 discards the response). A Gumroad JSON error (rate limit, maintenance, or a changed/deleted/recreated product, since `productID` is hardcoded at line 15 and the listing is a draft) is treated as "key invalid", and `recheckIfDue` runs `save(nil)` (137-138), deleting the stored key. Result: paying customers locked out of their own recordings, calibration and voice profiles inside the app, with a generic "key isn't valid" message that blames them.
- Scenario B (no notice): TERMS.md s.14 promises "where practical, notice and a chance to cure". The code revokes silently in the background; next launch shows the activation window with no explanation unless they re-paste a key. Chargeback/dispute rule (123-124) also revokes on any open dispute (`disputed && !dispute_won`), including a bank-initiated dispute the user did not file.
- Scenario C: no in-app view of license status, terms, or a "Deactivate/Manage license" path (grep: LicenseKit is called only from `requireActivation` in the four app entry points).
- L/I: M/H.
- Mitigation: refund/chargeback revocation is disclosed (TERMS.md:99, Gumroad page); 60-day offline grace (License.swift:21); network errors keep the key (line 139).
- Remaining risk: mass lockout is a plausible UDAP "unfair practice" fact pattern if it hits paid users.
- Fix (License.swift): in `activate`, capture `(data, response)`; treat non-2xx and any `success:false` whose `message` is not the known "license does not exist" / refunded / disabled cases as `.network`. In `recheckIfDue`, on `.rejected` set a `revokedReason` flag (UserDefaults) instead of silent delete, and show it in `ActivationView` ("Your key was deactivated because it was refunded/disputed. Contact X"). Add a minimal "License" row in each Settings (key status, view Terms, Deactivate). Confirm `productID` is the final product before shipping 1.0.0.

## 4. Terms-version bump locks out paying users until they re-assent (ATTORNEY)
- Scenario: bumping `termsVersion` (License.swift:14) makes `isUnlocked` false (line 49) for everyone, and re-assent needs the network (`activate`). TERMS.md s.19 says changes "do not apply retroactively to a Key you already bought unless you accept them". In practice a user who rejects new terms loses a product they bought. A regulator calls that a unilateral material change enforced by loss of function; also an offline traveller is locked out.
- L/I: M/M (becomes H if terms are bumped to fix item 1 after sales begin).
- Mitigation: s.19 wording; Terms bump is only for "material" changes (comment line 13).
- Remaining risk: no refund path stated for decliners; no grace for those already inside the 60-day window.
- Fix: License.swift:49: if key is fresh and only the terms version differs, allow a one-time grace (e.g. 14 days) with a banner; TERMS.md s.19: add "if you decline new terms you may keep using the version you installed, or get a refund within X days of the change".

## 5. Clickwrap presentation (Kauders v. Uber, 486 Mass. 557 (2021); Good v. Uber (verify cite and court))
- What is good (ActivationView, ActivationWindow.swift:55-73): unchecked checkbox, button disabled until checked (line 72), button text "Agree and Activate", both documents hyperlinked, assent version and time stored (License.swift:25-29,92-94). That is stronger than the Uber sign-in-wrap Kauders upheld.
- Scenario: (a) Assent comes after payment; the dialog never says "no agreement, no charge: request a refund". (b) Link text is `.caption` in a 380pt window (line 57-58); links sit inside a Toggle label, so clickability and legibility need a manual check. (c) Link target is mutable `main` (items 1). (d) The record lives only in the user's local `license.json` (`agreedAt`), editable, with no seller-side proof; the seller cannot show assent for a given purchase. (e) "have read the Privacy Policy" is an unverifiable representation by the user. (f) Key is stored in plaintext JSON, not Keychain (low).
- L/I: M/M.
- Remaining risk: weak evidence of assent; adhesion arguments on s.12 cap and s.13 indemnity.
- Fix: ActivationWindow.swift line 57: use `.callout` size; add a second line "Don't agree? Close this window and ask Gumroad for a refund within 30 days." Pin `termsURL` to a tag. Optionally send nothing new, but embed a hash of TERMS.md in `Stored.termsVersion`. ATTORNEY: whether Gumroad checkout needs its own assent mechanism.

## 6. "Free download" framing (16 CFR Part 251, Guides on "Free")
- Scenario: README says "The download costs nothing, but the apps need a paid license key to run" (README.md:24) and the Gumroad page says "download costs nothing, but apps need a license key". Disclosure is in the same sentence (good). But `release.yml` notes (Install step 5) say only "Paste your license key" with no price or purchase link, so someone landing on the public GitHub Releases page sees a download that does nothing without payment. The Guides require the condition be disclosed "at the outset". Also the mismatch: README says "open-source... no account" while the compiled app cannot run without paying and an online check; and what the buyer receives from Gumroad (a key only? a file?) must be unambiguous.
- L/I: M/M.
- Mitigation: README paragraph and the activation window ("Buy a License" button, ActivationWindow.swift:67); source is MIT and buildable free (TERMS.md:19-20), which keeps "free" claims about the source true.
- Remaining risk: "Free download" as a headline on any surface; "free" applied to a binary that is inoperable.
- Fix: release.yml notes: add line 0 "The app requires a license key (from $5): https://gumroad.com/l/hamkad. Or build free from source." Avoid the word "free" next to the DMG; say "download without a key; a key is required to run".

## 7. Substantiation of the accuracy claim (FTC substantiation doctrine; 93A)
- Scenario: README states OculOS "typically lands within a few degrees" (README.md ~61-62). The repo's own research puts webcam accuracy at 2-5 deg and notes this rules out clicking ordinary targets directly (research/07-gaze-interaction.md:5; research/04-iris-pupil.md:26; research/03:17 cites 5.79 deg in interactive use). The code has an in-app accuracy check but no recorded benchmark backing "typically". Terms s.11 also disclaims accuracy, but a disclaimer does not cure an affirmative claim.
- L/I: M/M.
- Mitigation: "approximate" and "can misread you" wording; dwell off by default and skips close buttons (SettingsView.swift:72); pause hotkeys (README.md:60-63).
- Fix: README: replace with "Accuracy varies by person, lighting and camera; calibration reports your measured error" and drop the numeric claim unless a benchmark file is added to `research/`. Keep the Gumroad page free of numbers.

## 8. Accessibility positioning vs "not assistive" disclaimers
- Scenario: README leads with "controlling your computer with your eyes, hands and voice" and links accessibility research; the first audience who benefits is people with motor limitations, who are a vulnerable group for FTC purposes. The disclaimer ("not a medical or assistive device", README.md:59; Gumroad) is real but sits lower and is not what the headline implies. Wording is also inconsistent: README says "not a medical or assistive device"; TERMS.md:64 says "not medical devices or certified assistive technology". A regulator reads net impression, not footnotes. Dwell click that can mis-click on purchases/send is a real harm path to someone with no keyboard fallback.
- L/I: M/M.
- Mitigation: keep-a-keyboard-available warning; Esc/hotkey stops; dwell off every launch; TERMS s.6 on accidental actions (TERMS.md:73-81).
- Fix: README.md:59 and Gumroad copy: use one phrase everywhere ("not a medical device and not certified assistive technology; accuracy is lower than dedicated eye trackers"). Put the sentence in the Gumroad description's first screen, not only the Limitations section. Do not add the words "accessibility", "disabled users", "ADA" to marketing without counsel review.

## 9. Unnotarized install and ad-hoc signing
- Scenario: the 5-step Open Anyway flow (release.yml notes; README.md:27-28) tells consumers to override Gatekeeper and enter their login password, for an app that then requests Camera, Microphone and Accessibility (can control the whole Mac). Regulators view "disable your security warning" instructions as risky for a paid product, and because the code is MIT, lookalike malicious DMGs are easy; users have been taught to approve unsigned apps. Release builds are ad-hoc signed with no pinned requirement (release.yml "PIN_DR=0"), so each update resets permission grants (also acknowledged in SetupView text, Murmur SetupView.swift:40). The checksum (`.sha256`) sits next to the DMG, so it only detects corruption, not tampering.
- L/I: M/M.
- Mitigation: SHA-256 files (`dist/*.sha256`); source pinned actions; SECURITY.md is candid; hardened runtime.
- Fix: Gumroad copy: state "not yet notarized; verify you downloaded from github.com/pikabrofar/sentidoS/releases, and compare the SHA-256". Add an official URL line to README.md:24-28. Plan Developer ID notarization before scaling sales; until then do not describe the flow as "easy".

## 10. Hidden or late-disclosed conditions
- Apple silicon: Gumroad says it; README Requirements (README.md ~33-37) does not, and CI builds universal (release.yml `UNIVERSAL: "1"`) so an Intel Mac user may buy a DMG that opens but misbehaves. Verify on Intel or state it.
- macOS 14 vs 26: summaries via Apple Intelligence and the better SpeechAnalyzer need macOS 26 (Murmur `Intelligence.swift:15` "Requires macOS 26"; `Transcriber.swift:30`); meeting call-audio capture uses an API gated at 14.4 (`MeetingRecorder.swift:120,161`). "macOS 14+" overstates parity.
- Online dependency: weekly Gumroad check and a 60-day offline lockout (License.swift:19-21) are in Terms s.7 and PRIVACY but not in the Gumroad one-line list; lockout after 60 days offline has no offline recovery.
- Per-key device limit: TERMS.md:25 is a blank; "one key unlocks every app" is clear, "how many Macs" is not.
- Updates: "free for [life of 1.x / N years]" blank (TERMS.md:102-104); no auto-updater means no security patches reach users automatically (SECURITY.md).
- L/I: M/L-M.
- Fix: Gumroad "Requirements" box: Apple silicon (or test Intel), macOS 14+, "some features need macOS 26", internet for activation and weekly check. Fill the Terms blanks.

## 11. Privacy-claim accuracy (FTC deception; biometric policy statement 2023)
- Verified true in code: audio/video not uploaded (AIKit sends text only; no multipart or audio endpoints found); speech recognition forced on-device (`Transcriber.swift:199-202`); license check sends key and product ID only; license.json stores key and dates only.
- Residual: UI strings like "your voice never leaves it" (Murmur SetupView.swift:14) and "Everything runs on this Mac" read as absolute, but transcripts can go to a cloud provider the user enables, and models download from Hugging Face. Some provider `dataUse` notes (e.g. Google free-tier review, AIKit `Provider.swift:55`) are shown in the UI (good) but are not on the Gumroad page.
- L/I: L/M.
- Fix: change that Murmur string to "Your voice is processed on this Mac. Text goes to an AI provider only if you add one." Mirror the Gumroad privacy sentence in the app's setup pages.

## 12. Seller identity and unenforceable promises (ATTORNEY)
- Scenario: Terms name no seller (TERMS.md:20 blank) and the repo owner is a handle. TERMS.md:108 promises a keyless release "if we stop selling Keys or Gumroad verification stops working", but installed binaries cannot receive it (no updater, `License.required` is a compile-time constant at License.swift:7), so affected buyers must find and reinstall a new build. Individual proprietor liability is personal and unlimited (LLC question already in TERMS.md Open Questions).
- L/I: M/M.
- Fix: TERMS.md s.20 and Gumroad profile: real name or DBA, email, postal address (or registered agent). TERMS.md:108: add "we will announce it on the GitHub releases page and the Gumroad product page". Consider an LLC and E&O/cyber coverage before launch (counsel).

## Attorney items consolidated
1 Binding-ness of terms and checkout assent (item 1, 5); 2 refund guarantee language and Gumroad's MoR role (2); 3 remedy for deactivation and whether revocation is a 93A unfairness issue (3, 4); 4 "free"/net-impression review of all marketing (6, 8); 5 warranty disclaimer for MA consumers, M.G.L. c. 106 s.2-316A (TERMS.md:110-115; software as "goods"); 6 entity formation and insurance (12); 7 EU withdrawal-right waiver mechanics at activation (TERMS.md s.9.4) since the checkbox does not mention it.

## Already done well (credit)
Unchecked, affirmative clickwrap with version and timestamp; 93A carve-out in s.12; refunds and revocation disclosed up front; no mandatory arbitration; consumers keep local mandatory law (s.17); source remains free; recording-consent and voiceprint notices landed in 1f611aa.
