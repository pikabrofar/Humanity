# Gesture Vocabulary Design for ManOS

## Summary

ManOS's core set (relative pointer, thumb–index pinch, thumb–middle pinch, fist clutch, spread-palm pause) already matches what the major platforms converged on. visionOS, Quest and Mudra all build on a pinch "click", pinch-and-hold to drag or scroll, and very few extra poses. The research and the platform guidelines agree on three points. Every extra gesture costs learnability and adds false positives. A custom gesture should exist only when the standard set can't do the job. Gestures should be gated by an explicit delimiter, not spotted out of free movement. So ManOS's next step should be one gated "command layer" with a directional HUD, not a pile of new static poses.

## Key findings

- **Elicitation studies favor familiar gestures, and legacy bias helps here.** Wobbrock-style elicitation is the dominant method for mid-air gestures (about 77% of reviewed studies). Users pull strongly toward WIMP and trackpad metaphors. For a desktop mouse replacement, that bias is useful: gestures that mirror trackpad swipes (Spaces, Mission Control) will be guessed and remembered. User-defined gestures are easier to recall than designer-invented ones.
- **Microgestures are dominated by the thumb.** Elicitation work on single-hand microgestures, and Meta's shipped set, centre on the thumb acting on the index finger. Meta's set is five discrete events: a tap, plus swipes left, right, forward and back along the index finger. It needs a specific pose (fingers loosely curled, not a fist) and fires at the *end* of the motion, which cuts false triggers.
- **Keep the vocabulary small and the poses distinct.** Ultraleap says abstract poses are "difficult to recall unless people use the application regularly". It recommends introducing them one at a time, keeping them highly distinct, and keeping a help screen reachable. Apple's HIG adds more rules for custom gestures. They should be easy to explain. They must not clash with system gestures or with hand movements people make while talking. They need a low false-activation rate and should not be culturally loaded. Every one needs a UI fallback.
- **Mudra (Mac/Apple TV) uses a deliberately tiny set.** It has an air-mouse pointer, tap, pinch-and-hold, pinch-and-swipe and twist, plus a user Gesture Mapper for media and shortcut bindings. The fixed core stays small, and the user binds extra actions.
- **False activation is the dominant failure.** A study of natural background movement found large numbers of spurious matches, roughly one every few seconds per person for naive recognizers. Delimiters (clutches) work better than dwell, because dwell adds a delay to every input. Ultraleap recommends hysteresis on pinch: a lower release threshold than activation threshold.
- **Confusable pairs for a single RGB webcam.** Thumb–middle and thumb–ring pinches are hard to tell apart because of occlusion and the lack of depth. So are a pinch and a near-pinch, a fist and the curled pose used for microgestures, and the open-palm "pause" and an ordinary wave or "stop" gesture in conversation.

## Recommendations (ranked)

1. **Add one command layer behind a distinct, held delimiter.** Use a V-pose (index and middle fingers extended, others curled) held for about 300 ms. It is unlike any existing ManOS pose. Once in the layer, a directional hand flick sends a trackpad-like shortcut:
   - up: Mission Control (⌃↑)
   - down: App Exposé (⌃↓)
   - left/right: switch Space (⌃←/→)

   Fire on flick *completion*, as Meta does. Exit when the pose is released or after 2 s. This covers app switching and Spaces without new always-on gestures.
2. **Make that layer a marking menu with a HUD.** If the user holds the V-pose without flicking for about 400 ms, show a radial overlay at the cursor labelling each direction. Novices read it, and experts flick before it appears. This handles discoverability and the move from novice to expert in one mechanism.
3. **Harden the existing gestures against accidental triggers:**
   - Add pinch hysteresis: activate at a normalised distance of about 0.25 and release at about 0.35.
   - Add a 2–3 frame debounce.
   - Require the palm to face the camera and sit inside an "active zone" before any click fires.
   - Make the spread-palm pause also require the hand to be nearly still (low velocity) during the 1 s hold, so waving or talking doesn't pause the app.
4. **Don't add a thumb–ring pinch, and don't copy Meta's thumb-on-index D-pad yet.** Both depend on depth detail that a 2D webcam tracks poorly, and both are easily confused with the existing pinches. Revisit with a depth camera.
5. **Zoom and media go through bindings, not new poses.** Map zoom to the thumb–middle pinch held with a vertical drag while the command layer is active, sent as ⌘+scroll. Put media (play/pause, next, volume) on user-bindable command-layer slots, such as diagonal flicks, using a Mudra-style mapper in Settings. Ship fixed defaults for the four cardinal directions only.
6. **Teach in the app, in stages.** Use a first-run tutorial that unlocks one gesture at a time: pointer, click, drag, right-click and scroll, clutch, pause, then the command layer. Draw a live hand skeleton in which the fingertips glow when a pinch registers. When a pose is detected at 60–80% confidence, show a "near miss" hint. Keep a menu-bar cheat sheet, and give every action a menu-bar equivalent as Apple's fallback rule requires. Pair visual feedback with a soft click sound.
7. **Measure false positives directly.** Add a local-only "background test": record 5 minutes of the user typing, talking and drinking with the recognizer live, then log spurious events per minute for each gesture. Use it as a release gate, aiming for fewer than one spurious command per 10 minutes. Keep the ⌃⌥⌘H kill switch as the last resort.

## Sources

- https://www.researchgate.net/publication/328036083_Gesture_Elicitation_Studies_for_Mid-Air_Interaction_A_Review
- https://arxiv.org/pdf/2104.04685
- https://vvise.iat.sfu.ca/pubs/chan2016microgestures
- https://www.uploadvr.com/meta-quest-sdk-v74-thumb-microgestures-improved-audio-to-expression/
- https://developers.meta.com/horizon/documentation/unity/unity-microgestures/
- https://developer.apple.com/videos/play/wwdc2023/10073/
- https://docs.ultraleap.com/xr-guidelines/Interactions/hand_poses.html
- https://docs.ultraleap.com/xr-and-tabletop/xr/unity/plugin/features/pinch-and-grab-detection.html
- https://support.mudra-band.com/hc/en-us/articles/4895488844061-What-gestures-and-movements-does-the-Mudra-Band-recognize
- https://mudra-band.com/blogs/blog-posts/turn-gestures-into-media-control-keys
- https://arxiv.org/html/1509.06109v1
- https://dl.acm.org/doi/10.1145/3780045.3780047
