# Competitor teardown: eye tracking and hand control

| Product | Input / price | Onboarding | Key features | Praise / complaints |
|---|---|---|---|---|
| **Beam Eye Tracker** (Eyeware) | Webcam or phone, paid; 3-hour Steam demo | Install, then calibrate | 6DoF head tracking, OBS gaze overlay, iPhone Face ID as a camera, runs locally | + trial, support. − depends heavily on the webcam: 30 fps is poor and 60 fps is much better. Frame rate matters more than resolution. [steam](https://steamcommunity.com/app/2375780/discussions/0/4633736723121171979), [beam](https://beam.eyeware.tech/) |
| **Tobii ET5 + Experience** | IR bar, ~$250 | ~2-minute dot calibration, first setup needs Windows | Mouse warp with a 1–10 cm dead zone, gaze overlay, dims the screen when you look away | + quick calibration. − calibrates the wrong screen when displays are mirrored; data is coarse and needs heavy filtering. [helisimmer](https://www.helisimmer.com/reviews/tobii-eye-tracker-5), [tobii](https://help.tobii.com/hc/en-us/articles/360011075918-Windows-Interaction-features-for-ET5) |
| **Precision Gaze Mouse** | Free, open source, Tobii | Minimal | Gaze moves the cursor near the target, then the head refines; the cursor stays still until gaze leaves a 1–4 cm radius | + fixes jitter. [techspot](https://www.techspot.com/downloads/7173-precision-gaze-mouse.html) |
| **Talon** eye tracking | Free/Patreon, Tobii | Community scripts | "Control mouse" (eyes plus head); "zoom mouse" (zoom in, then click); click by sound, voice or pedal | + power users. − needs a $250 tracker; the cursor moved after clicks until it was fixed. [changelog](https://talonvoice.com/dl/latest/changelog.html) |
| **iOS Eye Tracking** | Built in | ~30-second dot follow | Dwell click, Snap to Item | − dwell causes accidental input; the cursor wanders; accuracy drops after you move. [pocket-lint](https://www.pocket-lint.com/how-to-use-eye-tracking-on-apple-iphone/) |
| **macOS Head Pointer** | Built in | Toggle in Settings | Head moves the pointer; facial expressions trigger clicks | The free baseline to beat. [apple](https://support.apple.com/guide/mac-help/use-head-pointer-mchlb2d4782b/mac) |
| **Camera Mouse** (Boston College) | Free, Windows | Click a face feature to track | Dwell click | + over 3M downloads. − 8.1% dwell error rate, 1.28 bits/s throughput. [springer](https://link.springer.com/chapter/10.1007/978-3-319-58703-5_34) |
| **Enable Viacam / Tracky Mouse** | Free, open source | Automatic | Head mouse, dwell toolbar | + tunable speed and acceleration. [tracky](https://trackymouse.js.org/) |
| **Project Gameface** | Free, open source | Choose gestures and their sizes | 52 face blendshapes, a threshold for each | + customizable. [google](https://blog.google/innovation-and-ai/products/google-project-gameface/) |
| **GitHub gesture mice** | Open source | "Run the script" | Pinch click, 1€/EMA filter plus dead zone, timer to tell click from drag | Jitter is the top complaint; one project reports 86% less jitter at rest. [mausely](https://github.com/mahdidigitalx-oss/mausely) |
| **Leap Motion** | IR hardware | Visualizer | Mid-air pointing | − "gorilla arm" fatigue, unreliable clicks; 7.8% error rate vs 2.8% for a mouse. [mdpi](https://www.mdpi.com/1424-8220/15/1/214/xml) |

## Lessons

1. **OculOS: don't use raw gaze as the cursor.** Use gaze to move the cursor
   near the target, then refine it. Use a hold radius (1–10 cm), warp only on a
   trigger, and add a zoom-to-click or head-refine step.
2. **OculOS: expect accuracy to drift.** Show a "head in calibration zone"
   indicator and offer a quick re-calibration from the menu bar. Store which
   display each calibration belongs to, and handle mirrored displays.
3. **Both: test the camera during onboarding.** Measure fps and lighting, set
   expectations, and suggest Continuity Camera.
4. **ManOS: provide a 1€ smoothing slider** and freeze the pointer at the
   moment of a pinch.
5. **ManOS: avoid gorilla arm.** Use relative, trackpad-like pointing with gain
   so the elbow can rest, keep the clutch, and include practice.
6. **ManOS: make gestures distinct and thresholds per user,** with a visible
   state overlay and a kill switch.
7. **OculOS: offer several ways to click, without dwell as the default.**
   Use a hotkey, gaze plus a ManOS pinch, or optional dwell with a ring.
   Snap-to-item helps at 2–5° accuracy.
8. **Both: lead with privacy, a free Mac-native setup, and a live preview.**
   Ship a gaze overlay for streaming and an instant "try it" mode. Beat Head
   Pointer on setup speed and precision.
