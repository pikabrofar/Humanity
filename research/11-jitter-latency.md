# Jitter, Latency and Click Stability for ManOS

## Summary

ManOS's current setup (30 fps Vision hand pose, 1€ filter at 1 Hz / beta 0.8, 100 ms click rewind, pinch hysteresis 0.30/0.45 palm with 2-frame debounce) is a reasonable baseline. Three things will help most. First, rewind each click to the moment the pinch started instead of a fixed 100 ms back. Second, place the cursor on a hand point the pinch doesn't move. Third, measure latency per stage before adding prediction. Prediction can hide part of the roughly 100 ms pipeline delay, but only at high hand speeds and over a short horizon. Tremor needs its own filter mode, because the 1€ filter's speed term opens the filter up when tremor makes the hand move fast.

## Key findings

- **1€ filter tuning (Casiez):** start with beta = 0 and minCutoff ≈ 1 Hz. Hold the hand still and lower minCutoff until jitter is acceptable. Then move fast and raise beta, stepping by factors of 10 (try 0.001 and 0.0001 first), until lag is acceptable. Beta depends on the units, so 0.8 in palm units is not comparable to published defaults.
- **Lag from the current filter:** at minCutoff 1 Hz the time constant is 1/(2π·1) ≈ **159 ms**, so at 30 fps the smoothing factor is ≈ 0.17. A slow drift therefore trails by about 160 ms on top of the pipeline delay. With beta 0.8, a hand moving at 5 palm/s gets a cutoff of about 5 Hz (≈ 32 ms).
- **Cost of lag:** in a Fitts' law (pointing) task, 225 ms of lag raised movement time by **64%** and error rate by **214%** compared with no lag (MacKenzie & Ware 1993). The performance loss grows steadily with lag.
- **Prediction:** double exponential smoothing (DESP) predicts as accurately as Kalman/EKF filters at a **100 ms** horizon on hand data and runs about **135× faster** (LaViola 2003). The formula is p(t+τ) = (2 + ατ/(1−α))·S − (1 + ατ/(1−α))·S², where S and S² are the singly and doubly smoothed positions. The best α for hand data at 70 Hz was about 0.45–0.9. Predicting the full latency amplifies jitter and overshoot at direction changes.
- **Heisenberg effect, meaning the pointer moves as the user clicks (Wolf et al. CHI'20, controllers):** it caused **30.5%** of errors in fast pointing and **82%** in stationary pointing. The mean shift was **0.66°**. A full click took about **270–310 ms**. The shift grew roughly in step with how far the trigger was pressed (ρ = 0.74). It was mostly in one direction: 78% of shifts went upward. Subtracting a global offset cut Heisenberg errors from 11.8% to 9.5%, and per-condition offsets cut them to 8.8%.
- **Pinch on bare hands (Qiu et al. 2026):** the Heisenberg effect caused **80.6%** of selection errors. Pinch onset was detected as thumb–index closing speed **> 0.05 m/s for ≥ 3 frames**, then searching backward to the last stable frame. A 0.4 s intention-history window worked for picking the target after the fact.
- **Tremor:** essential tremor is **4–12 Hz**. Parkinson's tremor is mostly **4–6 Hz** at rest, and a postural tremor can return when the hand is held up. At 30 fps the highest frequency the camera can capture is 15 Hz, so all of this tremor reaches the filter. A first-order 1 Hz low-pass passes only about 20% at 5 Hz, but tremor speed raises the 1€ cutoff. For example, tremor of 0.05 palm amplitude at 6 Hz moves at about 1.9 palm/s, which lifts the cutoff to about 2.5 Hz.
- **Measuring latency:** the end-to-end standard is filming the input and the screen with a high-speed camera, or Casiez's optical-mouse method for the display stage. For ManOS, software timestamps (capture → Vision → filter → posted event) show where the time goes.

## Recommendations (ranked)

1. **Rewind the click to pinch onset, not a fixed 100 ms.** With a 2-frame debounce (67 ms) plus a 100–200 ms finger closure, onset is usually more than 100 ms in the past. Keep a ring buffer of the last 0.4 s of *displayed* cursor positions. On a click, set the click position to the cursor at the last frame where thumb–index aperture speed was near zero before closing. Clamp the rewind to 50–250 ms.
2. **Anchor the cursor away from the pinching fingers.** Drive the cursor from the palm centroid (wrist plus index and middle base knuckles) rather than the index tip, which moves during the pinch itself.
3. **Freeze the cursor during the pinch.** When the aperture drops below about 0.6 palm and is shrinking, cut the cursor gain to about 0.2×. Hold the cursor still from the click until release or until the hand moves more than about 0.5 palm (drag threshold).
4. **Instrument latency before tuning.**
   - Log CMSampleBuffer presentation time, Vision completion time and CGEvent post time. Report the median and 95th percentile (p95).
   - For end-to-end latency, film a sharp hand movement and the screen in 240 fps slow motion (4.2 ms per frame). Take 20 trials.
   - Set `alwaysDiscardsLateVideoFrames = true`.
   - Use 60 fps when the camera supports it (Continuity Camera does). This cuts frame wait and debounce time in half.
5. **Debounce by time, not frames:** use ≥ 40 ms, or 1 frame at 60 fps, plus the existing hysteresis.
6. **Retune the 1€ filter with the Casiez procedure** and make it a 15-second calibration step. Expect minCutoff around 0.5–1.5 Hz. Keep dcutoff at 1 Hz, because it smooths the speed estimate and keeps tremor from opening the filter. Search beta in powers of 10 around the current 0.8.
7. **Add gated prediction:** use DESP or an alpha-beta filter with a **30–50 ms** horizon, not the full latency. Fade it in only above about 2 palm/s and turn it off during pinches.
8. **Add a tremor mode:**
   - During calibration, run an FFT on a 3 s hold and find the strongest frequency in the 4–12 Hz band.
   - Use a 2nd-order Butterworth low-pass at about 2.5 Hz, or a notch filter at that frequency, in front of the 1€ filter.
   - Use minCutoff 0.3–0.5 Hz and cap the speed term.
   - Offer dwell-to-click and larger snap targets.
9. **Optional:** learn a per-user offset correction from the systematic click shift, which gives about a 25% error reduction in Wolf et al.

## Sources

- https://gery.casiez.net/1euro/
- https://www.uni-ulm.de/fileadmin/website_uni_ulm/iui.inst.100/institut/mitarbeiterbereiche/wolf/HeisenbergCHI20.pdf
- https://arxiv.org/pdf/2602.01061
- https://cs.brown.edu/people/jlaviola/pubs/kfvsexp_final_laviola.pdf
- https://www.yorku.ca/mack/CHI93b.html
- https://dl.acm.org/doi/fullHtml/10.1145/3603555.3603556
- https://gery.casiez.net/turbotouch/lagmeter/lagmeterUIST15.php
- https://www.msdmanuals.com/professional/neurologic-disorders/movement-and-cerebellar-disorders/tremor
- https://reunir.unir.net/server/api/core/bitstreams/8f1b1fb7-ff17-4fe1-a32e-9c56c35d92c7/content
