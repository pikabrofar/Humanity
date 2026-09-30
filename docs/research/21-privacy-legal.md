# 21 — Privacy and legal considerations for gaze and face data

> **Not legal advice.** This is engineering research from a time-limited agent (5 min, ~5 searches). Claims marked *(unverified)* came from search summaries or memory and should be checked with a lawyer before you rely on them.

## TL;DR

- Gaze data reveals a lot more than where someone looked. Kröger et al. (2020) survey studies that infer identity, age, gender, personality, drug use, emotional state, interests, sexual preference and health conditions from eye movements. Treat recorded sessions as sensitive personal data.
- **The strongest legal and ethical position is that frames and landmarks never leave the Mac and are never stored.** Persist only derived gaze points, and only when the user explicitly records a session.
- GDPR: gaze and face data can be "biometric data" under Art. 4(14). It becomes special-category data under Art. 9 only when it is processed *to uniquely identify* someone. oculOS doesn't identify anyone, but health inferences could still pull the data toward Art. 9 *(unverified interpretation)*.
- Illinois BIPA covers a "scan of … face geometry." Since 2024 (SB 2979), repeated scans of the same person count as a single violation, but consent and retention duties still apply. Local-only processing lowers the risk but doesn't remove it *(unverified)*.
- Apple: guideline 5.1.2 bans using facial-mapping and camera data for advertising or data mining. The guidelines also require consent and a clear indicator while recording. On macOS, a privacy manifest is required for bundled SDKs, but required-reason API declarations aren't currently required for macOS.

## Key findings

1. **Inference risk.** Gaze patterns work as behavioural biometrics and can re-identify people in "anonymized" datasets. A VisionGaze CSV of timestamps and screen coordinates, together with a PNG heatmap of the screen, can expose both the user and whatever was on screen (email, documents).
2. **GDPR definitions.** Art. 4(14) asks whether the data *allows or confirms* unique identification, which depends on what it can do. Art. 9 asks whether it is *processed for the purpose* of identification, which depends on what it's used for. Gaze analysis is listed among behavioural biometric techniques. The GDPR mostly binds whoever controls processing. An MIT app running only on the user's device, with no developer access, arguably has no developer-side controller for that data *(unverified)*.
3. **BIPA.** Biometric identifiers include "retina or iris scan … scan of hand or face geometry." Vision's face landmarks and hand joints could arguably count. BIPA's duties are to publish a retention policy, get written (electronic) consent, and not profit from the data. SB 2979 (Aug 2024) also confirmed that electronic signatures count as consent. Texas, Washington and Colorado have similar laws *(unverified details)*.
4. **Apple.** Guideline 5.1.1/5.1.2: no marketing or data-mining use of facial or depth data, and user activity may only be recorded with consent and a visible indicator. `NSCameraUsageDescription` is mandatory. The camera's green indicator light on Macs is hardware-linked and can't be suppressed by apps *(unverified — Apple has described this in its platform security guide)*.

## How to program it

- **No network.** In the App Sandbox, leave out `com.apple.security.network.client` and `network.server`. The OS then enforces "on-device only," so the claim is testable and not just marketing. Ship Core ML models in the bundle and never download them at runtime.
- **Entitlements:** `com.apple.security.device.camera` only. Use user-selected read-write file access for exports (`NSSavePanel`), not blanket home-folder access.
- **Minimize data.** Process `CVPixelBuffer`s in memory and drop them each frame. Never write frames, face crops or raw landmarks to disk. Store only `(t, x, y, confidence, event)`. Calibration parameters are small, but treat them as sensitive too.
- **Storage.** Keep sessions in the sandbox container's Application Support folder. Mark writes with `.completeFileProtection` where the platform honours it (limited on macOS *(unverified)*) and rely on FileVault for at-rest encryption. Optionally encrypt with a CryptoKit `AES.GCM` key stored in the Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- **Retention.** Add a setting with a default of 30 days, plus "Delete all sessions." Purge on launch.
- **Export warnings.** Before saving a PNG or CSV, show a sheet explaining that gaze data can reveal health, attention and identity information, and that a heatmap over a screenshot shows screen contents. Offer "gaze only, no screenshot," coordinate rounding and timestamp offsets.
- **Recording indicator.** Show a menu-bar dot or overlay whenever a session is being recorded. This is separate from simply tracking.
- **Privacy manifest.** Add `PrivacyInfo.xcprivacy` with `NSPrivacyTracking = false`, empty `NSPrivacyCollectedDataTypes` (nothing leaves the device), and `NSPrivacyAccessedAPITypes` for UserDefaults (`CA92.1`) and file timestamps (`C617.1`/`3B52.1`). These aren't required on macOS but are cheap to add, future-proof and honest.

## Recommendations for oculOS

1. Put a short `PRIVACY.md` in the repo: no network, no frames stored, what a session file contains, and how to delete it. Keep it matched to the entitlements.
2. Build a CI check that fails if a network entitlement or a `URLSession` or analytics SDK appears.
3. Make recording opt-in per session. Tracking for control should never persist data by default.
4. For any research or data-collection mode, add explicit consent text, a retention statement, and no health or emotion inference features. The EU AI Act restricts emotion recognition in some settings *(unverified scope)*.
5. Make the hand-gesture app follow the same rules. Hand geometry is named in BIPA.

## Pitfalls

- Claiming "fully on-device" while a dependency phones home, or a crash reporter uploads logs that contain coordinates.
- Heatmap PNGs over screenshots leaking private screen content when users share them publicly.
- Debug builds that dump frames to `/tmp` and then ship.
- Assuming "anonymized" CSVs are safe, when gaze itself can identify people.
- Hash-mismatched or unsigned builds losing their TCC camera grant (see report 08), which makes users re-grant permissions they don't understand.

## Sources

- https://www.researchgate.net/publication/339831475_What_Does_Your_Gaze_Reveal_About_You_On_the_Privacy_Implications_of_Eye_Tracking
- https://publica.fraunhofer.de/entities/publication/b17f461d-0a8f-46cf-8347-67d293ff4353
- https://developer.apple.com/app-store/review/guidelines/
- https://gdpr-text.com/read/article-4/
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/
- https://www.gtlaw.com/en/insights/2024/8/bipa-update-illinois-limits-liability-and-clarifies-electronic-consent-for-biometric-data-collection
- https://www.insideprivacy.com/data-privacy/illinois-enacts-bipa-amendment-limiting-violation-accrual/
- https://www.avanderlee.com/xcode/missing-api-declaration-required-reason-itms-91053/
- https://bitrise.io/blog/post/enforcement-of-apple-privacy-manifest-starting-from-may-1-2024
