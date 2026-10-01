# Humanity research

Background research behind the Humanity apps. Each file covers one topic and has
a summary, key findings with numbers, ranked recommendations, and sources.
Twenty-two agent-assisted literature and product reviews from September 2026.
Treat any figure marked as unverified in a file accordingly.

| # | Topic | Applies to |
|---|---|---|
| [00](00-competitors.md) | Competitor teardown: Tobii, Beam, Talon, Head Pointer, Leap… | OculOS, ManOS |
| [00](00-distribution-and-trust.md) | Distribution, signing, Homebrew, Sparkle, README | All |
| [01](01-gaze-models.md) | Appearance-based gaze CNNs and their licenses | OculOS |
| [02](02-gaze-calibration.md) | Calibration, personalization, drift | OculOS |
| [03](03-geometric-gaze.md) | Geometric eye models, head pose, camera FOV | OculOS |
| [04](04-iris-pupil.md) | Iris and pupil localization, jitter | OculOS |
| [05](05-gaze-filtering.md) | Real-time gaze filters for cursors | OculOS |
| [06](06-gaze-analytics.md) | AOIs, metrics, replay, export | OculOS |
| [07](07-gaze-interaction.md) | Dwell, zoom, snap-to-target, gaze UIs | OculOS |
| [08](08-hand-tracking-models.md) | Hand-tracking models and performance | ManOS |
| [09](09-gesture-vocabulary.md) | Gesture vocabulary and teaching | ManOS |
| [10](10-ergonomics.md) | Mid-air fatigue and posture | ManOS |
| [11](11-jitter-latency.md) | Jitter, latency, click rewind | ManOS |
| [12](12-accessibility.md) | Users with motor disabilities | All |
| [13](13-hci-pointing.md) | Fitts' law, MAGIC, Gaze + Pinch | OculOS, ManOS |
| [14](14-apple-apis.md) | Apple APIs and pitfalls | All |
| [15](15-dictation-apps.md) | Dictation app landscape | Voice app |
| [16](16-speech-engines.md) | On-device speech and summarization engines | Voice app |
| [17](17-privacy-security.md) | Privacy, security, threat model | All |
| [18](18-evaluation.md) | Benchmarks and honest evaluation | All |
| [19](19-multimodal.md) | Combining gaze, hands, and voice | All |
| [20](20-macos-ux.md) | macOS utility UX and onboarding | All |

## Roadmap distilled from the research

Status: ✅ done · 🔜 next · 💡 later

### OculOS
- ✅ Geometric head-pose model, pursuit + validation calibration, click learning (02, 13)
- ✅ **Never click with gaze alone.** Gaze points; a pinch (ManOS), a hotkey, or
  an optional dwell commits. Dwell defaults to 800–1000 ms with a progress ring,
  adjustable from 300 to 3000 ms (07, 12, 13).
- ✅ **Snap-to-target** through the Accessibility tree, within about 4°, plus a
  zoom-to-click magnifier for small targets (07, 13). Magnifier still 💡.
- ✅ Cursor filter: one-sample look-ahead saccade confirmation and a ~450 ms
  weighted window. This can cut about 67 ms of delay (05).
- ✅ Jitter: gradient-based pupil centers (Timm & Barth) with a sub-pixel limbus
  fit. At 720p, 1 px is about 2–3° (04).
- 💡 Real camera FOV and a 3D face fit for head distance, replacing the 150 mm
  face-box assumption (03). macOS reports no FOV (videoFieldOfView is 0), so
  the calibrated scale absorbs it for now.
- ✅ Turn off Center Stage while tracking (14).
- 💡 Few-shot head on frozen CNN features; drift offset when click residuals
  exceed 1.5× validation error (01, 02).
- 💡 AOIs with TTFF, dwell and revisits; gaze-overlay replay video (06).
- ⚠️ **License:** the MobileGaze weights are trained on Gaze360 (non-commercial).
  Keep them a separate opt-in download and never ship them in releases (01).

### ManOS
- ✅ Palm anchor, pinch hysteresis, click rewind, clutch, physical-mouse takeover,
  kill switch (11, 13)
- ✅ Camera Reactions disabled via Info.plist (14)
- ✅ Rewind clicks to pinch onset (50–250 ms) instead of a fixed 100 ms, and slow
  the pointer to about 0.2× while the fingers close (11, 13).
- ✅ 60 fps capture format when available; crop Vision to the region of the last
  hand (08, 14). Measured: the crop doesn't speed Vision up on Apple silicon,
  so it's used only to find small, distant hands.
- ✅ Chirality lock by vote across frames (08). Depth from bone length skipped:
  palm-scale normalization already covers it.
- ✅ Teach an elbow-rested low posture in Quick Setup; fatigue counter with break
  hints (10).
- 💡 Command layer: hold a V-pose and flick for Mission Control, Exposé and
  Spaces, with a radial menu that teaches it (09).
- 💡 Built-in ISO 9241-411 Fitts test comparing throughput with your mouse (18).
- 💡 Gestures recorded by the user, for people who can't pinch (12).

### Voice app
- ✅ Hold-to-talk HUD, paste with clipboard restore, typed fallback in terminals,
  under 500 ms after release (15).
- ✅ Engines: SpeechAnalyzer (macOS 26, no download); 💡 Parakeet via FluidAudio as an
  option; Foundation Models summaries in chunks of about 20 minutes (16).

### Suite-wide
- 🔜 Sign with one stable self-signed certificate so permissions survive updates;
  DMG releases from GitHub Actions; document the "Open Anyway" flow (00, 17).
- ✅ PRIVACY.md and SECURITY.md: no network, no stored video or audio, minimal
  entitlements (17).
- ✅ Humanity owns one shared camera; with OculOS and ManOS both on, you look
  to aim and pinch to click (19).
- 💡 Notarization ($99/yr) for Homebrew cask and Gatekeeper trust (00).
