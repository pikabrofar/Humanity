# Evaluating and Benchmarking OculOS and ManOS

## Summary

Both projects are tested only on synthetic data, so nothing yet shows how they perform for real users. Eye-tracking data quality is reported as **accuracy, precision (RMS-S2S and STD), and data loss**, measured on validation targets the model did not train on. Pointing devices are compared by **Fitts throughput (bits/s)** from the ISO 9241-411 multi-directional tapping task, which yields one number that can be set beside published mouse and touchpad figures. Latency has to be timed from **frame capture**, not from when a result is emitted. Measured that way, browser webcam gaze runs about 22–52 ms, and an emit-time measurement reads about 0 ms.

## Key findings

- **Eye-tracking metrics (Holmqvist, Nyström & Mulvey 2012).** Accuracy is the mean angular offset from the target. Precision has two measures. RMS-S2S is the root-mean-square of successive sample differences during a fixation. STD is the spread around the fixation centroid. Data loss is lost samples divided by expected samples. Across 12 trackers, RMS-S2S differed by up to two orders of magnitude, so both precision measures need to be reported.
- **Reporting standard.** Use the consensus *Minimal reporting guideline for research involving eye tracking (2023 edition)* (Dunn et al., BRM 56:4351–57). Do not cite Holmqvist et al. 2022, "empirical foundations for a minimal reporting guideline": it was **retracted in November 2023**.
- **Webcam baselines.** WebGazer reports about 4.17° in the lab. Measured as deployed, it lands at 8–11° (11.1° for N=1 in one capture-clock study). A commercial webcam system reached 1.4° accuracy and 1.1° precision against an EyeLink 1000, about 0.5° worse than the EyeLink. Results vary widely between participants and degrade with glasses.
- **Latency (capture-clock method, arXiv 2608.11566).** Timestamp each sample with its source frame's capture time from `requestVideoFrameCallback`. FaceMesh-based gaze measured 22–34 ms median and about 27 ms p95. WebGazer measured about 33 ms median and 51–52 ms p95. Report accuracy and precision separately; they do not move together.
- **End-to-end latency** (motion to photon) is measured with a 240 fps phone camera filming the hand and the screen together, or with photodiodes.
- **Fitts / ISO 9241-411 method.** Place targets in a circle and use several A×W combinations. Compute W_e = 4.133·SD_x of the selection endpoints along the task axis, and use the effective amplitude A_e. Calculate TP = ID_e/MT for each sequence, then average those values (the "mean of means"). Record the x-y coordinates of every selection.
- **Throughput baselines.** Mouse 3.7–4.9 bits/s. Touchpad about 1.9–2.3 bits/s. Smartphone touch about 6.85 bits/s. Leap Motion mid-air pinch 2.21 bits/s with 1.99% errors, tap 2.29, dwell 1.75 (N=12). Gaze sits lower again and has high error rates: in one XR comparison gaze had 19.1% errors and hand input 1.8%.

## Recommendations (ranked)

1. **Ship a built-in Fitts test in ManOS (and in OculOS's gaze-pointer mode).** Use ISO 9241-411 circles of 13–20 targets, 3 amplitudes × 2–3 widths, and 2+ blocks. Log every selection's x/y, the target, MT, and whether it was an error. Report TP_e as a mean of means, the error rate, and the click-induced cursor jitter at pinch. Run the same test with the user's own mouse or trackpad so each result has its own baseline.
2. **Add a OculOS validation screen that uses held-out targets.** Show a fresh 9–13-point grid, none of which were calibration points, with 1–1.5 s fixations, and drop the first 300 ms of each fixation. Report accuracy (°, mean and per target), RMS-S2S and STD (°), and data loss (%). Convert pixels to degrees using the measured viewing distance and screen PPI. Repeat at 0, 5 and 15 minutes to capture drift.
3. **Measure latency from capture time and publish p50/p95/p99.** Break it into stages (capture→landmarks→filter→OS event). Add an optional "flash-on-pinch" mode that changes a screen corner's colour when a click fires, so users can check end-to-end latency with a 240 fps phone video.
4. **Build a record/replay harness.** Record versioned sessions containing raw landmark streams (MediaPipe face and hand), capture timestamps, screen geometry, and ground-truth targets or clicks, with no video by default. Replay them through the filter, calibration and pinch logic in CI. Assert accuracy and TP within set tolerances, plus pinch false-positive and false-negative rates. Collect at least 10–20 consented recordings that cover glasses, low light, darker skin tones, and varied backgrounds.
5. **Publish results the way the field expects.** Follow the Dunn 2023 checklist. Report N, demographics, hardware (camera model, resolution, fps), lighting, viewing distance, the calibration and validation protocol, and per-participant distributions, not only means. Present results as "as deployed" and state plainly that we are not lab-grade (EyeLink is below 0.5°). Put the raw data and analysis scripts in the repo.
6. **Add an opt-in "Export benchmark" button** that writes a JSON file anyone can attach to a GitHub issue. Each file carries the build hash, device, metrics and environment.

## Sources

- https://www.researchgate.net/profile/Kenneth-Holmqvist/publication/254007815_Eye_tracker_data_quality_What_it_is_and_how_to_measure_it/links/54db175a0cf2ba88a68f0b76/Eye-tracker-data-quality-What-it-is-and-how-to-measure-it.pdf
- https://www.researchgate.net/profile/Kenneth-Holmqvist/publication/321678981_Common_predictors_of_accuracy_precision_and_data_loss_in_12_eye-trackers/links/5a2a9401aca2728e05de621d/Common-predictors-of-accuracy-precision-and-data-loss-in-12-eye-trackers.pdf
- https://github.com/dcnieho/ET_reporting_guideline
- https://ora.ox.ac.uk/objects/uuid:84769290-f0b6-4e59-9b1f-b7cd54f49f99
- https://link.springer.com/article/10.3758/s13428-021-01762-8 (retracted)
- https://arxiv.org/html/2608.11566
- https://cs.brown.edu/people/apapouts/papers/ijcai2016webgazer.pdf
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11289017/
- https://www.yorku.ca/mack/hhci2018.html
- https://www.yorku.ca/mack/ijhcs2004.pdf
- http://www.yorku.ca/mack/iss2022.html
- http://www.yorku.ca/mack/jmui2025.pdf
- https://arxiv.org/html/2603.15991
- https://www.biorxiv.org/content/10.1101/2022.06.24.497509v1.full
- https://epub.uni-regensburg.de/45570/1/yet-another-latency-measuring-device.pdf
