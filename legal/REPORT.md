# Humanity: compliance research report (pre-release)

Prepared 2026-10-01 against commit `222596d` and the then-untracked `.github/`. Written by a compliance research lead, **not a lawyer. This is not legal advice.** Nothing here says the product is safe, compliant or immune from suit.

Markers used throughout: V = fetched and read 2026-10-01; V2 = secondary source only; U = unverified. Full source URLs are in the files in `legal/`, `legal/research/` and `legal/redteam/`. This report summarizes them.

Since this report was drafted, PRIVACY.md has been fixed: the unremembered-voiceprint row now says 30 days, and "Learn from clicks" is disclosed (P0-7).

## 1. Executive summary
- **Engineering findings mostly closed.** Most P0/P1 engineering findings were closed in three commits: `e098368`, `1f611aa` and `222596d`.
  - Recording consent gate, floating banner and 30-minute reminder.
  - Opt-in voiceprints with retention.
  - Dictation audio off by default, and Delete All.
  - 0700 folders and the input sanitizer.
  - Gumroad-error safety and key-free source builds.
  - Per-app entitlements and complete notices.
- **Downloads.** The 1.0.0 DMGs have correct per-app entitlements and current notices. They are ad-hoc signed and arm64-only, so they are not notarized.
- **Remaining blockers are mostly owner actions:**
  - Terms/Privacy placeholders.
  - Developer ID and notarization.
  - Gumroad settings.
  - Pushing `.github/`.
  - Trademark decisions.
  - Entity and insurance.
- **Terms not in effect.** `TERMS.md` still says "Not yet in effect". Selling before that is fixed is the largest consumer-law exposure (c.93A, FTC §5).
- **Wiretap and biometric exposure** (c.272 §99, BIPA, CUBI, GDPR Art. 9, EU AI Act) now rests on better design facts. The legal positions are untested and need counsel.
- **Bottom line: risk is reduced, not eliminated.** A determined user can still misuse Meetings. An unincorporated seller is personally liable.

## 2. Applicable laws (summary; full table and URLs in `legal/LEGAL-COMPLIANCE.md`)

| Law | Applies? | What we did | Residual risk | Attorney |
|---|---|---|---|---|
| FTC Act §5; Free Guide 16 CFR 251.1 | Yes | Claims audits; wording fixed; paid key disclosed | Gumroad copy, release notes | Y |
| MA wiretap c.272 §99 ("aid"), CA PC 631/632, 18 USC 2511/2512 | Users yes; developer indirectly | Consent gate, Copy to Chat, banner, reminder, Stop & Delete, no stealth | Self-attestation; no vendor case law | Y |
| MA c.93A, 940 CMR 3.13, c.106 §2-316A; Kauders / Good v. Uber | Yes | 30-day refund in TERMS; clickwrap with version and date | Terms not in effect; cap/disclaimer conflict | Y |
| MA c.93H / 201 CMR 17 | Probably not | — | Gumroad exports | N |
| IL BIPA (G.T. v. Samsung, 7th Cir. 2026); TX CUBI; WA 19.375 / MHMDA; CO HB24-1130; CT | Developer likely not (no control); users possibly | Opt-in, retention table, backup exclusion | State courts not bound; checkbox ≠ written release | Y |
| CCPA / other state privacy laws | No at this scale | Never sell data | — | N |
| COPPA; CA AB 1043 (2027); TX SB 2420 | Probably not / watch | Children section | Age-signal duty possible from 2027 | Y |
| GDPR, EU AI Act, EU CRA, EU consumer law | Only if selling to the EU | — | CRA reporting since 2026-09-11. Recommendation: US-only launch | Y |
| ADA / FDA | Only with medical claims | "Not a medical or assistive device" | Research notes naming conditions (softened) | Y |
| EAR / OFAC | Light | Likely EAR99; Gumroad blocks embargoed countries | No classification memo | Y |
| Tax | Gumroad is merchant of record for sales tax | — | Income tax; confirm MA collection | CPA |
| Trademark | Yes | TRADEMARKS.md | Murmur HIGH, OculOS MED-HIGH, Humanity MED-HIGH, ManOS MED | Y |
| Personal liability | Yes | — | Sole proprietor; consider an LLC | Y |

## 3. Apple

**Done:**
- Hardened runtime, with per-app entitlements.
- No private APIs, Apple events or `get-task-allow`.
- Usage strings match each app's APIs.
- `--timestamp` used for real certificates, and packages never pin the signature.
- Original icons.

**Left:**
- Developer Program ($99/yr) and a Developer ID certificate.
- Sign, notarize and staple, then confirm with `spctl --assess`.
- Compute the checksum after stapling.
- Remove the "Open Anyway" text once notarized.
- Clean-machine test on macOS 15, 26 and 27.
- Counsel to read DPLA §3.3.1(C) (license keys) and the Foundation Models acceptable-use requirements.

## 4. Gumroad

**Done:**
- License verification by product ID.
- `dispute_won` respected.
- 5xx, 429 and unreadable replies treated as offline.
- Offline re-assent.
- Draft page updated: refund line, consent note, checksums, Terms link.

**Left (owner):**
- Connect payout.
- Support email.
- 30-day refund setting, and the checkout Terms field.
- Read the updated Gumroad Terms before **2026-10-14** and decide on the 30-day arbitration opt-out (§19). The seller indemnity is uncapped.
- After publishing, test with a 100%-off code: key issued, activation, refund, verify.

**Left (code):**
- Release notes are missing the price and the Gumroad link.
- CI builds universal binaries while the docs say Apple silicon.

## 5. Privacy

**Matched to code:**
- No camera frames are saved or sent.
- Speech recognition is on-device.
- Dictation keeps text only by default.
- Voiceprints are created only with Remember plus a consent date.
- Profile retention is 12 months unused, 3 years maximum.
- No voice matching without recording consent.
- A meeting summary asks before using the cloud.
- Delete All works, and its scope is stated.
- Folders are 0700, with backup exclusion for biometric data.
- The license check sends only the key and the product ID.

**Gaps:**
- Note summaries go to a configured cloud provider without a per-note prompt.
- Some undated provider data-use notes.
- No privacy contact or effective date in PRIVACY.md yet.
- `legal/PRIVACY-POLICY-DRAFT.md` is stale relative to the current code.

## 6. Security

**Fixed:**
- Control and invisible characters are stripped before typing into terminals.
- Dev signatures are no longer pinned in packages.
- Gumroad errors never revoke a key.
- Concealed clipboard contents are never restored.
- Dwell snap reduced, and dialogs and close buttons avoided.
- Stuck mouse button released.
- Redirects never carry the API key to another host.
- A future-dated license is capped.
- Meeting delete is confined to the Meetings folder.
- Crash leftovers are cleaned up.

**Open:**
- High: the app is unnotarized, so a lookalike DMG can't be told apart.
- Med: `.github/` is unpushed.
- Med: a FluidAudio environment variable can redirect model downloads.
- Med: newlines can still reach editor-integrated terminals.
- Med: Delete All hides failures.
- Several Low items: see `legal/redteam/03-security-researcher.md`.

## 7. Open source

**Done:**
- Complete notices shipped in every app.
- Original icons.
- TRADEMARKS.md, plus a DCO in CONTRIBUTING.md.
- Source builds are key-free.
- The Gaze360 script requires acknowledgement.

**Open:**
- The LICENSE holder is "Humanity contributors"; replace it with the legal name or DBA.
- No ScanCode scan yet.
- No CI guard that keeps the espeak-derived FluidAudio bundle out.
- TERMS §2.3, §5 and §15 vs MIT (attorney).

## 8. Automation safeguards
- **ManOS:**
  - Off at launch.
  - Physical mouse wins.
  - ⌃⌥⌘H kill switch.
  - Stall watchdog.
- **OculOS:**
  - Dwell off at every launch.
  - 1.5° snap, avoiding dialogs.
  - Esc and ⌃⌥⌘E.
  - Visible ring.
- **Murmur:**
  - Four-key chord, no wake word.
  - Sanitized output and no synthesized Return.
  - Secure-input handling.
- **Meetings:**
  - Click-only start.
  - Consent every time.
  - Non-closable banner with a 30-minute reminder.
  - No stealth, scheduler or scripting.

## 9. Documentation

| Document | State |
|---|---|
| TERMS.md | Draft, with placeholders (seller name, contact, address, devices per key, and more) |
| PRIVACY.md | Live; needs contact and date |
| TRADEMARKS.md, CONTRIBUTING.md, SECURITY.md, THIRD_PARTY_NOTICES.md, LICENSE | Exist; LICENSE holder is a placeholder |
| Missing | Biometric/health-data statement for WA/CO, GDPR notice (or a US-only decision), export memo, recording-consent help page, SBOM |

## 10. Priority plan

**P0, before the first sale:**
- Consent gate, voiceprint opt-in, banner, key-free source builds, Gumroad-error safety, entitlements and notices, PRIVACY matching the code: **DONE**.
- TERMS placeholders and banner removal: **OWNER + ATTORNEY**.
- Gumroad refund setting: **OWNER**.
- Notarization, or an interim disclosure: **OWNER**.
- Push `.github/`: **OWNER** (`gh auth refresh -s workflow`).

**P1:**
- Done: dictation audio off by default, Delete All, crash orphans, retention, 0700 folders, indicators.
- **OPEN:**
  - Cloud prompt for note summaries (`Murmur/Sources/MurmurUI/AppModel.swift`).
  - Intel decision (`release.yml` `UNIVERSAL`).
  - Price in release notes.
  - Version-pinned Terms and Privacy URLs (`License.swift`).
  - Run the voiceprint sweep at launch, not only when Meetings opens (`MeetingKit/Sources/MeetingKit/Storage.swift`).
  - Copyright holder, trademarks, TERMS vs MIT, EU decision: **OWNER/ATTORNEY**.

**P2:**
- Pin the FluidAudio registry.
- Editor-terminal newlines.
- Delete All error reporting.
- Revocation reason shown to the user.
- `package.sh` assertions: notices, entitlements, bundle guard, checksum computed last.
- ScanCode scan.

**P3:**
- Kill-switch semantics, flick modifiers, the clipboard edge cases, and the other items listed in `legal/redteam/`.

## 11. Pre-release checklist
- [ ] Decide on an LLC: yours, or your father's after his accountant or attorney reviews it.
- [ ] Choose new names after a clearance search (candidates in `legal/research/15*`).
- [ ] Fill the TERMS/PRIVACY placeholders; attorney review; remove the banner.
- [ ] Set the LICENSE holder line.
- [ ] Pin the Terms/Privacy URLs to a tag.
- [ ] Decide arm64-only vs Intel, and make README, Gumroad and CI agree.
- [ ] Release notes: price, Gumroad link, checksum.
- [ ] Run `gh auth refresh -s workflow`; push `.github/`; create the `release` environment.
- [ ] Developer ID: sign, notarize, staple, compute the checksum last, then `spctl`.
- [ ] Rebuild the DMGs and re-verify them.
- [ ] Gumroad: payout, support email, refund setting, Terms field.
- [ ] Read Gumroad's Terms before 2026-10-14.
- [ ] Attorney sign-off.
- [ ] Publish; test with a 100%-off code.

## 12. Questions for an attorney
1. Developer liability for a local-only meeting recorder under c.272 §99 ("aid"), CA PC 631 and 18 USC 2512, and how much the consent gate and banner help.
2. Whether the Terms (post-payment clickwrap) are enforceable under Kauders and Good, and whether Gumroad checkout needs its own assent.
3. c.106 §2-316A and the 93A limits on the disclaimer and the liability cap.
4. Whether a key-gated EULA is coherent on an MIT binary.
5. Developer status for on-device voiceprints and eye data (BIPA after G.T., MHMDA, CO, CT), and whether a checkbox is an adequate BIPA release.
6. LLC (own vs. father's) and insurance: order and proportionality.
7. US-only launch vs. EU duties (AI Act, CRA, consumer withdrawal).
8. Trademark severity for all four names.
9. Gumroad §19: arbitration opt-out, and the uncapped indemnity.
10. "Load Model…" and Gaze360 secondary liability.
11. DPLA §3.3.1(C) and the license-key model.
12. CA AB 1043 and TX SB 2420 reach.
13. For a CPA: MA DOR registration, income tax and estimated payments.

## Owner to-do
1. Connect a Gumroad payout; set the support email, the 30-day refund policy and the Terms field.
2. Fill the TERMS.md and PRIVACY.md placeholders, and make the LICENSE holder line consistent.
3. Decide on an LLC and insurance.
4. Decide on names (see `legal/research/15*`).
5. Apple Developer account, then notarization.
6. Run `gh auth refresh -h github.com -s workflow` so `.github/` can be pushed.
7. Read Gumroad's Terms before 2026-10-14.
8. After publishing, get a test key via a 100%-off code.
9. Attorney review.
10. Publish.
