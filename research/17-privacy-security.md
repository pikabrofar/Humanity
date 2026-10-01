# Privacy, Security and Trust for oculOS

## Summary

oculOS combines camera, microphone, Accessibility (synthetic input) and optional Screen Recording permissions, so on a typical Mac it is one of the most privileged non-Apple processes running. An attacker who compromises the binary, an update, a downloaded model, or a CI secret gets a ready-made spyware and remote-control kit, and the user has already approved every permission it needs. The trust story therefore depends on three things: keeping the privileged surface small, making every byte that runs verifiable (code, updates, models), and storing almost nothing, especially gaze data. Gaze data is biometric-adjacent and reveals much more than where the user is looking.

## Key findings

- **TCC is a gate, not a sandbox.** Once a user grants Accessibility, the app can read and drive any UI. TCC bypasses keep appearing (CVE-2025-31199 via Spotlight plugins, CVE-2025-43530 via VoiceOver/`com.apple.scrod`), so oculOS should not assume the OS will contain a compromised process. TCC grants are tied to the code-signing identity, so a stable Developer ID matters, and ad-hoc builds lose their grants on every rebuild.
- **Hardened Runtime needs explicit device entitlements.** Without `com.apple.security.device.camera` / `audio-input`, tccd answers "Policy disallows prompt" and never shows a dialog. Weakening entitlements such as `cs.disable-library-validation`, `allow-jit` and `allow-unsigned-executable-memory` let attackers inject dylibs into a process that already holds the TCC grants.
- **The update channel is the main supply-chain risk.** Sparkle 2 signs archives with EdDSA (ed25519) and checks them against `SUPublicEDKey` in Info.plist, in addition to Apple code signing. DSA-only feeds are no longer supported. In 2025 the tj-actions/changed-files compromise (CVE-2025-30066) showed that retagged GitHub Actions can leak signing secrets.
- **Model files can carry code.** Pickle-based weights (`.pt`, `.pkl`, `.bin`) can execute arbitrary code when loaded. Safetensors is a JSON header plus raw tensors and has no way to run code. Core ML (`.mlmodel`/`.mlpackage`) and ONNX are data formats too, but they still need integrity checks.
- **Gaze data is sensitive.** Kröger et al. show that eye-tracking data can reveal identity, age, gender, emotional state, drug use, health conditions and sexual preferences. Under GDPR, gaze counts as a behavioural biometric. It becomes Article 9 special-category data when it is processed to identify someone, and inferences about health are special-category data in any case. Not storing it is the simplest way to comply.
- **Secure Event Input exists for a reason.** Password fields enable `EnableSecureEventInput`, which blinds event taps. An app that synthesizes input or listens for hotkeys should detect this state with `IsSecureEventInputEnabled()` and back off, not try to work around it.
- **How trusted apps communicate privacy:** a short plain-language statement of what is never collected, reproducible or attested builds, and an honest list of every network endpoint. Privacy manifests (`PrivacyInfo.xcprivacy`) are not required on macOS, but they are a cheap way to state that the app does no tracking.

## Recommendations (ranked)

1. **Default to zero network access and zero retention.** Process camera frames and audio in memory only. Never write raw frames, gaze traces or audio to disk unless the user starts a recording on purpose, and then store it in a user-visible folder with a retention timer. Keep calibration data as a few model coefficients, never as images.
2. **Sign updates twice and pin the key.** Use Sparkle 2 with EdDSA signatures, HTTPS-only appcasts and `SUPublicEDKey` embedded in the app. Keep the private key off CI, or in a protected environment that requires manual approval. Notarize every release.
3. **Ship a minimal Hardened Runtime profile.** Declare only `device.camera` and `device.audio-input`, with clear `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` strings. Ship without `disable-library-validation`, JIT or unsigned-memory entitlements, and add a CI check that diffs `codesign -d --entitlements` output against a committed allowlist.
4. **Verify every model download.** Pin a SHA-256 for each model in a signed manifest that ships inside the app bundle, and refuse to load anything that fails the check. Accept only safetensors, Core ML or ONNX, never pickle. Fetch models from pinned URLs, and only after the user agrees.
5. **Harden CI.** Pin every GitHub Action to a full commit SHA, use Dependabot for actions and SwiftPM, give workflows read-only tokens by default, and publish GitHub Artifact Attestations (Sigstore/SLSA provenance) for each DMG so users can run `gh attestation verify`.
6. **Respect Secure Event Input.** When `IsSecureEventInputEnabled()` returns true, pause dictation insertion and any keystroke observation, and show a menu-bar indicator. Never log typed or dictated text.
7. **Put the privileged parts in a separate process.** Run the code that posts synthetic events in a small helper that accepts only a narrow XPC protocol, and validate the caller's code signature (audit token plus designated requirement). Keep vision and ML code out of that process.
8. **Show live, honest indicators.** Display clear menu-bar states when the camera, mic or screen capture is active, add a single "pause all sensing" hotkey, and include a permissions screen that explains why each TCC grant is needed and links to System Settings to revoke it.
9. **Treat gaze as biometric in the documentation.** State that oculOS does not identify users, does not infer emotion or health, and does not export gaze data. If you ever add opt-in telemetry, collect only aggregate counters, never raw gaze, and require explicit consent.
10. **Publish a short `PRIVACY.md` and `SECURITY.md`.** List every network call (update check, model download) and every data type with where it lives and for how long. Add a vulnerability disclosure contact, document how to check signatures and attestations, and ship a `PrivacyInfo.xcprivacy` with `NSPrivacyTracking=false`.

## Sources

- https://securityonline.info/new-tcc-bypass-cve-2025-43530-exposes-macos-to-unchecked-automation/
- https://securityaffairs.com/180503/hacking/microsoft-uncovers-macos-flaw-allowing-bypass-tcc-protections-and-exposing-sensitive-data.html
- https://github.com/impressiver/snitt/pull/166 (Hardened Runtime + audio-input / tccd behavior)
- https://developer.apple.com/forums/thread/799497
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/eddsa-migration/
- https://github.com/advisories/ghsa-mrrh-fwg8-r2c3 (CVE-2025-30066)
- https://github.blog/enterprise-software/devsecops/enhance-build-security-and-reach-slsa-level-3-with-github-artifact-attestations/
- https://www.datacamp.com/blog/safetensors-format
- https://arxiv.org/pdf/2501.02170
- https://publica.fraunhofer.de/entities/publication/b17f461d-0a8f-46cf-8347-67d293ff4353 (Kröger et al.)
- https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/
- https://gdpr-text.com/read/article-9/
- https://developer.apple.com/library/archive/technotes/tn2150/_index.html
- https://developer.apple.com/videos/play/wwdc2023/10060/
