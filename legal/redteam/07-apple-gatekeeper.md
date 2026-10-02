# Red team 07: Apple reviewer / Gatekeeper engineer

Scope: Info.plist, entitlements, hardened runtime, notarization readiness, private APIs, DPLA, TCC, SF Symbols.
Repo state: commit 1f611aa plus working tree. Read-only review. Not a lawyer; nothing here is a clearance or a "compliant" finding.
Ranked, highest first. L/M/H = low/medium/high.

## What I checked (evidence)

- `codesign -dvv --entitlements -` on `{Humanity,ManOS,Murmur,OculOS}/build/*.app` and on the apps inside `dist/*-1.0.0.dmg` (mounted read-only).
- The four `Resources/Info.plist` files and the entitlement generator in each `scripts/build-app.sh`.
- `scripts/package.sh`, `.github/workflows/release.yml`, `Permissions.swift`, `LicenseKit/License.swift`.
- Greps for private API, Apple-event, and event-tap symbols.
- `strings` on the shipped Humanity binary for local paths.

## Verified clean (no finding)

- **Private APIs:** no `dlopen`, `dlsym`, `@_silgen_name`, `CGS*`, `_AX*`, `MultitouchSupport`, `NSAppleScript` or `osascript` in any app source (grep over all `.swift`, `.sh`, `.py` outside `.build`, `build` and `research`). Calls are public: AX, CGEvent, ScreenCaptureKit, `AudioHardwareCreateProcessTap`, Carbon `IsSecureEventInputEnabled`. No `CGEvent.tapCreate`, so Input Monitoring is not needed.
- **Hardened runtime:** all built and DMG apps show `flags=0x10002(adhoc,runtime)`. No `get-task-allow`, no sandbox, no `cs.*` exceptions. `codesign --verify --deep --strict` passes. No nested code. Binaries are arm64-only.
- **Usage strings:** each app's string matches the APIs it uses.
  - Camera string: Humanity, OculOS, ManOS.
  - Microphone, speech and audio-capture strings: Humanity and Murmur.
  - Murmur has no camera string and no camera code.
  - The Humanity audio-capture string no longer names "Murmur" (fixed since the checklist).
  - No `NSAppleEventsUsageDescription` is needed.
  - No undocumented `NSScreenCaptureUsageDescription` is present.
- **Local paths:** the shipped `dist/Humanity-1.0.0.dmg` binary has 0 hits for `taylorpan`.
- **App icons:** all `make-icon.swift` files draw custom geometry with `NSBezierPath` and `NSGradient`. There is no `NSImage(systemSymbolName:)` in icon code. SF Symbols are used only in the UI (about 98 `Label`/`Image(systemName:)` sites), which Apple allows.

## Findings

### 1. The current `dist/` DMGs and `build/*.app` still carry the old over-broad entitlements. Likelihood H, impact M
- **Scenario:** `scripts/build-app.sh` (mtime Oct 1 00:29) now generates per-app entitlements. The artifacts were built earlier.
  - Every `build/*.app` and every app in `dist/*.dmg` I mounted carries both `device.camera` and `device.audio-input`.
  - That means OculOS and ManOS hold audio-input, and Murmur holds camera, with no matching usage string.
  - The `dist/*.sha256` files also describe these stale builds.
  - If these DMGs are uploaded to Gumroad, the shipped product contradicts the "only the devices this app uses" comment in `build-app.sh` and the privacy story.
- **Mitigation:** the script fix (`OculOS/scripts/build-app.sh:51`, `Murmur/scripts/build-app.sh:51`, `Humanity/scripts/build-app.sh:51`; ManOS inherits camera-only). `.github/workflows/release.yml` rebuilds from scratch.
- **Remaining risk:** the manual upload path (`scripts/package.sh` output in `dist/`) can ship stale files. Nothing asserts the entitlements after signing.
- **Fix:**
  1. Rebuild all four with `scripts/package.sh <App> 1.0.0` and regenerate the checksums.
  2. Add to `scripts/package.sh`, after the build: `codesign -d --entitlements - --xml "$APP_DIR/build/$APP_NAME.app"` plus a grep-based assertion per app (OculOS and ManOS: camera only. Murmur: audio-input only. Humanity: both).
  3. Add the same step to `release.yml`.

### 2. Notarization is not achievable with the current signing path. Gatekeeper rejects the app. Likelihood H, impact H
- **Scenario:** `spctl -a -vv Humanity/build/Humanity.app` returns `rejected`. The DMG apps are `Signature=adhoc` with `TeamIdentifier=not set` and no timestamp.
  - `release.yml:52` signs with a self-signed "Humanity Self-Signed" identity when the secret exists. Notarization rejects self-signed and ad-hoc identities, so that path can never notarize.
  - Every ad-hoc update has a cdhash designated requirement, so users lose Accessibility and Screen Recording grants on each update. The README and release notes must say this.
  - Unnotarized, quarantined apps on macOS 15, 26 and 27 need the Privacy & Security trip and an admin password. A "paid" product that most buyers cannot launch drives refunds, which Gumroad lets buyers file for 30 days.
- **Mitigation:** the 5-step Open Anyway copy on the product page. `PIN_DR=0` for shared builds (`package.sh`). `build-app.sh` adds `--timestamp` for real identities.
- **Remaining risk:**
  - `spctl` shows `rejected` today.
  - The DMG itself is unsigned.
  - There is no `notarytool` or `stapler` step.
  - The "Notarization ready" claim can only be made after enrollment.
- **Fix:**
  1. Enroll in the Apple Developer Program and use a Developer ID Application identity.
  2. In `release.yml`, add DMG signing, `xcrun notarytool submit --wait`, `stapler staple`, and `spctl --assess` checks. These match `legal/RELEASE-CHECKLIST.md` A9.1 steps 8-12.
  3. Until then, keep the Open Anyway steps and the "grants reset after each update" line on the product page.
- **Attorney:** none for this point. It is an engineering and consumer-expectation issue.

### 3. SF Symbol used as the app's menu bar identity glyph. Likelihood M, impact L-M
- **Scenario:** `Humanity/Sources/Humanity/HumanityApp.swift:551-554` renders the idle menu bar icon as the SF Symbol `figure.arms.open`.
  - The same view shows `hand.point.up.left.fill`, `waveform.circle.fill` and `record.circle.fill` as state glyphs.
  - Apple's SF Symbols license (as I understand it, not verified against the current text) bars using symbols in app icons, logos or trademark-like branding.
  - The menu bar glyph is effectively the product's logo, and the Dock/Finder icon is separately custom drawn.
  - `Permissions.swift:28-32` and the Settings tabs use symbols as ordinary UI, which is fine.
- **Mitigation:** the `.icns` is custom and has no symbols.
- **Remaining risk:** a reviewer could treat the always-visible menu bar icon as a logo.
- **Fix:** ship a custom template image asset for the idle brand state and keep SF Symbols only for transient state indicators. Alternatively, have counsel confirm the license text (attorney item).
- **Attorney:** confirm SF Symbols license wording.

### 4. Names that sit close to Apple and Meta marks. Likelihood M, impact M-H
- **Scenario:** "ManOS" is one letter from "macOS". "OculOS" and "ManOS" follow the "...OS" pattern. Apple's trademark guidelines (summarized in `RELEASE-CHECKLIST.md` A8) forbid "variations, takeoffs or abbreviations" of its marks. "OculOS" also sits near OCULUS (Meta; and an eye-device company, see `LEGAL-COMPLIANCE.md` 2.26).
  - The apps are sold from Gumroad, with a public GitHub repo.
  - Apple routinely sends notices to developer-program members and to hosting platforms.
- **Mitigation:** the README disclaimer (`README.md:70-71`): not affiliated with Apple, and "Mac and macOS are trademarks of Apple Inc."
  - `TERMS.md:146` reserves the names.
- **Remaining risk:** the disclaimer does not cure a similar-mark problem. `TERMS.md:147` points to `TRADEMARKS.md`, which does not exist in the repo (confirmed with `ls`). The open-source audit lists it as an open to-do.
- **Fix:**
  1. Create `TRADEMARKS.md` now, or delete the reference in `TERMS.md:147`.
  2. Run a clearance search and decide on renames before spending on marketing.
  3. The cheap hedge is to keep the umbrella name (Humanity) most prominent on the Gumroad page and add the Apple credit line there too.
- **Attorney:** yes, trademark clearance and Apple/Meta risk assessment.

### 5. DPLA terms: license-key unlocking and "Apple checked this" claims. Likelihood L-M, impact M
- **Scenario:** the DPLA is binding only once enrolled, and enrollment is needed for item 2.
  - §3.3.1(C) as summarized in `RELEASE-CHECKLIST.md` A7 bars unlocking features through distribution mechanisms outside the App Store without Apple's approval. Its scope against Developer ID software is ambiguous. `License.swift` gates the whole app (`required = true`, Gumroad `verify`).
  - §5.3 bars saying Apple reviewed, approved or security-checked a notarized app. The product page and release notes must never say "notarized, so it's safe".
  - The copy says "Not a medical or assistive device" while the README describes control by eyes and hands, which will draw accessibility-adjacent reading. That is a marketing-claims issue, not a DPLA one.
- **Mitigation:** `License.swift:7-8` has a kill switch (`required`) that can make every app free. Terms text states license mechanics.
- **Remaining risk:** no written position on §3.3.1(C).
- **Fix:** a one-line release note rule ("never say Apple approved or checked it") in `legal/RELEASE-CHECKLIST.md`. Get counsel to read §3.3.1(C) against the license model before enrolling.
- **Attorney:** yes, DPLA §3.3.1(C) and §5.3 reading.

### 6. Recording indicator coverage (DPLA §3.3.3(A) and consumer-consent). Likelihood M, impact M
- **Scenario:** meeting capture records other people's audio through a Core Audio tap, not the mic, so macOS shows only its generic system-audio indicator.
  - Humanity: the menu bar icon becomes `record.circle.fill` while meeting recording is on (`HumanityApp.swift:551`).
  - Standalone Murmur: I found no menu bar item. It relies on `Views/HUD.swift`, a floating panel. I did not verify it stays visible for the whole meeting, or after a window loses focus.
  - Standalone OculOS and ManOS use the camera and get the system green dot.
- **Mitigation:** `legal/RECORDING-CONSENT-UX.md`, the PRIVACY.md consent warning, and the Humanity menu bar state.
- **Remaining risk:** the Murmur-only path may lack an always-visible indicator. If the HUD can be hidden, DPLA §3.3.3(A) (as summarized in the checklist) is arguably unmet, and so is a "reasonably conspicuous" indicator under wiretap-statute advice in the legal docs.
- **Fix:** confirm in `Murmur/Sources/MurmurUI/Views/HUD.swift` and `AppModel.swift` that the HUD or a menu bar item stays up for the full recording. If not, add an `NSStatusItem` while recording.
- **Attorney:** the sufficiency of the indicator is part of the recording-consent review.

### 7. TCC: `tccutil reset` and grant churn. Likelihood M, impact L
- **Scenario:** `Permissions.swift:116-128` runs `/usr/bin/tccutil reset <Accessibility|ScreenCapture> <own bundle id>` from a "stale entry" button, then re-requests.
  - `tccutil reset SERVICE BUNDLE_ID` with the app's own id is a documented command, scoped to Humanity's entry. It is not a private API and not a modification of system or security settings outside the app's own record.
  - The `Accessibility` reset also clears PostEvent grants for that bundle id. Users clicking it will re-grant, which is expected.
  - The designated requirement on ad-hoc updates changes every release (item 2), so this button will be needed constantly. A reviewer could read frequent resets as "app fighting TCC".
  - Screen Recording on macOS 15 and later re-prompts periodically for apps using ScreenCaptureKit directly (`MeetingKit/Capture/ScreenCaptureAudio.swift`, `OculOS/.../ScreenshotCapture.swift`). That prompt cadence is Apple-controlled. It is reported in press, not documented, so treat it as a test item.
- **Mitigation:** the reset is user-initiated, own-bundle only, and the action is labelled. Screen Recording is optional (`Permissions.swift:47`).
- **Remaining risk:** the in-app copy does not say that a reset removes the existing grant. Standalone Murmur has no UI to grant the Screen Recording fallback.
- **Fix:** add one line to the button's help text: "Removes Humanity's existing grant, then asks again." Stable signing (item 2) removes most need for it.

### 8. Dev builds leak the home path; do not hand-upload `build/` output. Likelihood L, impact L
- **Scenario:** `strings` on `Humanity/build/Humanity.app/Contents/MacOS/Humanity` shows `/Users/taylorpan/Cloud/Humanity/Humanity/.build/.../FluidAudio_FluidAudio.bundle` (a SwiftPM resource-bundle path baked into the binary). The shipped DMG has none. Release builds use `SCRATCH`, so only a local build copied by hand would leak it.
  - The Rust static library inside FluidAudio's `NemoTextProcessing` also embeds `/Users/runner/.cargo/...` paths, which are harmless.
  - `FluidAudio_FluidAudio.bundle` is not copied into the `.app`. Only the TTS code paths use `Bundle.module` (`LuxTtsG2p.swift`), which the suite does not appear to call. I did not run the app to confirm.
- **Mitigation:** `SCRATCH` in `build-app.sh` and in the release workflow. The shipped DMG is clean.
- **Fix:** make `package.sh` pass a `/tmp` `SCRATCH` by default, and add `strings ... | grep "$HOME"` to the same post-build check as item 1.

### 9. Apple marks used in copy and UI: referential, but a few spots are loose. Likelihood L, impact L
- **Scenario:**
  - `TERMS.md:87` says "Apple Intelligence frameworks". The shipping framework is Foundation Models. "Apple Intelligence" is Apple's mark and the phrase is slightly inaccurate.
  - UI and docs name FaceTime (`AudioApps.swift:64`), "Apple's on-device recognizer" (usage strings), and "macOS" throughout. These are nominative and referential uses and look acceptable.
  - Using "macOS" as part of a product name or as a noun with a possessive would not be. I found no such use in the plists, `README.md`, or UI strings. The Gumroad page copy is outside the repo, so re-check it.
- **Mitigation:** the README credit line.
- **Fix:** reword `TERMS.md:87` to "Apple's on-device speech and Vision frameworks, and Apple's on-device language model where available". Add the full credit line ("Mac and macOS are trademarks of Apple Inc., registered in the U.S. and other countries and regions.") to the Gumroad page.
- **Attorney:** include in the trademark review (item 4).

### 10. Version and metadata hygiene for notarization. Likelihood M, impact L
- **Scenario:**
  - Source `Info.plist` files hold `CFBundleVersion` = `1`. `build-app.sh` rewrites both version keys to `$VERSION` only when `VERSION` is set. `package.sh` with no version produces the invalid string "dev" in the DMG name, and `CFBundleShortVersionString` is left alone. The workflow's regex enforces `X.Y.Z` for tags, but a manual `package.sh` run has no check.
  - `CFBundleVersion` is a dotted string equal to the short version, not a monotonically increasing build number. This works but is non-standard.
  - There is no `NSHumanReadableCopyright` key.
- **Mitigation:** the `X.Y.Z` regex in `release.yml:30-31`.
- **Fix:** in `package.sh`, `[ -n "$VERSION" ] || { echo "version required"; exit 1; }` with the same regex. Add `NSHumanReadableCopyright` to the four plists (the About window will show it).

### 11. Shared storage and bundle-id layout across the suite. Likelihood L, impact L
- **Scenario:** bundle ids are `io.github.pikabrofar.humanity`, `...humanity.ManOS` and so on. They use a GitHub-handle reverse-DNS namespace the author does not own as a domain, which Apple does not check for Developer ID.
  - All apps share `~/Library/Application Support/Humanity/license.json`.
  - Humanity and the standalone apps are separate TCC identities, which `Permissions.swift:172` tells users.
  - Nothing here blocks notarization.
- **Fix:** none required. Consider a domain-based id before the first notarized release, because changing bundle ids later also resets every user's TCC grants.

### 12. Hardened-runtime and entitlement gaps to retest once notarized. Likelihood L, impact M
- **Scenario:** Core ML, Vision, FoundationModels, FluidAudio and the Rust static lib currently run under the runtime with no JIT or library-validation exceptions. Not verified: I did not launch the apps. A first notarized build is the point where a missing `disable-library-validation`, `allow-jit` or `allow-unsigned-executable-memory` need would show up as a crash.
- **Mitigation:** none needed so far. The ad-hoc runtime-flagged build is built and signed under the same hardened rules.
- **Fix:** the checklist's A9.1 launch test on a clean macOS 15, 26 and 27 machine for each app (camera, dictation, meeting capture, model download), before adding any entitlement. Add an entitlement only if a crash log requires it, and only for the app that needs it.

## Attorney items

- Trademark clearance and Apple/Meta risk for ManOS, OculOS (item 4), plus the SF Symbols license wording (item 3).
- DPLA §3.3.1(C) vs license-key model, and §5.3 marketing limits (item 5).
- Sufficiency of the recording indicator, especially standalone Murmur (item 6).

## 5-line summary

1. Stale artifacts: the `dist/` DMGs and `build/*.app` still ship camera plus audio-input in all four apps, though `build-app.sh` now sets per-app entitlements. Rebuild and assert entitlements in `package.sh` and CI.
2. Gatekeeper `rejected` is expected for ad-hoc builds. Notarization needs Developer ID, DMG signing, and notarytool/stapler steps. The self-signed CI path can never notarize.
3. No private APIs, no Apple-event use, hardened runtime on, no `get-task-allow`. Usage strings match each app's APIs. `tccutil reset` is own-bundle only.
4. Attorney items: ManOS/macOS and OculOS/Oculus naming, `TRADEMARKS.md` referenced in `TERMS.md:147` but missing, DPLA §3.3.1(C), SF Symbol as menu bar brand glyph.
5. Gaps to verify: Murmur-only recording indicator, version and copyright metadata, a post-notarization launch test for runtime exceptions, and keeping `build/` copies (home path in binary) off Gumroad.
