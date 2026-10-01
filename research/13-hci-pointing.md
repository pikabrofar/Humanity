# HCI Pointing Research for OculOS and ManOS

**Summary.** Gaze is fast but imprecise and should not click by itself. Mid-air hands carry about 35% less information per second than a mouse, and the click gesture itself moves the pointer. OculOS (2–5° error) should use gaze to get near a target and finish with a hand, zoom or moving target. ManOS's biggest losses are pinch jitter and a poor transfer function.

## Key findings

- **Fitts throughput (ISO 9241-9/411).**
  - Mouse: about 4–5 bits/s.
  - Leap Motion mid-air: 2.7 bits/s against 4.2 for the mouse, with 7.2% errors against 2.3%. It saturated near ID 3.2.
  - Eye pointing: 3.78 bits/s with a spacebar to select, 1.79 with dwell, 1.16 with blink.
  - Webcam head pointing (Camera Mouse): 0.65–0.85 bits/s.
- **Gaze target size (Feit, CHI 2017).** Targets were sized so 95% of gaze samples land inside. Even with an IR tracker, 1.9 × 2.35 cm covers 75% of users with filtering, and 3.28 × 3.78 cm without it. Accuracy varied more than 6x between users and was worst at the bottom and right edges. At 60 cm, 1° ≈ 1.05 cm, so 2–5° of error is about 2–5 cm (about 100–270 pt on a MacBook). A 22 pt menu-bar item is about 10x too small.
- **MAGIC (Zhai 1999).** Gaze warps the cursor near the target and the hand finishes. *Liberal* MAGIC warps whenever gaze moves more than 120 px and feels overactive. *Conservative* MAGIC warps only when the hand starts to move. Both reduced fatigue compared with manual pointing.
- **Gaze + Pinch (Pfeuffer 2017).** Look to select, then pinch indirectly to commit, with the hand anywhere. visionOS later shipped this model. Looking never commits an action, which avoids the Midas-touch problem.
- **Pursuits / Orbits (Vidal 2013; Esteves 2015).** A target is selected when Pearson r is above **0.8 on both axes** over **0.5–1 s (20–30 samples)**. It needs no calibration and tolerates a constant offset.
- **Dwell (Jacob 1990).** Typical fixed dwell is 450–1000 ms, and 750 ms gave lower throughput than 500 ms. With adjustable dwell, users went from about 876 to about 282 ms over 10 sessions (Majaranta 2009; these figures are from memory, so verify them).
- **Heisenberg effect (Wolf, CHI 2020).** The click itself displaces the pointer and caused **30.45% of errors**. The shift is systematic (upward), and a correction removed 25.4% of those errors.
- **Expansion and zoom.** Invisible motor-space expansion improved gaze speed and accuracy. Zoom without lower cursor gain does not improve accuracy and makes jitter more visible.
- **Transfer functions.** Gain that depends on velocity beats constant gain (Casiez & Roussel). The 1€ filter adapts its cutoff to speed, using `mincutoff` for jitter and `beta` for lag.

## Recommendations (ranked)

1. **[OculOS] Never let gaze alone click.** Commit with a pinch (Gaze + Pinch with ManOS), a key or a pursuit match. If dwell is required, start at 600–800 ms, let the user tune it down to about 300 ms, and show a progress ring.
2. **[ManOS] Freeze the pointer at pinch onset.** When the finger gap starts closing, use the cursor position from 100–150 ms earlier and ignore motion until the pinch is confirmed. This targets about 30% of errors.
3. **[OculOS] Snap to targets instead of showing a free cursor.** Make effective hit areas at least 2x the error: about 5–10 cm at 60 cm. Use the macOS accessibility tree to get target positions, with invisible expanded hit areas.
4. **[Both] Use conservative MAGIC.** Warp to the gaze point only when the hand starts moving and the gaze point is more than about 120 px (about 3°) away. ManOS then finishes in relative mode at low gain.
5. **[ManOS] Use a 1€ filter with velocity-based gain.** Start at `mincutoff` 1.0 Hz and `beta` 0.007, then tune. Use CD gain below 1 when slow and higher gain when fast.
6. **[OculOS] Use pursuits for dense or small targets.** Put 2–8 candidates on distinct orbits and select at r > 0.8 on both axes over 0.5–1 s. This survives calibration drift.
7. **[OculOS] Zoom only when the target is ambiguous.** Use a 2–3x magnifier only when more than one target is inside the error circle. Lower gain or keep snapping inside the zoom.
8. **[ManOS] Plan for about 2.7 bits/s.** Avoid ID > 3.2 and keep frequent targets large and near the hand's resting position.
9. **[OculOS] Avoid the bottom and right edges for critical targets.** Weight recalibration toward those regions and show per-user accuracy.
10. **[Both] Benchmark with ISO 9241-411 multidirectional tapping.** Track throughput and error rate for each release.

**Possible design mistakes:**
- Gaze-only dwell clicking on native-size macOS controls.
- Liberal MAGIC (constant warping).
- Reading the click position at pinch release.
- Webcam head pointing as a fallback, which scored lowest (about 0.7 bits/s) in the studies cited.

## Sources
- https://www.yorku.ca/mack/45520779.pdf
- https://pmc.ncbi.nlm.nih.gov/articles/PMC4327015/
- https://www.yorku.ca/mack/hcii2019.html
- https://www.researchgate.net/publication/316653598_Toward_Everyday_Gaze_Input_Accuracy_and_Precision_of_Eye_Tracking_and_Implications_for_Design
- https://dl.acm.org/doi/10.1145/302979.303053
- https://userweb.cs.txstate.edu/~ok11/papers_published/2012_CHI_Fa_Do_Ko.pdf
- https://3dvar.com/Pfeuffer2017Gaze.pdf
- https://arxiv.org/pdf/2401.10948
- https://doi.org/10.1145/2493432.2493477
- https://www.hcics.simtech.uni-stuttgart.de/publications/esteves15_uist.pdf
- https://dl.acm.org/doi/abs/10.1145/3313831.3376876
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12218499
- https://arxiv.org/pdf/1704.06399
- https://dl.acm.org/doi/abs/10.1145/3025453.3025517
- https://gery.casiez.net/1euro/
