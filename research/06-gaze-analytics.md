# Gaze Analytics: What VisionGaze Recordings Should Add

## Summary

Commercial tools (iMotions, Tobii Pro Lab, Tobii Sticky, RealEye, GazeRecorder) and open-source ones (OGAMA, PsychoPy/ioHub) are built on the same few things: **Areas of Interest (AOIs) with a standard metric set**, **gaze replay over the stimulus or a screen recording**, **aggregation across participants**, and **tabular export**. VisionGaze already has heatmaps, I-DT fixations, scanpaths and PNG/CSV export. What it lacks is AOIs, replay, multi-session aggregation and a standards-based export. Webcam accuracy is about 2–4° (RealEye reports about 106 px on desktop). That means VisionGaze should target large AOIs and coarse metrics, and skip word-level reading analysis.

## Key findings

- **The AOI metric set is the same everywhere.** Tobii Pro Lab defines Time to First Fixation (TTFF) as the time from interval start to the first fixation inside the AOI. A visit runs from the first fixation in the AOI to the last one before gaze leaves. Dwell time is all time inside the AOI, revisits included. iMotions exports dwell time, TTFF, revisits, fixation count and *respondent ratio* (the share of participants who looked at the AOI). RealEye adds "viewed by", average revisits, average first view and time per view. GazeRecorder gives only dwell time, first view and viewer count. So even a minimal webcam tool is expected to have AOIs.
- **Exports are per-AOI × per-participant tables.** iMotions has an "AOI Metric Respondent" CSV, and RealEye has an "AOI overall stats" CSV. Researchers want one row per (participant, AOI), not raw samples only.
- **Gaze replay over screen recordings is a core feature.** GazeRecorder's main output is a dynamic heatmap video overlaid on a screen recording. iMotions has single-participant replay plus *Aggregate Replay*, which shows many participants at once. OGAMA (open source, C#) centres on replay, attention maps, AOIs and a statistics module.
- **Multi-participant aggregation is expected.** Every tool here can pool sessions on the same stimulus into one heatmap and averaged AOI stats.
- **Standard export now exists.** BIDS eye-tracking (BEP020, now in the spec) uses `_physio.tsv.gz` plus a JSON sidecar. The columns are `timestamp, x_coordinate, y_coordinate[, pupil_size]`. The sidecar sets `PhysioType: "eyetrack"`, `SamplingFrequency`, `RecordedEye` ("cyclopean" fits a webcam), `SampleCoordinateSystem: "gaze-on-screen"`, units, and calibration fields such as `AverageCalibrationError`. Events like fixations, saccades and messages go in `_physioevents.tsv.gz` (onset, duration, trial_type, message). PsychoPy/ioHub uses HDF5 instead, which is more friction for casual users.
- **Webcam accuracy rules out fine-grained analysis.** Webcam trackers are accurate to about 3–4° for WebGazer, about 2.4° for the newer FAZE deep-learning model, and about 106 px for RealEye. Lab trackers manage 0.25–0.5°. Studies conclude webcam tracking is "inappropriate" for analysis at the letter or word level. A 100 px error crosses words and lines. Large-AOI paradigms are the recommended use. The Penn webcam reading study found line-level and region-level reading measures workable, but word-level measures were not.

## Recommendations (ranked)

1. **Rectangle AOIs with the standard metrics.** Let users draw named rectangles on the session's screenshot background. For each AOI, compute TTFF, dwell time, fixation count, visit/revisit count, first-fixation duration, and % of session time. Show a warning when an AOI is smaller than about 2× the measured calibration error (e.g. under ~200 px on a laptop).
2. **Per-AOI CSV export plus an accuracy record.** Write an `aoi_metrics.csv` with one row per (session, AOI). Save each session's validation error (px and approximate degrees) in its metadata, so users can filter out bad sessions.
3. **Gaze-overlay replay.** Scrub through a session with a moving gaze dot, a short fixation trail and an optional rolling heatmap over the screenshot or a recorded screen video. Export it as MP4/GIF using AVFoundation. This is the feature UX users notice most (GazeRecorder, iMotions).
4. **Multi-session aggregation.** Select N sessions that share a stimulus or screen region and produce a pooled heatmap, averaged AOI metrics, and "viewed by X/N" (respondent ratio). Normalize each session's coordinates to the screen size before pooling.
5. **BIDS eye-tracking export.** Add a one-click export of `sub-XX_task-YY_recording-eye1_physio.tsv.gz` plus JSON. Use `RecordedEye: "cyclopean"` and `gaze-on-screen` coordinates in pixels, and fill `ScreenSize`/`ScreenResolution`/`AverageCalibrationError`. I-DT fixations go in `_physioevents.tsv.gz`. It's cheap to add and gives VisionGaze research credibility.
6. **Event markers.** Add hotkey or API markers that appear as `message` rows and split a session into intervals, so TTFF is measured per interval and not only from session start.
7. **Coarse reading analysis only.** Detect line-level progression (return sweeps, regressions between lines, reading versus skimming) for text that is large enough. Don't offer word-level metrics. State that limit in the UI.
8. **Defer:** dynamic or moving AOIs, saliency models, a Visual Attention Index-style composite score, and pupil metrics. None of these are reliable with a webcam.

## Sources

- https://connect.tobii.com/s/article/understanding-tobii-pro-lab-eye-tracking-metrics?language=en_US
- https://connect.tobii.com/s/article/What-are-AOI-metrics-in-Sticky?language=en_US
- https://imotions.com/blog/learning/10-terms-metrics-eye-tracking/
- https://imotions.com/blog/learning/product-guides/screen-based-eye-tracking-module/
- https://imotions.com/products/imotions-lab/features/analysis/
- https://support.realeye.io/areas-of-interest-aois
- https://support.realeye.io/aoi-overall-stats-csv
- https://www.realeye.io/features/online-webcam-eyetracking
- https://gazerecorder.com/gazerecorder/
- https://link.springer.com/content/pdf/10.3758/BRM.40.4.1150.pdf (OGAMA)
- https://psychopy.org/api/iohub/index.html
- https://bids-specification.readthedocs.io/en/latest/modality-specific-files/physiological-recordings.html
- https://github.com/bids-standard/bids-specification/pull/1128
- https://www.biorxiv.org/content/10.64898/2026.02.03.703514v1 (Eye-Tracking-BIDS)
- https://www.cambridge.org/core/journals/judgment-and-decision-making/article/webcambased-online-eyetracking-for-behavioral-research/B726E77B68A76577F9BC6BB8F1EBC6E4
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11133145/
- https://learninganalytics.upenn.edu/ryanbaker/BRMWebcamGaze.pdf
- https://www.sciencedirect.com/science/article/pii/S2772766125000655
