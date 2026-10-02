# Red team 06: open-source maintainer / license purist

Not legal advice. Nothing here says the project is "safe" or "compliant". Reviewed at commit 1f611aa against current files. Read-only review. Items marked ATTORNEY need counsel.

Sources read: LICENSE (root and OculOS), TERMS.md, README.md, THIRD_PARTY_NOTICES.md, LicenseKit/Sources/LicenseKit/License.swift and ActivationWindow.swift, the four *App.swift entry points, .github/workflows/release.yml, legal/OPEN-SOURCE-AUDIT.md, legal/research/09-trademarks.md. Web: GitHub Acceptable Use Policies and GitHub anti-circumvention (DMCA) policy, fetched 2026-10-01.

## Ranked findings

### 1. TERMS and README say "build from source with no key"; the source does not do that (L: H, I: H)
- Scenario: a purist builds with `make run`, as the README says to. `License.required` is hard-coded `true` (License.swift:7). Every app calls `License.requireActivation` at launch (OculOSApp.swift:11 and the Humanity, ManOS, Murmur equivalents). The source build asks for a key and quits without one. TERMS §2.1 states "You may build Humanity from source, without a Key, at no charge", and §2.2 states the payment "is not a fee for the source code". Both are false as the code stands. The README's "open-source ... Install" section also says nothing about this. Someone will post "the open-source app is key-locked, and the Terms misstate that". For a paid product that is a misrepresentation claim (M.G.L. c. 93A, FTC §5) and a trust hit. It also invites forks, which feeds finding 2.
- Mitigation: TERMS §2.5 and §14 say MIT rights are unaffected. Nothing in code supports the "no key" claim. The only hint is the comment at License.swift:6.
- Remaining risk: the statement is untrue today, and this is the most checkable claim in the package.
- Fix (pick one):
  - (a) Make it true. Read `required` from a compile flag (`#if HUMANITY_OFFICIAL_BUILD`), set only by scripts/package.sh and release.yml. Then `make run` builds are key-free.
  - (b) Reword TERMS §2.1/§2.2 and the README to "the source is MIT; to run it you must remove or change the one-line check at LicenseKit/.../License.swift:7". Say it plainly.
- ATTORNEY: whether (b) is acceptable wording under 93A.

### 2. Gumroad copy plus Terms plus a one-line bypass, and GitHub's AUP on "bypassing checks" (L: M, I: H)
- Scenario: GitHub's Acceptable Use Policies bar content that "unlawfully shares unauthorized product licensing keys, software for generating unauthorized product licensing keys, or software for bypassing checks". GitHub's anti-circumvention policy says that for those cases its normal circumvention review "does not apply", so handling is fast. The check here is public. Any fork or PR that sets `required = false` is, on a literal reading, "software for bypassing checks". The word "unlawfully" is the defense: MIT expressly allows modification and redistribution, and TERMS §2.1/§2.5 concede that. But a GitHub reviewer or a third-party complaint will not parse that. Two risks follow:
  - (i) The owner (or Gumroad) files an AUP complaint against forks and contradicts the "MIT, not restricted" promise.
  - (ii) The owner's own repo is flagged, or a fork is flagged by a third party, because the repo documents the flip.
- Mitigation: legal/OPEN-SOURCE-AUDIT.md §5 says do not invoke DMCA §1201. TERMS §2.5 says redistribution of MIT source is not restricted. Neither is in a public-facing file about enforcement.
- Remaining risk: no stated policy on what the maintainer will and will not report. Keys in issues or PRs have no handling rule. The `productID` constant is public, but it is only an identifier and not a secret. Gumroad verification needs no secret, so there is nothing to leak, but there is also nothing preventing a fake-server patch.
- Fix:
  - Add a short "Licensing and enforcement" section to README or a new TRADEMARKS.md: "We will not use takedowns or §1201 against modified MIT source. We act only on posted real keys and on unauthorized use of our names." Keep it consistent with TERMS §2.4/§14.
  - Add SECURITY.md or CONTRIBUTING.md text: "Do not post license keys in issues. Do not submit key generators."
  - Do not file AUP reports against forks that only edit the check.
- ATTORNEY: whether the Terms' "do not publish, sell or share [a Key]" (§2.4) plus the check's visibility leaves any enforceable control beyond contract.

### 3. TERMS §2.3 licenses the "Official Apps" separately and restricts them; MIT already covers the compiled app (L: M, I: H)
- Scenario: MIT grants rights in the "Software" and "copies". Compiled output of an MIT source tree is a copy of the Software under the normal reading, and the DMG ships `Resources/LICENSE` (build-app.sh:42). TERMS §2.3 grants only a "non-exclusive, worldwide, non-transferable license ... on Macs that you own or control", with "[one person / up to N Macs]" still in brackets. That contradicts the MIT right to redistribute and sublicense the same binary. §2.5 half-resolves this ("We do not restrict copying or redistributing the free DMG"), but §2.3 and §2.5 still say opposite things about the same file. Further, §5 (acceptable use: no surveillance, covert recording) and §14 (we may deactivate a Key for "material breach of §5") are field-of-use restrictions. They are fine as contract terms for a key, but they are not compatible with calling the binary itself open source (OSD #6: no discrimination against fields of endeavor). A purist will say "MIT with a field-of-use EULA is not MIT". Also §15 says "We and our contributors keep all rights not expressly granted", which cannot bind contributors who only granted MIT (see finding 6).
- Mitigation: TERMS §2.1 and §14 say MIT rights are not affected. §3 ("the open-source license controls for that component") covers third-party components only.
- Remaining risk: an internal contradiction that a reader can quote. Practical effect: the Terms could be read as a contract on the key service plus a use-license on a build that cannot be restricted anyway.
- Fix (TERMS.md):
  - Reframe §2.3 as "the Key unlocks the Official Apps' license check and gives you our support and updates", and say the app code is licensed under MIT, independent of the Key.
  - Move §5 acceptable-use items to "conditions of holding a Key and receiving support" and say they do not limit MIT rights in the code.
  - Delete "non-transferable" and "Macs you own or control", or limit them to the Key.
  - Rewrite §15 to say "we hold copyright in the code we wrote; contributors keep theirs under MIT".
- ATTORNEY: yes. This is the central drafting issue.

### 4. Trademark: dead reference, weak clearance, and a prior same-name open-source project (L: M, I: M-H)
- Scenario A: TERMS §15 and §2.5 point to `TRADEMARKS.md`, which does not exist (confirmed: no such file in the tree). Forks have no stated rules, and the Terms cite a missing file.
- Scenario B: "OculOS" is the name of an existing MIT project by huseyinstif (Rust desktop-control daemon; legal/research/09-trademarks.md §3.1), and also one letter from OCULUS (Meta). Humanity's OculOS is a different product but the same name and platform, sold for money. The OculOS/ directory also appears to have an earlier standalone repo (pikabrofar/oculOS) that the research notes treat as the same codebase. A license purist's first question is "is this a fork or a name collision"; the repo does not say.
- Scenario C: "Murmur" is also the name of Mumble's open-source server (common law) and of several live Mac/iOS dictation apps; the research rates it HIGH. ManOS is one letter from macOS (RELEASE-CHECKLIST A8). The README line "Mac and macOS are trademarks of Apple Inc." covers Apple only.
- Scenario D: other projects' names used descriptively are fine (FluidAudio, pyannote, WeSpeaker, Groq, OpenAI, Anthropic, Gemini appear as provider or component names). I found no use of a competitor's name as a product name or in marketing in the README or code. The risk is only that the Gumroad page not add "alternative to X" copy.
- Mitigation: legal/OPEN-SOURCE-AUDIT.md §5 recommends TRADEMARKS.md (unchecked in §7). legal/research/09-trademarks.md rates every name MEDIUM or higher.
- Remaining risk: the Terms assert trademark rights ("The names ... are not licensed by MIT") over marks that a prior user or Meta may hold. Asserting marks you may not own, while telling forkers to rename, is the kind of thing that draws a counter-letter.
- Fix:
  - Create TRADEMARKS.md with the audit's text (forks must rename and re-icon, no implied endorsement, nominative use allowed) and say "we make no claim of registration".
  - Add a line to OculOS/README.md saying the app is unrelated to huseyinstif/oculos and to Meta's Oculus.
  - Keep Gumroad copy free of competitor names and of "Apple-compatible" implications.
- ATTORNEY: yes. Name clearance for all four names (already flagged in legal/LEGAL-COMPLIANCE.md).

### 5. Copyright holder is "Humanity contributors"; no contributor policy; AI co-authorship (L: M, I: M-H)
- Scenario: both LICENSE files read "Copyright (c) 2026 Humanity contributors". The OPEN-SOURCE-AUDIT (item 5) flagged this and it is not fixed (OculOS/LICENSE was changed to match the root, so they are identical now, but both still name no legal person). "Contributors" is not an entity that can grant a license, sell a key, or relicense. The git history shows one human author (pikabrofar), and per the audit most commits carry a Claude co-author trailer. The Terms are signed by "[SELLER LEGAL NAME / DBA]", which is still a placeholder. A purist cannot tell who the licensor is.
- Mitigation: the audit explains the problem; nothing in the tree resolves it.
- Remaining risk: unclear licensor for MIT, for Terms, and for any future relicense or takedown. AI-assisted code may have thinner copyright (the audit cites USCO guidance); that weakens enforcement of anything but the trademark.
- Fix (LICENSE and OculOS/LICENSE): `Copyright (c) 2026 [LEGAL NAME / DBA] and Humanity contributors`, identical in both, and the same name in TERMS §1. Keep the notice in the app bundle (already done by build-app.sh:42).
- ATTORNEY: low. Mostly a fill-in, but the DBA and any LLC decision belong to counsel.

### 6. No contributor policy; GitHub ToS inbound=outbound is the only rule (L: M, I: M)
- Scenario: no CONTRIBUTING.md, no DCO, no CLA, no CODE_OF_CONDUCT (confirmed absent). The Terms speak of "our contributors". Under GitHub ToS §D.6, a contribution to a repo is licensed under the repo license, so an outside PR is MIT in. That is workable, but then:
  - the seller cannot relicense later without contributor consent, and Terms §15's "our contributors keep all rights not expressly granted" is wrong for them;
  - a contributor could submit a patch that removes or weakens the license check, or adds third-party code with an incompatible license, with no screening policy;
  - the paid binary will include contributor code, so a contributor could in theory demand an accounting or object to sale (MIT allows sale, so low risk).
- Mitigation: none in the repo. The audit recommends a DCO (checklist line unchecked).
- Remaining risk: unmanaged provenance, especially for AI-generated patches and snippets from other projects.
- Fix: add CONTRIBUTING.md (a few lines): MIT in/MIT out; sign-off per DCO (`Signed-off-by`); no third-party code without a license listed in THIRD_PARTY_NOTICES.md; no keys, key generators, or check-bypass changes; maintainers may decline any PR. Add a CI job that checks for sign-off. If dual-licensing is ever possible, use a CLA instead. ATTORNEY: choose DCO vs CLA.

### 7. Does a public-source key check plus Terms hold together? (L: M, I: M)
- The structure works only as honest convenience pricing, and the docs say so in places (TERMS §2.2, audit §5). It stops holding together where:
  - the README says "the apps need a paid license key to run" while also saying MIT (README line 24-27) without telling the reader the check is removable (see finding 1);
  - the activation window presents one clickwrap for the whole suite (ActivationWindow.swift, "I agree to the Terms of Sale") for a binary that is also freely redistributable;
  - License.swift enforces "no" only on refund/dispute (`refunded`, `chargebacked`, `disputed`), which matches TERMS §9.3. It does not enforce device count (`increment_uses_count` is only a counter), so TERMS §2.3's "[one person / up to N Macs]" cannot be applied by the app at all.
  - Terms §10 promises a key-free release if sales stop or Gumroad verification fails. `required` is a constant, so this is possible, but there is no committed mechanism (for example a documented release branch).
- Mitigation: TERMS §2.5, §10, §14. Audit §5.
- Remaining risk: promises the app cannot enforce, plus a promise in §10 that is not tied to anything checkable.
- Fix: in TERMS §2.3 replace "[one person / up to N Macs]" with wording that matches what the check does, or add a device cap via Gumroad `uses`. Add to README a three-line "Licensing" section that says: source is MIT; official builds need a key; you may remove the check in your own build. State the §10 commitment in README.

### 8. Third-party notices: improved, with remaining gaps (L: L-M, I: M)
- Verified present in THIRD_PARTY_NOTICES.md at 1f611aa: FluidAudio, VBx, fastcluster, the NemoTextProcessing NOTICE text (Apache §4(d)), the Japanese G2P ports, and the "applies to Humanity and Murmur only" line. The prior audit's main gaps (findings 2 and 7) are therefore addressed in text.
- Still open per the audit and not checked off: the MIT-only Rust crates (nom, generic-array, ordered-float, simd-adler32) and Rust std notice; no ScanCode run is recorded; no CI check that `FluidAudio_FluidAudio.bundle` is absent (espeak-ng-derived data, GPL-adjacent); the Gaze360 weights warning is only in TERMS §5.6 (a user-run script, not shipped). I did not re-run the binary inspection; verify against the shipped DMG, not the tree.
- TERMS §3 lists the components in a shorter list than the notices file, and says the diarization models are licensed by "Fluid Inference, pyannote and BUT Speech@FIT", which is fine. The point to watch is TERMS §3's sentence "the open-source license controls", which is right and should stay.
- Fix: paste the MIT-only crate block from audit §3.3; run `scancode` on the repo and FluidAudio checkout and attach output to the release; add the CI bundle check. No attorney needed.

### 9. App icons from SF Symbols (L: M, I: L-M)
- Audit finding 1 says three app icons (Humanity, ManOS, Murmur) are drawn from SF Symbols, which Apple's terms bar from app icons and logos. I did not re-verify whether 1f611aa redrew them; check `*/scripts/make-icon.swift` before release. This also weakens the trademark position in finding 4, since a trademark owner cannot claim an icon that is Apple's artwork.
- Fix: redraw as original vector art (as OculOS does), rebuild AppIcon.icns, and mention in TRADEMARKS.md that icons are covered.

### 10. GitHub ToS and AUP: other points (L: L, I: M)
- GitHub AUP prohibits content that "infringes any proprietary right ... including ... trademark" and impersonation. A third party with a Murmur or OculOS mark (finding 4) could file a trademark complaint against the repo, and GitHub can act on it. The repo carries the commercial release pipeline (release.yml publishes DMGs), so a takedown would stop distribution of the free download that the paid key unlocks.
- Releases publish unnotarized, ad-hoc-signed binaries (release.yml). That is not an AUP violation, but the "Open Anyway" steps in the release notes will read to some reviewers as asking users to bypass Gatekeeper. Keep the wording factual ("not notarized yet") and keep the SHA-256 file (already present).
- Fix: keep a mirror or a second distribution path for the DMGs (Gumroad file delivery) so a repo takedown does not stop paying users. Keep a record of the Gumroad key list outside GitHub.

### 11. "Humanity contributors" in the notice shown to users vs sole-seller identity in Terms (L: L, I: L)
- The same name problem as finding 5, but visible to users in the About panel (Credits.rtf is built from LICENSE; build-app.sh:43). Fixing finding 5 fixes this. No separate change.

### 12. FluidAudio models and CC BY 4.0 "additional terms" (L: L, I: L-M)
- The audit §4 notes CC BY 4.0 §2(a)(5)(B): do not impose "additional or different terms" on the models. TERMS §3 and §14 exclude third-party components from restrictions ("Where these terms conflict with an open-source license, the open-source license controls"), and the apps fetch models from Hugging Face directly. Still, §5's acceptable-use list (voice profiles, surveillance) is written around the app, not the models, so the exclusion sentence should stay explicit that §5 does not restrict the model files.
- Fix: add to TERMS §3: "§5 and §14 apply to the Key and the Official Apps, not to third-party components or models." ATTORNEY: low.

## Attorney items, short list
1. Findings 3 and 7: whether a Key-gated EULA on an MIT-licensed binary is coherent, and how to word §2.3/§5/§15.
2. Finding 4: trademark clearance and whether to rename OculOS/Murmur/ManOS before launch.
3. Finding 5: legal name or DBA, LLC, who is licensor.
4. Finding 6: DCO vs CLA, plus AI-generated contribution policy.
5. Finding 2: statement of enforcement policy, given GitHub's "bypassing checks" AUP text.

## Order of fixes (fastest first)
1. Make Terms §2.1 true or reword it (finding 1).
2. Create TRADEMARKS.md and a short Licensing/Enforcement section (findings 2, 4).
3. Fill in the copyright line and seller name (finding 5).
4. Add CONTRIBUTING.md with DCO (finding 6).
5. Reconcile TERMS §2.3/§5/§15 with MIT (finding 3).
6. Notices and icons checklist (findings 8, 9).
