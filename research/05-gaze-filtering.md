# Real-Time Gaze Filtering for Cursor Control

## Summary

VisionGaze's FixationStabilizer is close to the weighted on-off ("Woo") filter: it holds one fixation buffer, fills a second buffer with candidate samples, and switches only after enough of them agree. Špakov (ETRA 2012) compared real-time filters for 30–100 Hz trackers. Filters that detect fixation vs. saccade did best. Dropping the confirmation buffer (his AWoo variant) cut the delay metric by about 4.6x while keeping smoothness. Kumar's EyePoint filter gets the same result with one sample of look-ahead and a time-bounded fixation window. The largest gains for oculOS come from confirming saccades faster, limiting how much history is averaged, and keeping the spring from adding lag after a saccade.

## Key findings

- **Špakov 2012** (Tobii T60, 60 Hz, 11 participants). Scores are RMS px; lower is better.
  - **Woo** (uses an alternate-fixation buffer): delay D ≈ 148–152, smoothness S ≈ 3.1–3.8.
  - **AWoo** (compares only the previous and new output): D ≈ 32, S ≈ 3.2–3.7, closeness C ≈ 5.1. This was best overall, and the triangular-kernel version had the best delay/closeness trade-off.
  - **TWW** (dynamic weighted window, as in Kumar): D ≈ 70–93.
  - **Kalman** had the worst smoothness (S = 10.0, C = 8.15). Savitzky-Golay (D = 133) and a Gaussian filter without state detection (D = 158) were also poor.
  - State detection is the key ingredient. Triangular (Wᵢ = N − i + 1) or Gaussian kernels beat a flat mean.
- **Plain averaging lags after saccades.** The first 1–3 samples of a new fixation get too little weight in a 4–7-point mean. A running mean over the whole fixation is worse still, and it never tracks drift.
- **Kumar et al. 2008** (EyePoint, Tobii 1750 at 50 Hz):
  - Displacement is measured from the *current fixation estimate*, not from the previous sample.
  - A sample over threshold whose *next* sample returns to the fixation is treated as an outlier. This costs one sample of latency (20 ms).
  - The fixation window keeps only the last **400–500 ms**.
  - System lag was about 33 ms (sensor) plus 20 ms (filter), so they added **early-trigger correction**: trigger points are shifted **80 ms** earlier.
  - In their setup, 1° of visual angle ≈ 33 px.
- **Komogortsev 2010:** online I-VT, I-DT and I-HMM performed about the same at their best thresholds. I-HMM matched true behaviour most closely. I-KF was also compared.
- **Velocity thresholds** for I-VT are typically 30°/s (mobile), about 40°/s (static scenes) and about 90°/s (dynamic scenes). At 30 Hz, velocity and acceleration thresholds become unreliable, and dispersion- or density-based detection is recommended instead.
- **Windows Community Toolkit GazeInteraction** smooths the gaze pointer with a **1€ filter** (Beta = 5.0, MinCutoff = 0.1 Hz, VelocityCutoff = 1.0 Hz; the filter rate comes from sample timestamps). Dwell defaults are Enter/Exit 50 ms, Fixation 350 ms and Dwell 400 ms. The 1€ filter shows less lag than other low-pass filters at equal jitter reduction (Casiez 2012).

## Recommendations (ranked)

1. **Replace N-consecutive confirmation with 1-sample look-ahead** (Kumar/AWoo).
   - When sample *k* falls outside the radius, hold the output for one sample.
   - If *k+1* is also outside the radius and near *k*, declare a saccade and reseed the buffer with {k, k+1}. Otherwise drop *k* as an outlier.
   - At 30 Hz this cuts confirmation lag from N×33 ms (100 ms at N = 3) to 33 ms.
2. **Bound and weight the fixation window.** Replace the whole-fixation running mean with a triangular-weighted mean over the last ~450 ms (about 13 samples at 30 Hz). After a saccade, start the window at 2 samples and let it grow (TWW).
3. **Make the spring state-aware.** Stacked on the filter, the spring acts as a second low-pass.
   - On a saccade, snap or use a stiff, critically damped spring that settles in ≤ 60 ms.
   - Within a fixation, smooth with a 1€ filter (tune MinCutoff and Beta) rather than the spring.
4. **Set the radius from each user's measured noise**, not a fixed 30–150 pt range.
   - During calibration, measure the RMS dispersion σ of fixation samples.
   - Set radius = 2.5–3σ, clamped to 30–150 pt, and update σ online from accepted fixations.
   - Use degrees, where 1° ≈ 33–45 pt at 60 cm.
5. **Test for saccades by dispersion from the current centroid, not by sample-to-sample velocity.** If you add I-VT, compute velocity on pre-smoothed positions and keep the threshold at 40°/s or higher.
6. **Add early-trigger correction for dwell and click.** Pick the target from the filtered position about 80 ms before the trigger, and require at least 350 ms of stable fixation before dwell progress starts.
7. **Skip Kalman and HMM for now.** Instead, log raw gaze and score candidate filters offline with Špakov's D/C/S metrics before shipping.

## Sources

- Špakov 2012, Comparison of eye movement filters used in HCI: https://homepages.tuni.fi/oleg.spakov/publications/Spakov_ETRA_12.pdf
- Kumar et al. 2008, Improving the Accuracy of Gaze Input for Interaction: https://graphics.stanford.edu/~klingner/publications/GazeInputAccuracy.pdf
- Komogortsev et al. 2010, Standardization of Automated Analyses of Oculomotor Fixation and Saccadic Behaviors: https://cs.odu.edu/~sampath/publications/journal/IEEE_TOBE_2010.pdf
- Casiez et al. 2012, 1€ Filter: https://direction.bordeaux.inria.fr/~roussel/publications/2012-CHI-one-euro-filter.pdf ; https://gery.casiez.net/1euro/
- Microsoft Gaze Interaction Library: https://learn.microsoft.com/en-us/windows/communitytoolkit/gaze/gazeinteractionlibrary
- GazeInteraction OneEuroFilter.cs: https://github.com/CommunityToolkit/WindowsCommunityToolkit/blob/rel/7.1.0/Microsoft.Toolkit.Uwp.Input.GazeInteraction/OneEuroFilter.cs
- Fixation detection strategies (velocity thresholds): https://link.springer.com/article/10.3758/s13428-024-02360-0
- Webcam eye tracking at 30 Hz: https://pmc.ncbi.nlm.nih.gov/articles/PMC11133145/
