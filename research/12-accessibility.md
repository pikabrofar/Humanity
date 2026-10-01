# Accessibility-First Design for OculOS and ManOS

## Summary
The people who need OculOS and ManOS most have ALS/MND, spinal cord injury, RSI, tremor or cerebral palsy. Their abilities vary and they tire quickly. AAC vendors (Tobii Dynavox, Eyegaze), research on dwell and switch input, and Apple's docs agree on four things: conservative defaults that each user can tune, selections that are visible and safe to get wrong, quick pause and recalibration, and working with the macOS assistive stack rather than replacing it. Webcam tracking is less accurate than infrared AAC hardware, so it needs bigger targets and longer dwell.

## Key findings
- **Dwell timing:** typical thresholds are 500–1000 ms. Novices need about 1000 ms or more, and experts can go to about 300 ms. Longer dwell raises selection success and cuts corrections, but slows input. Tobii offers 8 dwell levels plus per-button dwell.
- **Fatigue and the eyes:** Tobii advises starting with short gaze sessions, because effortful focusing and reduced blinking cause fatigue and dry eyes. ALS adds droopy eyelids, a weaker blink reflex and dry corneas. Medications blur focus or change pupil size. Glasses add glare.
- **Gestures:** recognizers fail when tremor or spasticity changes the movement itself. In one study, people with limited movement barely agreed on gestures (agreement 0.11–0.37), and 16–40% of the gestures they chose were unique to one person. 51% were done with the arm resting on an armrest. Fixed pinch thresholds exclude many users.
- **Switch scanning:** auto-scan is about 1 s per step, adjustable in 0.1 s increments. One-switch scanning is recommended when fatigue dominates.
- **macOS built-ins:** the Accessibility Keyboard has Dwell (click, drag, scroll and pause actions, a toolbar, a menu-bar item, hot corners). Head Pointer has speed, camera choice, recenter and a pause switch. Facial expressions can be mapped to clicks.

## Recommendations (ranked)
1. **[OculOS] Tunable dwell.** Default to **1000 ms**, adjustable from 300 to 3000 ms in 100 ms steps. Show a progress ring the user can hide. Destructive targets get about 1.5× dwell.
2. **[Both] Hands-free pause/resume.** Use a 2 s corner glance or a held resting palm, plus a menu-bar item. Start paused after launch or wake.
3. **[ManOS] User-recorded gestures.** Record 3 samples per action. Let the user choose either hand and swap hands without retraining. Detect gestures with the forearm resting, not held up in the air.
4. **[ManOS] Tremor filtering.** Use a One-Euro filter (min cutoff about 1.0 Hz, beta about 0.007) with a heavier "tremor" preset. Require the click pose to be held for at least 150 ms, with hysteresis, so jitter doesn't double-fire.
5. **[OculOS] Snap to targets.** Snap to AX elements within about 60 px and offer a 2× dwell magnifier. Webcam gaze error is about 2–4°, so don't promise pixel-level pointing.
6. **[Both] Work with macOS, not around it.** Offer a cursor-only mode so macOS Dwell or the Accessibility Keyboard handles clicks. Let OculOS or ManOS events act as Switch Control switches. Make the settings fully VoiceOver-labelled.
7. **[OculOS] Fast recalibration.** Use a 5-point recalibration plus drift correction against known targets. Check calibration quality each session and warn about glare, low light or droopy eyelids.
8. **[Both] Fatigue awareness.** Track undo and cancel rates and session length. After about 20 minutes, or when errors rise, suggest a break or a longer dwell. Never lock the user out.
9. **[Both] Undo for unintended selections.** Keep the last 5 synthesized events and offer one undo gesture or gaze target, as a guard against the Midas-touch problem.
10. **[Both] Day profiles.** Offer "Fresh", "Tired" (dwell +50%, more smoothing, wider snap radius) and an OT/caregiver setup mode. Keep all data on the device.

## Things to avoid
1. **Blink-to-click as the default.** Blinks are involuntary and unreliable in ALS. Make it opt-in, with a closure of at least 400 ms.
2. **Fixed pinch or arm-raised gestures.** They exclude users with tremor, cerebral palsy or spinal cord injury and cause fatigue.
3. **Taking over input with no exit.** Always keep a reachable pause, a fallback to macOS Dwell or Switch Control, and recovery after a crash.

## Sources
- https://www.tobiidynavox.com/blogs/support-articles/how-to-set-eye-gaze-dwell-time-on-a-button-in-td-snap
- https://download.mytobiidynavox.com/I-Series/documents/I-Series_User_manual/I-13%20and%20I-16/Tobii%20Dynavox%20I-Series%20I-13_I-16%20Users%20Manual_v1-0-2_en-US.pdf
- https://eyegaze.com/als-and-communication/
- https://eyegaze.com/users/als/
- https://www.researchgate.net/publication/347593073_GazeWheels_Comparing_Dwell-time_Feedback_and_Methods_for_Gaze_Input
- https://doi.org/10.1177/20556683221079694
- https://arxiv.org/html/2002.08455v2
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11015695/
- https://dl.acm.org/doi/fullHtml/10.1145/3290605.3300445
- https://arxiv.org/pdf/1907.02227
- https://www.specialedtechcenter.org/images/PDF/Switch%20Access%20to%20AAC%20Apps-%20Quick%20Reference.pdf
- https://support.apple.com/guide/mac-help/use-dwell-mchl437b47b0/mac
- https://support.apple.com/guide/mac-help/use-head-pointer-mchlb2d4782b/mac
- https://mcmw.abilitynet.org.uk/how-to-use-dwell-in-macos-15-sequoia
- https://mcmw.abilitynet.org.uk/how-to-control-your-computer-with-head-movement-in-macos-13-ventura
