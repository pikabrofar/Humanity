# Release checklist: Apple distribution and Gumroad sales

Research date: **2026-10-01**. Written by a research engineer, not a lawyer. **This is not legal or tax
advice.** It summarizes official Apple and Gumroad sources and compares them with what this repo does
today. Before relying on any clause interpretation flagged below, have a lawyer or tax adviser review it.

How each claim is marked:

- **[Verified]**: read on the official page cited, fetched on 2026-10-01.
- **[Repo]**: checked directly in this repository or in the built DMGs in `dist/`.
- **[Unverified]**: Apple or Gumroad does not document it, or the only sources are third-party or
  Apple Developer Forums posts. Treat it as a test item, not a fact.

Freshness notes:
- The Apple Developer Program License Agreement (DPLA) page says it was **last updated August 18, 2026**.
- Gumroad's Terms page showed no "Last Updated" date in the fetched text, and help articles are undated.
  Their content was current as of the fetch date.
- Apple's Mac User Guide version picker lists macOS 15, 26 **and 27**, so macOS 27 is already a shipping
  target to test on.

---

## 0. Release blockers at a glance

| # | Finding | Where | Fix |
|---|---|---|---|
| 1 | Builds are ad-hoc signed. `spctl` rejects every app and the DMGs have "no usable signature". | [Repo] `dist/*.dmg` | Developer ID, then notarize, then staple (§A9) |
| 2 | `codesign` has no `--timestamp`. Notarization requires a secure timestamp. | [Repo] `*/scripts/build-app.sh` | Add `--timestamp` to Developer ID signing |
| 3 | The DMG is never signed. | [Repo] `scripts/package.sh` | `codesign --timestamp --sign "Developer ID Application: …" X.dmg` |
| 4 | `CFBundleVersion` is hard-coded to `1` and never bumped. | [Repo] all four `Info.plist`, build scripts | Stamp a monotonically increasing build number |
| 5 | `package.sh` defaults `VERSION=dev`, which writes the invalid `CFBundleShortVersionString` "dev". CI accepts 2-part versions such as `1.2`. | [Repo] | Require `X.Y.Z` (Apple: "three period-separated integers") |
| 6 | Every app gets **both** camera and audio-input entitlements from one shared file. | [Repo] `scripts/app.entitlements` | Per-app entitlements (§A3) |
| 7 | Humanity's `NSAudioCaptureUsageDescription` says "**Murmur** records the meeting app's audio…" | [Repo] `Humanity/Resources/Info.plist` | Change it to "Humanity …" |
| 8 | SHA-256 is computed before signing and stapling. Stapling modifies the DMG, so the published checksum would be wrong. | [Repo] `scripts/package.sh` | Compute the checksum last |
| 9 | "Apple silicon only" vs CI: `release.yml` sets `UNIVERSAL=1` (arm64 + x86_64), but the local `dist/` DMGs are arm64-only. | [Repo] | Pick one: ship arm64-only or drop the claim |
| 10 | The release notes describe the unnotarized flow in 3 steps. Apple's flow has more steps, including the admin password and a 1-hour window. | [Repo] `.github/workflows/release.yml` | Use the copy in §B10 |
| 11 | LicenseKit treats a **won** dispute (`disputed: true, dispute_won: true`) as invalid. | [Repo] `LicenseKit/Sources/LicenseKit/License.swift` | Accept `disputed && dispute_won` (§B4) |
| 12 | No Terms (end-user license), refund policy or seller privacy policy is linked from Gumroad. | Gumroad Terms §6.3, §11.2 | §B2, §B7 |

---

# Part A: Apple

## A1. Developer ID, code signing and notarization

**Official requirements [Verified]** (Apple, *Notarizing macOS software before distribution*;
*Resolving common notarization issues*; *Customizing the notarization workflow*):

- Developer ID software must be notarized: "Beginning in macOS 10.15, all software built after
  June 1, 2019, and distributed with Developer ID must be notarized."
- The notary service requires all of the following:
  - All executables signed, with a valid signature (`codesign -vvv --deep --strict` must pass).
  - A **Developer ID Application** certificate. Ad hoc, Mac Distribution, Apple Development and local
    certificates are explicitly not accepted. Apple's docs say to sign "Mach-O files, **disk images**,
    bundles, apps" with Developer ID Application.
  - Hardened Runtime enabled.
  - A secure timestamp (`codesign --timestamp`, served by `timestamp.apple.com`).
  - **No** `com.apple.security.get-task-allow` entitlement.
  - Linked against the macOS 10.9 SDK or later.
  - Entitlements as ASCII XML with no BOM.
- Tools:
  - `notarytool` and `stapler`. Since November 1, 2023 the notary service no longer accepts `altool`
    uploads or uploads from Xcode 13 and earlier.
  - Submit with `xcrun notarytool submit … --keychain-profile … --wait`, then read the log with
    `xcrun notarytool log <id>`. Apple says to check the log even on success.
  - Credentials can be an App Store Connect API key or an app-specific password stored with
    `notarytool store-credentials`.
- What can be notarized and stapled:
  - Accepted uploads: UDIF disk images, signed flat packages and ZIPs. You cannot upload a bare `.app`.
  - Tickets are generated for the top-level file **and nested items**.
  - `stapler staple` works on apps, bundles, disk images and flat packages, but not on ZIPs.
  - Gatekeeper can also find the ticket online. Stapling makes it work offline.
- Limits: most submissions finish within 5 minutes. Stay under 75 notarizations per day, and run
  `hdiutil verify` before uploading a DMG.
- Developer ID certificate: only the **Account Holder** can create it. You can have up to five
  Developer ID Application certificates. An app signed while the certificate was valid keeps running
  after it expires (Apple Account Help, *Developer ID certificates*).
- Membership costs **99 USD per membership year** (developer.apple.com/programs/enroll).

**Repo today [Repo]:**
- `build-app.sh` runs `codesign --force --options runtime --entitlements ../scripts/app.entitlements`
  with `SIGN_ID` defaulting to `-` (ad-hoc).
  - Without `--timestamp`.
  - Local builds pin the designated requirement to the bundle ID. Releases use `PIN_DR=0`.
- The `dist/` apps show `flags=0x10002(adhoc,runtime)`, `TeamIdentifier=not set`, and
  `designated => cdhash H"…"`. `spctl --assess --type execute` gives **rejected**.
- The DMGs are "not signed at all", `stapler validate` reports no ticket, and `spctl -a -t open
  --context context:primary-signature` gives **rejected, no usable signature**.
- CI can import a **self-signed** "Humanity Self-Signed" certificate. That keeps TCC grants stable
  across updates, but Gatekeeper still treats it as unidentified, so it is **not** a substitute for
  Developer ID.
- Good news for notarization:
  - Each app has a single Mach-O. `otool -L` shows no non-system dylibs or frameworks, so there is no
    nested code to sign first.
  - `notarytool` and `stapler` ship in the Command Line Tools on this machine
    (`/Library/Developer/CommandLineTools/usr/bin/`), so full Xcode isn't required to notarize.
    Apple's docs only say "included with Xcode".
- Side note: SwiftPM builds `FluidAudio_FluidAudio.bundle` (LuxTTS lexicon files), but `build-app.sh`
  never copies it into the app. FluidAudio only uses it for TTS, which MeetingKit doesn't appear to
  call. Confirm that before release, or copy the bundle into `Contents/Resources`.

**Needed:**
1. Enroll in the Apple Developer Program.
2. Create a Developer ID Application certificate.
3. Sign with `--options runtime --timestamp`.
4. Sign the DMG.
5. Notarize the DMG.
6. Staple it.

The full ordered steps are in §A9.

## A2. Gatekeeper behavior for ad-hoc and unnotarized downloads (macOS 15, 26, 27)

**[Verified]:**
- Apple Developer News, *Updates to runtime protection in macOS Sequoia* (Aug 6, 2024): "In macOS
  Sequoia, users will no longer be able to Control-click to override Gatekeeper when opening software
  that isn't signed correctly or notarized. They'll need to visit System Settings > Privacy & Security."
- Apple's Mac User Guide, *Open a Mac app from an unknown developer*, gives the same procedure for
  macOS 15, 26 and 27. **"Open Anyway" still exists** in all three:
  1. Try to open the app. macOS shows a warning and refuses to launch it.
  2. Open System Settings, go to **Privacy & Security**, and scroll to **Security**.
  3. Click **Open Anyway**. Apple says the button "is available for about an hour after you try to open
     the app."
  4. Enter your **login password**, then click OK.
  5. A second warning appears. Click **Open** (Apple Support article 102445).
- After that, "the app is saved as an exception" and opens normally afterwards.

**Step count:** five user actions after copying the app to Applications, including one admin
authentication. The flow resets if the user waits more than about an hour between step 1 and step 3.
Each update adds friction again, because every ad-hoc build is a different, unknown binary to Gatekeeper.

**Notarized flow, for comparison [Verified, Apple notarization doc]:** Gatekeeper finds the ticket and
"places descriptive information in the initial launch dialog". The user sees a single "downloaded from
the Internet" confirmation, with no trip to System Settings.

**[Unverified]:**
- The exact wording of the macOS 15, 26 and 27 block dialogs. Apple doesn't publish it. Screenshot it on
  each OS for the docs.
- Third-party reports of "is damaged and can't be opened" on macOS 26. That message is typically
  associated with broken or missing signatures. These builds have valid ad-hoc signatures, but test a
  real browser download on 26 and 27.

**Repo today:** README and the `release.yml` notes describe the Privacy & Security → Open Anyway path,
plus `xattr -dr com.apple.quarantine`. They miss the password step, the 1-hour window and the second
confirmation. Drop the `xattr` advice once builds are notarized.

## A3. Hardened runtime and entitlements

**[Verified] (Apple, *Hardened Runtime* and the entitlement reference pages):**
- Hardened Runtime is required for notarization.
- "Make sure to use only the entitlements that are absolutely necessary." Entitlements go on
  executables only. Boolean entitlements default to false, so only include `true` ones.
- `com.apple.security.device.camera`: lets the app "interact with the built-in and external cameras".
  It is enabled under App Sandbox or Hardened Runtime, so a hardened-runtime app that uses the camera
  needs it.
- `com.apple.security.device.audio-input`: lets the app "record audio using the built-in microphone and
  access audio input using Core Audio." It is enabled under Hardened Runtime > Resource Access.

**Is audio-input needed for Core Audio process taps?**
- [Verified] Apple's sample *Capturing system audio with Core Audio taps* says only that you "need to
  include the `NSAudioCaptureUsageDescription` key". It also says the system prompts for "system audio
  recording permission" the first time you record from an aggregate device that contains a tap. It
  says nothing about the audio-input entitlement. The sample's project file wasn't downloaded, so its
  entitlements are not checked.
- [Unverified] Third-party reports say a hardened-runtime build creates taps without audio-input.
- **Practical answer:** it doesn't matter for this repo. The only two apps that use taps (Humanity and
  Murmur, via MeetingKit) also record the microphone, so they need audio-input anyway.

**Is the camera entitlement required?** Yes, for Humanity, OculOS and ManOS (all use `AVCaptureDevice`
via GazeKit). No, for Murmur, which has no camera code and no `NSCameraUsageDescription`.

**Repo today [Repo]:** one shared `scripts/app.entitlements` with camera and audio-input for every app.
There is no sandbox, no `get-task-allow`, and no `cs.*` exceptions. None are needed: no JIT, no
plug-ins, and Core ML and FoundationModels are system frameworks.

**Needed: per-app entitlements (least privilege):**

| App | camera | audio-input | Why |
|---|---|---|---|
| Humanity | yes | yes | Hosts OculOS, ManOS and Murmur modules |
| OculOS | yes | **remove** | Camera only |
| ManOS | yes | **remove** | Camera only |
| Murmur | **remove** | yes | Mic, speech, taps |

After signing, verify with `codesign -d --entitlements - --xml App.app`.

## A4. Info.plist usage strings

**[Verified] Apple key reference:**
- `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`: "required if your app uses APIs that
  access the device's camera/microphone."
- `NSSpeechRecognitionUsageDescription`: macOS 10.15+.
- `NSAudioCaptureUsageDescription`: macOS **14.2+**, for system-audio capture with taps.
- `NSAppleEventsUsageDescription`: "required if your app uses APIs that send Apple events."
- **`NSScreenCaptureUsageDescription` is not an Apple-documented key.** Its documentation URL returns
  404, and it is absent from Apple's *Protected resources* list of usage keys. Screen Recording uses a
  system-worded prompt.

**Matrix [Repo]** (code paths found by grepping each app's sources and the packages it links):

| Key | Humanity | OculOS | ManOS | Murmur |
|---|---|---|---|---|
| NSCameraUsageDescription | present, needed | present, needed | present, needed | absent, not needed |
| NSMicrophoneUsageDescription | present, needed | absent, not needed | absent, not needed | present, needed |
| NSSpeechRecognitionUsageDescription | present, needed | n/a | n/a | present, needed |
| NSAudioCaptureUsageDescription | present, **text names "Murmur": fix** | n/a | n/a | present, needed |
| NSAppleEventsUsageDescription | not used | not used | not used | not used |
| NSScreenCaptureUsageDescription | n/a (undocumented) | n/a (undocumented) | n/a | n/a |

Notes:
- **OculOS and Screen Recording:** OculOS calls `SCShareableContent` and
  `SCScreenshotManager.captureImage` for the optional heatmap backdrop (`ScreenshotCapture.swift`), so it
  does use Screen Recording. Apple documents no Info.plist key for it, so nothing is required. Don't add
  `NSScreenCaptureUsageDescription` expecting it to change the prompt.
- **Apple events are not used anywhere.** No `NSAppleScript`, `OSAScript`, `NSAppleEventDescriptor` or
  `osascript`. Opening `x-apple.systempreferences:` URLs with `NSWorkspace` is not an Apple event. Do
  not add `NSAppleEventsUsageDescription`.
- **Speech:** recognition is forced on-device (`requiresOnDeviceRecognition = true` in
  `Murmur/…/Transcriber.swift` and `MeetingKit/…/FileTranscriber.swift`), so the claim "Nothing is sent
  to Apple" is consistent with the code. Text cleanup can go to a cloud provider when the user adds a
  key, but that is text, not speech recognition.
- **Versions:** `CFBundleShortVersionString` uses "three period-separated integers". For
  `CFBundleVersion`, Apple says: "For macOS apps, increment the build version before you distribute a
  build." Today it is always `1`.

## A5. TCC: Accessibility, Input Monitoring, Screen Recording

What each app uses [Repo]:

| Capability | API in repo | TCC service (System Settings pane) | Apps |
|---|---|---|---|
| Post mouse/keyboard events | `CGEvent(...)` + `.post` | **PostEvent**, shown under **Accessibility** | ManOS, OculOS (dwell click), Murmur (paste), Humanity |
| Read AX tree (snap-to-target) | `AXUIElementCopyElementAtPosition`, `AXUIElementCopyAttributeValue` | **Accessibility** | OculOS, Humanity |
| Global mouse-down monitor | `NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown)` | Apple gates only key events (below) | OculOS, Humanity |
| Global hotkeys | Carbon `RegisterEventHotKey` | none documented | OculOS, Murmur, Humanity |
| Window bounds | `CGWindowListCopyWindowInfo` | none for bounds [Unverified] | ManOS, Humanity |
| Screen stills / app audio | `SCShareableContent`, `SCScreenshotManager`, `SCStream` | **Screen Recording** | OculOS (optional), MeetingKit fallback (macOS < 14.4 or failed tap), Humanity |
| App audio | Core Audio process tap | "system audio recording" (`NSAudioCaptureUsageDescription`) | Murmur, Humanity |

**Input Monitoring: are CGEvent posting and Carbon hotkeys affected?**
- **CGEvent posting needs PostEvent, not Input Monitoring.** [Verified via Apple DTS on the Apple
  Developer Forums, which is not formal documentation]:
  - Thread 730441, May 2023: "You don't need the Accessibility privilege to post mouse events. There's a
    separate privilege, Post Event," checked with `CGPreflightPostEventAccess` and requested with
    `CGRequestPostEventAccess`.
  - Thread 789896, 2025: `tccutil` has "separate services for `Accessibility`, `ListenEvent`, and
    `PostEvent`". PostEvent shows in the UI under Accessibility. ListenEvent (event taps) is the one
    shown as **Input Monitoring**.
  - Apple's API reference pages for `CGRequestPostEventAccess` and `CGPreflightListenEventAccess` exist
    (macOS 10.15+) but have no discussion text.
- **Carbon `RegisterEventHotKey`:** Apple documents no TCC requirement for it. [Unverified] It is widely
  reported to need no permission.
- **No Input Monitoring needed today.** The repo uses no `CGEvent.tapCreate` and no IOHID listening.
  Apple's `tapCreate` doc says taps receive key events only for root or with assistive access. If a
  future feature adds an event tap, that changes.
- **Key events:** Apple's `addGlobalMonitorForEvents` doc says "Key-related events may only be monitored
  if accessibility is enabled". OculOS monitors only `.leftMouseDown` globally; its key monitors are
  local.

**Screen Recording:**
- [Unverified, press reports]: macOS 15 added recurring "bypass the system private window picker"
  re-confirmation prompts, reportedly monthly and reduced in 15.1, for apps that use ScreenCaptureKit
  directly. Expect them on 15, 26 and 27.
- [Verified] Apple offers `SCContentSharingPicker` (macOS 14+) as the system picker. The
  `com.apple.developer.persistent-content-capture` entitlement is only for VNC apps and requires an
  application to Apple. It doesn't apply here.

**TCC identity and updates:**
- [Unverified, but it matches the repo's comments and common experience] TCC ties a grant to the app's
  designated requirement.
  - Ad-hoc releases (`PIN_DR=0`) have a cdhash requirement, so **every update drops the Accessibility
    and Screen Recording grants**.
  - A Developer ID signature's designated requirement is anchored to the Team ID and bundle ID, so
    grants survive updates.
  - Test this explicitly (§A9, step 14).

**`tccutil reset` of the app's own bundle ID:**
- [Verified, `man tccutil`] `tccutil reset SERVICE [bundle_id]` is a shipped, documented command.
  Resetting only your own bundle ID is within its documented use.
- The service names used (`Accessibility`, `ScreenCapture`) don't appear in the man page's examples.
  That is [Unverified] but long-standing.
- It works because the apps are not sandboxed. It is not a private API.

## A6. The rule against private APIs

**[Verified] DPLA §3.3.1(A):** "Applications may only use Documented APIs in the manner prescribed by
Apple and must not use or call any private APIs."
- Scope: the §3.3 lead-in names App Store, Custom App, TestFlight and Ad Hoc apps. However, §3.2 also
  requires every Application to be "developed in compliance with the Documentation and the Program
  Requirements … set forth in Section 3.3."
- **Treat the rule as applying to Developer ID builds.** Notarization scans for malware and signing
  problems, not private API use, so a violation wouldn't be caught there. It would still breach the
  agreement.

**Repo today [Repo]:**
- A grep finds no `dlopen`, `dlsym`, `NSClassFromString` or `NSSelectorFromString`, no `@_silgen_name`,
  and no `CGS*`, `SLS*` or `_AX*` symbols. `perform(...)` matches are only Vision's public
  `VNImageRequestHandler.perform`.
- Carbon HIToolbox hotkeys, the AX APIs, CGEvent, ScreenCaptureKit, Core Audio taps and the weak-linked
  FoundationModels framework are all public SDK APIs.

**Needed:** re-run the grep before each release (§A9, step 1).

## A7. DPLA clauses relevant to Developer ID distribution

Source: DPLA, last updated **August 18, 2026** [Verified]. My summary, not legal interpretation:

| Clause | What it says | Implication here |
|---|---|---|
| §3.2 (bullet on distribution) | "Applications for macOS may be distributed outside of the App Store using Apple Certificates and/or tickets as set forth in Section 5.3 and 5.4" | Developer ID distribution via GitHub and Gumroad is permitted. |
| §3.2 (security bullet) | No code that would "disable, hack or otherwise interfere with … security, digital signing … mechanisms … or enable others to do so" | Once notarized, stop telling users to `xattr -dr com.apple.quarantine`. |
| §3.2 (conduct bullet) | No "misleading, fraudulent … consumer misrepresentation" | Product claims must be accurate (also Gumroad §11.2(b)). |
| §3.3.1(A) | No private APIs | §A6 |
| §3.3.1(C) | No unlocking features "through distribution mechanisms other than the App Store, Custom App Distribution or TestFlight" without Apple's approval | **Ambiguous for license keys.** The §3.3 lead-in scopes the Program Requirements to App Store, TestFlight and Ad Hoc apps, and license keys are standard practice for Developer ID software. This would be a problem if the apps ever go to the Mac App Store. **Ask a lawyer if in doubt.** |
| §3.3.3(A) Recordings | Recording mic, camera or screen requires "a reasonably conspicuous audio, visual or other indicator"; apps "may not be designed to facilitate Recordings of others without their awareness" | Murmur meeting capture: keep a visible recording indicator (menu bar icon or HUD) the whole time. Keep the PRIVACY.md consent warning. |
| §3.3.3(B)–(C) | Collect data only with consent; "provide a privacy policy … on Your website"; notify users of breaches | Publish the privacy policy at a stable URL (§B7). |
| §5.1 | Safeguard certificates and keys; don't transfer them; notify Apple of compromise | Store the Developer ID `.p12` and notary API key only as encrypted CI secrets. Restrict them to tag-triggered release jobs and never commit them. The clause's example (no uploading the App Store certificate "to a cloud repository for use by a third party") is about App Store certificates, but follow its spirit. |
| §5.3 Notarized Applications | Apple may retain and scan uploads and revoke tickets. "You agree **not to represent that Apple has performed a security check or malware detection** for Your Application or that Apple has reviewed or approved Your Application." You remain responsible for the app's safety. Includes an export-control clause (EAR/ITAR, encryption). | **Marketing must not say "Apple-approved", "verified by Apple" or "malware-checked by Apple."** A conservative reading avoids "notarized by Apple" as a trust claim in marketing too. Install docs can say the app "opens without Gatekeeper warnings." The apps use only standard HTTPS. Have a lawyer confirm the export clause is satisfied. |
| §5.4 | Apple can revoke certificates (compromise, malware, breach, etc.). "If Apple revokes … Your Application may no longer run." | Plan a signing-key compromise response. |
| §7.6 | Lists permitted distribution, including "Applications … developed for macOS" | Consistent with §3.2. |
| §9.4 Press Releases and Other Publicity | No press releases or public statements "regarding this Agreement … or the relationship of the parties" without approval | Don't claim to be an Apple partner. |
| Indemnification | Excludes macOS apps distributed outside the App Store **that do not use Apple Services or Certificates** | Signing with Developer ID uses Certificates, so the indemnity applies once you enroll. |

## A8. Trademark use of "Mac" and "macOS" in marketing

**[Verified]** Apple's *Guidelines for Using Apple Trademarks and Copyrights* and the *Apple Trademark
List* (which lists `Mac®` and `macOS®`):

- **Compatibility use is allowed.** You may use an Apple word mark "in a referential phrase such as
  'runs on,' 'for use with,' 'for,' or 'compatible with'", provided:
  - the mark is not part of the product name;
  - it is less prominent than the product name;
  - the product really is compatible.
- **Not allowed:**
  - the Apple logo or any Apple graphic or icon;
  - implying endorsement or sponsorship;
  - imitating Apple trade dress;
  - "variation[s] … takeoff[s], or abbreviation[s] of an Apple trademark";
  - plural or possessive forms ("Macs", "macOS's").
- **Attribution:** in US-only materials, use ® on first use and a credit line. Outside the US, use the
  international credit line: "Mac and macOS are trademarks of Apple Inc., registered in the U.S. and
  other countries and regions."

**Recommendations:**
- Use "Humanity for Mac" or "Requires macOS 14 Sonoma or later", with the product name more prominent.
- Never use the Apple logo or an App Store badge.
- Add the credit line to the Gumroad page and website footer.
- **Naming risk to review with a trademark lawyer:** "ManOS" is one letter from "macOS", and both
  "OculOS" and "ManOS" end in "OS". Apple's guidelines forbid takeoffs and variations of its marks.
  I can't assess the risk, but it's worth checking before spending on marketing.

## A9. Ordered release checklist

### A9.1 Developer ID release (target)

Per app, run in CI on a tag. `$ID` = `Developer ID Application: <Legal Name> (<TEAMID>)`.

1. **Pre-flight.**
   - Re-run the private-API grep from §A6. Confirm the usage strings match each app's matrix row (§A4).
   - Confirm `NSAudioCaptureUsageDescription` in Humanity names Humanity.
   - Run `swift test` for each package.
2. **Versions.**
   - Set `CFBundleShortVersionString` to the tag (`X.Y.Z`, exactly three integers).
   - Set `CFBundleVersion` to a strictly increasing integer, e.g. `$GITHUB_RUN_NUMBER` or a commit count:
     `PlistBuddy -c "Set :CFBundleVersion $BUILD"`.
   - Don't ship `VERSION=dev`.
3. **Build** with `SCRATCH` outside the home folder. Choose arm64-only or universal so it matches the
   product page (blocker 9). Check with `lipo -archs`.
4. **Sign the app** with that app's entitlements file (§A3):
   `codesign --force --options runtime --timestamp --entitlements <app>.entitlements --sign "$ID" App.app`
   Sign nested code first if any is ever added. Today there is none.
5. **Verify the app signature.**
   - `codesign --verify --deep --strict --verbose=2 App.app`
   - `codesign -dvv App.app` must show `Authority=Developer ID Application…`, a `Timestamp=` line (not
     `Signed Time`), and `flags=…runtime`.
   - `codesign -d --entitlements - --xml App.app` must show no `get-task-allow`.
6. *(Recommended, for offline first launch)* Zip the app with `ditto -c -k --keepParent`, run
   `notarytool submit --wait`, then `xcrun stapler staple App.app`. This staples the app itself, so a
   copy dragged out of the DMG carries its own ticket.
7. **Create the DMG** (`hdiutil create -format UDZO`, as `package.sh` does), then `hdiutil verify X.dmg`.
8. **Sign the DMG:** `codesign --timestamp --sign "$ID" X.dmg`.
9. **Notarize the DMG:** `xcrun notarytool submit X.dmg --keychain-profile <profile> --wait` (or
   `--key/--key-id/--issuer` in CI). Then `xcrun notarytool log <id> log.json`, and fail the job on
   any issue.
10. **Staple:** `xcrun stapler staple X.dmg && xcrun stapler validate X.dmg`.
11. **Checksum last:** `shasum -a 256 X.dmg > X.dmg.sha256`, only after stapling.
12. **Gatekeeper test (local):**
    - `spctl --assess --type execute -vv App.app` must report `accepted` and
      `source=Notarized Developer ID`. Apple shows `spctl -vvv --assess --type exec`.
    - `spctl -a -t open --context context:primary-signature -vv X.dmg` must report `accepted` and
      `source=Notarized Developer ID`.
13. **Gatekeeper test (real download):**
    - Upload a draft release, download it with Safari on a clean macOS 15, 26 and 27 machine or VM, and
      check `xattr -p com.apple.quarantine` is set.
    - Open the DMG, drag to Applications and launch. Expect a single "downloaded from the Internet"
      confirmation and no Privacy & Security trip.
14. **TCC persistence test:** install the previous release and grant Camera, Accessibility and Screen
    Recording. Then install this release over it and confirm the grants still hold.
15. **Publish.** Update the release notes: remove the Open Anyway and `xattr` steps, and don't claim
    Apple "checked" or "approved" the app (§A7, §5.3).

### A9.2 Interim ad-hoc release (until enrolled)

1. Do steps 1–3 above. `CFBundleVersion` must still increase.
2. Build with `PIN_DR=0`, as CI already does. `spctl --assess` will report **rejected**, which is
   expected; record it in the release notes.
3. Release notes and product page must disclose:
   - the 5-step Open Anyway flow with the password and the ~1-hour window (§B10);
   - that **permissions must be re-granted after every update**;
   - the checksum.
4. Test steps 13 and 14 by hand on macOS 15, 26 and 27, and screenshot each block dialog for the docs.

---

# Part B: Gumroad

## B1. What Gumroad handles

| Topic | What Gumroad does | Source [Verified] |
|---|---|---|
| Merchant of record | **Yes, since January 1, 2025.** Gumroad is appointed your "non-exclusive reseller" and is "merchant of record of each resale". It "reserves the right to set the price" of your product. | gumroad.com/pricing; Terms §6.1–6.3 |
| Sales tax / VAT / GST | Gumroad is "treated as the seller … for purposes of any relevant Indirect Tax" and handles "collection, reporting and remittance". It automatically handles "all sales tax collection and remittance worldwide". Sellers can't opt out of VAT on digital products. EU business buyers can reclaim VAT with a VAT ID. | Terms §6.2(e), §10.2; Help 121; Help 10 |
| Payment data | Processed by Stripe and PayPal as "Third-Party Payments Providers". The seller never handles card data, and buyers never see the seller's bank details or address. | Terms §5; Help 120 |
| Chargebacks | Gumroad handles disputes "in Gumroad's sole discretion". It submits evidence; you get a 72-hour window (120 hours over a weekend) to add yours. **You pay back the disputed amount and processing fees**, and Gumroad returns its own platform fee. The buyer is blocked from buying again. Disputes on Stripe Connect or PayPal Connect sales are yours to fight. | Terms §7.1(a); Help 134 |
| First-tier buyer support | Invoicing, refund requests, payment reconciliation, failed payments, download issues. | Terms §6.2(d); Help 352 |
| Refunds on your behalf | "Gumroad reserves the right to issue refunds within 90 days of purchase, at its discretion, to prevent chargebacks." Brazil: a 7-day withdrawal right is honored even under a no-refunds policy. | Help 51; Help 335 |

## B2. What the seller remains responsible for

- **Refund policy:** you decide and issue refunds yourself (Help 47, 352). Set a per-product policy
  (Help 335). Gumroad shows it on the product page and attaches it to disputes. Rules to know:
  - If more than **1% of customers dispute**, Gumroad forces an account-wide 30-day refund policy if
    yours is "no refunds" (Help 51, 134).
  - A refund rate above **15%** triggers a 25% reserve for 90 days.
  - A refund rate above **25%** can lead to suspension (Terms §11.3(b)).
- **Consumer disclosures:** "all communications, representations and warranties … [must] be accurate
  and contain all disclosures and disclaimers necessary to prevent such communications … from being
  false, deceptive, or misleading" and comply with consumer-protection law (Terms §11.2(b)). You must
  provide "public-facing contact information and order fulfillment timelines" (§11.2(c)).
- **Your own terms:** "You shall provide Gumroad with the end user license terms and Product
  Documentation applicable to your Products". Gumroad presents them "in a manner that creates a binding
  contract between you and each such Buyer" (Terms §6.3).
  - MIT covers the **source code**. You still need short end-user terms for the **license key and
    official builds**: what a key unlocks, how many Macs, the refund policy, the "as is" warranty
    disclaimer, and that it requires macOS permissions and internet access for activation.
  - You may not add terms that limit Gumroad's refund and dispute section (§11.2(d)).
- **Your own privacy policy:** for buyer data Gumroad processes "in connection with the sale", **"the
  relevant seller is the data controller"** (Gumroad Privacy Policy; Help 349 includes the DPA). The
  apps also process camera, audio, gaze and voiceprint data locally. PRIVACY.md is a good base; publish
  it at a stable URL and add the purchase-data section from §B10.
- **Product claims:** products must "conform to and perform as described" (Terms §6.9(d)).
  - Keep claims like "never uploaded" true. Mention the optional bring-your-own-key AI and the
    Hugging Face model download.
  - Avoid medical or therapeutic claims for the accessibility use cases.
  - Don't promise gaze accuracy you haven't measured.
- **Direct (income) tax** is yours (Terms §10.6). So is compliance with email-marketing laws if you
  email buyers (§11.2(h)).

## B3. Prohibited products policy

Source: gumroad.com/prohibited and Help 155 [Verified]. The list "may change abruptly and without
notice", so re-check it before launch.

- Desktop software you wrote is allowed. Nothing here is a reseller-rights, PLR or OEM product.
- **Watch this item:** "AI services which includes selling access to AI tools, chatbots, image or
  content generation services, or subscriptions to AI services that are fulfilled outside of Gumroad."
  - Humanity doesn't sell AI access: AIKit uses the **buyer's own** API keys, and every task defaults
    to on-device.
  - Describe it as offline Mac software with optional bring-your-own-key integrations. Don't market it
    as an AI service or subscription.
- Off-Gumroad delivery: a product "whose only way of delivering it is telling buyers to message you
  somewhere else" is blocked. Linking to GitHub downloads is fine, but put real content on the Gumroad
  content page: the License key block, install instructions and download links. Optionally attach the
  DMGs themselves.
- Bundled third-party code must be properly licensed ("copyrighted media and software … including OEM
  or bundled software"). `THIRD_PARTY_NOTICES.md` covers this. Keep it current.

## B4. License keys

Sources: Help 76 *License keys*; gumroad.com/api#licenses [Verified].

- **Verify API:** `POST https://api.gumroad.com/v2/licenses/verify` with:
  - `product_id`: required for products created on or after Jan 9, 2023, instead of `product_permalink`;
  - `license_key`;
  - `increment_uses_count` (`"true"`/`"false"`, default `"true"`).

  No OAuth app is needed. On failure, the API returns **HTTP 404** with an error message.
- **Uses count:** the top-level `uses` field. Each verify call increments it unless
  `increment_uses_count=false`. Gumroad doesn't enforce limits: "License key enforcement is completely
  up to the creator … Gumroad performs no additional license key verification." The seller can reset or
  edit the count in the Sales dashboard. The API can decrement it (`PUT /licenses/decrement_uses_count`)
  but can't set an exact value.
- **Seats:** an optional "Multi-seat license" toggle lets buyers choose a number of seats. The response
  then has `is_multiseat_license: true` and `quantity` = seats.
- **Refund and chargeback fields: confirmed in the docs.** `purchase.refunded`, `purchase.disputed`,
  `purchase.dispute_won` and `purchase.chargebacked` are all documented. `chargebacked` is marked
  "non-subscription product only", and the docs' inline comment beside it confusingly says "purchase was
  refunded". Help 76 says: "You can also check if a purchase has been refunded or disputed by checking
  the refunded/disputed fields."
- **Behavior on refund or chargeback:**
  - [Verified] A full refund removes the buyer's access to the Gumroad content (Help 47). A chargeback
    "will appear to you as a full refund" (Help 134).
  - [Verified] The Licenses API "will continue to return the key state as enabled until you disable it"
    (said of memberships). You can disable a key with `PUT /licenses/disable`, which needs an
    access_token, or from the Sales dashboard.
  - [Unverified] Whether a refund auto-disables the key, and what `verify` returns for a disabled key.
    Neither is documented. **Test both with a test sale.**
- Other endpoints: `enable`, `disable`, `decrement_uses_count` and `rotate` (the old key stops working).
  You cannot import your own keys (Help 76 FAQ).

**LicenseKit vs. the docs [Repo]** (`LicenseKit/Sources/LicenseKit/License.swift`):

| Behavior | Status |
|---|---|
| Uses `product_id` (`rUEF1fvaBmPG_LIv3lXMMQ==`) and form-encodes it | OK. Confirm the ID matches the License key block of gumroad.com/l/hamkad. |
| `increment_uses_count=true` on activation, `false` on the weekly re-check | OK, matches the docs. |
| Rejects `success: false` and 404 bodies | OK (it parses the JSON body regardless of status). |
| Rejects `refunded`, `chargebacked`, `disputed` | **Fix:** `disputed` stays `true` after you **win** a dispute (`dispute_won: true`). Accept `disputed && dispute_won`, otherwise a buyer who was in the right stays locked out. |
| Ignores `uses` and `quantity` | Decide a policy, e.g. "personal license, your own Macs". Optionally warn above N activations. The license file is shared by all four apps, so `uses` ≈ number of Macs. |
| Re-check every 7 days, 60-day offline grace | Disclose on the product page (§B10). |
| Data handling | The verify response includes the buyer's email, IP country and sale details. LicenseKit decodes only the refund and dispute flags and stores only `{key, verifiedAt}`. Say so in the privacy policy. |

## B5. Free and promotional keys

- **100%-off discount codes:**
  - [Verified, Help 128] Codes can be a percentage or amount off. You can limit them by quantity,
    validity window, products, or existing customers.
  - [Verified, Help 133] "You can send customers a 100% off discount code." Gumroad also says "We also
    don't take any fee on free product sales."
  - [Verified, Help 62] A 100% code is an accepted way to test a purchase.
  - [Unverified] How a 100% code interacts with PWYW's $5 minimum, and whether a $0 order issues a
    license key. The API's own example response shows `"price": 0` with a key, which suggests yes.
    **Test it.**
- **Is giving free copies allowed?**
  - Nothing in the Terms, the Prohibited list or the help articles prohibits it.
  - What *is* prohibited is circumventing Gumroad's fee: arranging sales or payments "outside the
    context of the Platform" (Terms §17.3 "Subverting the Platform"; §11.2(d)). Don't sell codes or keys for money off-platform.
  - Since keys can't be imported, free copies have to go through Gumroad (a 100% code) or through a
    build where `License.required = false`.
- **Your own testing:** use Gumroad's **test purchase** feature, or a 100% code. Don't buy your own
  product with a real card: Help 62 and Help 13 warn this looks like fraud and can get the account
  suspended.

## B6. Gumroad's fees

Source: Help 66 and gumroad.com/pricing [Verified].

- **Direct sales** (your profile or links): **10% + $0.50** per transaction, "+ sales tax".
  - This does **not** include card processing (**2.9% + $0.30**) or PayPal fees.
  - High-volume discount: after $20,000 of paid sales in a calendar month, new direct sales that month
    are 5% + $0.50.
- **Discover marketplace sales:** a flat **30%**, including processing.
- No monthly fee. Free ($0) sales have no fee.
- **Refunds:** Gumroad returns its own fee on the refunded portion, but the processing fee is retained.
- **Chargebacks:** you cover the amount plus processing fees; Gumroad returns its platform fee.
- **Payout fees:** PayPal payouts 2%, instant payouts 3% (US only).
- **Worked example, $5 direct card sale (approximate):** Gumroad fee $1.00, processing about $0.45, so
  you net **about $3.55 (about 71%)**. Tax is added and remitted by Gumroad. With the $100 minimum
  payout, that's about 29 sales before the first payout.

## B7. Where to link Terms and Privacy on the product page

Gumroad has no dedicated "seller terms" or "seller privacy" fields. Its own Terms and Privacy links
appear in its site footer, and they don't replace yours. Use these places [Verified unless noted]:

1. **Checkout "Terms" custom field** (Help 101, Checkout customization): "Enter the URL for your terms
   that customers must accept before purchasing. This field is always set to 'Required.'" Point it at
   the end-user terms.
2. **Refund policy setting** with fine print (Help 335). It shows on the product page and goes into
   disputes.
3. **Product description:** a short "Terms · Privacy · Refunds · Support" link line near the price.
4. **Content page** (what buyers see after purchase, next to the License key block): the same links,
   plus install instructions.
5. **Support email** in Settings → Support. It's printed on every receipt (Help 352) and satisfies the
   public-contact requirement (§11.2(c)).
6. *(Code change, later)* The activation window (`ActivationWindow.swift`) could link Terms and Privacy
   next to "Buy a License".

Host the Terms and Privacy pages at stable URLs, e.g. GitHub Pages or `legal/` in the repo.

## B8. Payouts and tax forms for a US seller

Sources: Help 13, 260 and 15 [Verified].

- **Payout settings are mandatory:**
  - full legal name;
  - physical address (no PO boxes);
  - **SSN** (US individuals) or EIN, with the name and date of birth matching the SSN card exactly;
  - Stripe KYC: government photo ID and proof of address, when requested;
  - Individual vs. Business account type.
- **Age:** sellers aged 13–17 need a legal guardian added to the account before payouts. US only.
- **Schedule:**
  - Weekly, monthly or quarterly payouts, with a **$100 minimum** and a 7-day holding period. Daily
    payouts are available for eligible US accounts.
  - US bank payouts go out on Thursdays and take 2–7 business days.
  - New accounts go through a 1–3 week review.
  - Payouts pause automatically if your chargeback rate goes above 1% (Help 134).
- **1099-K:**
  - Issued by Stripe if, in the previous calendar year, the account was US-based **and** had more than
    **$20,000** gross volume **and** more than **200** transactions.
  - Downloadable from the Tax center. It arrives from late January to March.
  - The gross amount includes Gumroad's fee and collected sales tax and VAT, so it won't match your
    payouts.
  - Stripe Connect and PayPal Connect sales are excluded.
  - Gumroad issues 1099-MISC only to affiliates (over $600).
- **Below the thresholds:** no form is issued, but the income is still yours to report (Terms §10.6).
  [Unverified here] The IRS 1099-K threshold is set by law; confirm the current figure at irs.gov with a
  tax adviser.

## B9. What a buyer sees

[Verified, Help 282, 247, 120, 133, 134, 335]

1. **Product page:**
   - name, cover and description;
   - a **pay-what-you-want** price field with a $5 minimum and an optional suggested price;
   - your refund policy, if set;
   - ratings.
2. **Checkout:**
   - email address (no account required);
   - cards, Apple Pay, Google Pay or Venmo. PayPal appears only if you connect PayPal;
   - sales tax or VAT added where applicable;
   - any custom fields, such as the required Terms checkbox.
3. **Receipt email:**
   - a download or content link and the **license key**;
   - your support email;
   - a "Generate invoice" option, where EU and UK buyers can add a VAT ID for a refund.

   Buyers can also find the key on the content page, in their Gumroad Library, or via the license-key
   lookup page.
4. **Card statement:** a descriptor beginning with Gumroad's prefix plus your full name, username or
   product name. Help 134 says to use your **brand name** as your Gumroad name so buyers recognize it.
5. **What the buyer learns about you:** only your email (or support email) and profile name. Not your
   address or bank details.

## B10. Recommended product page copy

Adapt this wording. Keep it accurate, and update it when notarization lands.

**System requirements**
> Requires macOS 14 Sonoma or later on a Mac with Apple silicon. A webcam (the built-in camera works)
> for OculOS and ManOS, and a microphone for Murmur. Recording a call app's audio needs macOS 14.4 or
> later; earlier versions use Screen Recording instead. The most accurate dictation needs macOS 26.

**Apple silicon only.** Use this line only if the shipped binaries are arm64-only. Today CI builds
universal binaries (blocker 9).
> Apple silicon only. Intel-based Macs are not supported.

**Unnotarized warning** (interim, until Developer ID):
> Humanity isn't notarized yet, so macOS blocks it the first time you open it. To open it:
> 1. Drag it to Applications and open it. Close the warning.
> 2. Open System Settings → Privacy & Security, and scroll to Security.
> 3. Click **Open Anyway**. It appears for about an hour after step 1.
> 4. Enter your Mac login password.
> 5. Click **Open**.
>
> You'll need an administrator password. Each update must be approved the same way, and you'll need to
> turn macOS permissions back on after updating. Verify your download with the SHA-256 checksum on the
> release page.

**License model**
> Free to download. A license key is required to use the official builds. One key unlocks Humanity,
> OculOS, ManOS and Murmur on the Macs you personally use. Pay what you want, minimum $5. You can pay
> more to support development. The source code is open under the MIT License. Activation needs an
> internet connection. The apps re-check your key about once a week, and they keep working offline for
> up to 60 days after the last successful check. Refunded or charged-back keys stop working.

Decide and state the seat policy explicitly. "Your own Macs" is a suggestion.

**Refund policy.** Set it in Gumroad's refund-policy setting. Given the install friction, a generous
window reduces disputes.
> 30-day money-back guarantee: if Humanity doesn't work on your Mac, email support@… for a full refund.
> Refunded keys are deactivated.

**Data practices**
> Camera frames and audio are processed on your Mac and never uploaded. No analytics, telemetry or
> tracking. The apps connect to the internet only to:
> - check your license key with Gumroad (your key and the product ID);
> - download speaker-separation models from Hugging Face the first time you process a meeting;
> - let macOS download Apple's speech model;
> - send transcript *text*, never audio, to an AI provider, but only if you add your own API key.
>
> Your purchase (name, email, payment) is handled by Gumroad and its payment processors. We receive your
> email and order details from Gumroad. Gaze data and voiceprints are stored locally and can be deleted
> at any time. Full details: [Privacy Policy]. Recording meetings may require consent from everyone on
> the call.

**Footer:** "Terms · Privacy · Refunds · Support: support@…", followed by "Mac and macOS are trademarks
of Apple Inc., registered in the U.S. and other countries and regions." Don't claim the app is
"approved", "verified" or "malware-checked" by Apple (DPLA §5.3).

---

# C. What the developer must do personally

An assistant must not do any of these. They involve the developer's identity, credentials, legal
agreements, tax identifiers or money.

**Apple**
- Enroll in the Apple Developer Program. You need an Apple Account with two-factor authentication and
  must be of legal age. Choose **Individual** (your legal name appears as the developer) or
  **Organization** (needs a legal entity and a D-U-N-S number).
- Pay the 99 USD per year fee.
- Accept the DPLA, and its updates when prompted.
- As Account Holder, create the **Developer ID Application** certificate and keep its private key safe.
  If it is compromised, notify Apple and request revocation at product-security@apple.com.
- Create the notarization credential: an App Store Connect API key or an app-specific password. Add it,
  plus the `.p12` and its password, to GitHub Actions secrets yourself.
- Decide on product names after a trademark review (§A8). Have a lawyer review the §3.3.1(C) and §5.3
  export-control questions if they concern you.

**Gumroad**
- Create and secure the account (2FA).
- Fill in **payout settings** yourself:
  - legal name, physical address, SSN or EIN;
  - bank account;
  - Stripe identity verification documents;
  - Individual vs. Business.

  If you're under 18, a guardian must be added.
- Set the support email and brand name. The name shows on buyers' card statements.
- Set the PWYW price ($5 minimum).
- Write, approve and link the refund policy, end-user Terms and Privacy Policy (§B7).
- Confirm that the product's License key block shows the same `product_id` as LicenseKit.
- Use the **test purchase** feature or a 100% code to check the receipt, key delivery, a refund and a
  key disable. Never use your own card.

**Tax and records**
- Talk to a tax adviser about income tax, estimated payments, and whether to form an LLC (for privacy
  and liability).
- Keep the Gumroad payout CSVs.
- Download any 1099-K from the Tax center each year.

---

## Sources

All fetched 2026-10-01.

**Apple**
- Notarizing macOS software before distribution: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Resolving common notarization issues: https://developer.apple.com/documentation/security/resolving-common-notarization-issues
- Customizing the notarization workflow: https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- Signing Mac Software with Developer ID: https://developer.apple.com/developer-id/
- Developer ID certificates (Account Help): https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
- Program enrollment: https://developer.apple.com/help/account/membership/program-enrollment/
- Fee: https://developer.apple.com/programs/enroll/ and https://developer.apple.com/support/purchase-activation/
- Updates to runtime protection in macOS Sequoia: https://developer.apple.com/news/?id=saqachfa
- Open a Mac app from an unknown developer (macOS 15, 26, 27): https://support.apple.com/guide/mac-help/mh40616/mac
- Safely open apps on your Mac: https://support.apple.com/en-us/102445
- Hardened Runtime: https://developer.apple.com/documentation/security/hardened-runtime
- Audio input entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input
- Camera entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.camera
- Capturing system audio with Core Audio taps: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
- Usage keys:
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nsaudiocaptureusagedescription
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nsspeechrecognitionusagedescription
  - https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription
  - Protected resources list: https://developer.apple.com/documentation/bundleresources/protected-resources
- CFBundleVersion: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion
- CFBundleShortVersionString: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring
- addGlobalMonitorForEvents: https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)
- CGEvent tapCreate: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)
- CGRequestPostEventAccess: https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess()
- SCContentSharingPicker: https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker
- Persistent content capture entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.persistent-content-capture
- Apple DTS forum posts: https://developer.apple.com/forums/thread/730441 and https://developer.apple.com/forums/thread/789896
- Apple Developer Program License Agreement (updated Aug 18, 2026): https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
- Apple trademark guidelines: https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html
- Apple Trademark List: https://www.apple.com/legal/intellectual-property/trademark/appletmlist.html
- `man tccutil` (local, macOS 26.6.2)

**Gumroad**
- Terms of Service: https://gumroad.com/terms
- Privacy Policy: https://gumroad.com/privacy
- Prohibited products: https://gumroad.com/prohibited
- Pricing: https://gumroad.com/pricing
- API: https://gumroad.com/api#licenses
- Help articles:
  - License keys: https://gumroad.com/help/article/76-license-keys
  - Gumroad's fees: https://gumroad.com/help/article/66-gumroads-fees
  - 1099s: https://gumroad.com/help/article/15-1099s
  - Getting paid: https://gumroad.com/help/article/13-getting-paid
  - Payout settings: https://gumroad.com/help/article/260-your-payout-settings-page
  - Sales tax: https://gumroad.com/help/article/121-sales-tax-on-gumroad
  - EU and UK VAT: https://gumroad.com/help/article/10-dealing-with-vat
  - Issuing a refund: https://gumroad.com/help/article/47-how-to-refund-a-customer
  - Custom refund policy: https://gumroad.com/help/article/335-custom-refund-policy
  - Gumroad's refund policy: https://gumroad.com/help/article/51-what-is-gumroads-refund-policy
  - Chargebacks: https://gumroad.com/help/article/134-how-does-gumroad-handle-chargebacks
  - Discount codes: https://gumroad.com/help/article/128-discount-codes
  - Pay what you want: https://gumroad.com/help/article/133-pay-what-you-want-pricing
  - Checkout customization: https://gumroad.com/help/article/101-designing-your-product-page
  - How purchases work for customers: https://gumroad.com/help/article/282-how-do-purchases-work-for-my-customers
  - The Gumroad Library: https://gumroad.com/help/article/247-what-your-customers-see
  - Testing a purchase: https://gumroad.com/help/article/62-testing-a-purchase
  - Things not allowed: https://gumroad.com/help/article/155-things-you-cant-sell-on-gumroad
  - Supporting your customers: https://gumroad.com/help/article/352-supporting-your-customers
  - Protecting creator privacy: https://gumroad.com/help/article/120-protecting-your-privacy-on-gumroad
  - GDPR and data requests: https://gumroad.com/help/article/349-gdpr-data-requests
