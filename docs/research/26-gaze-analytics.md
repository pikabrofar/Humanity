# 26 — Gaze analytics for UX research

## TL;DR

- Standard AOI metrics (Tobii Pro Lab / Sticky vocabulary): **time to first fixation (TTFF)**, **fixation count**, **total visit (dwell) duration**, **visit count** (revisits = visits − 1), and **% of participants who looked**. They're simple to compute from VisionGaze's I-DT fixations.
- Heatmap σ should be set in **degrees of visual angle** (usually 1–2°) and weighted by **fixation duration** ("absolute duration"). For webcam data, set σ to at least the measured accuracy (~1.5–2°+), not a fraction of image width.
- Webcam tools report ~100–150 px or ~1.5–2° error (RealEye), and worse with head movement. **AOIs must be large (≥2–3° plus margin) and few** (one WebGazer-based study estimated only 4–6 usable AOIs *(unverified)*).
- For scanpaths, use **Levenshtein/Needleman–Wunsch on AOI strings** (ScanMatch-style) first. MultiMatch (5 vector scores) is a later add-on.
- Use **ScreenCaptureKit `SCRecordingOutput`** (macOS 15+) to record the screen for replay, keyed to the same monotonic clock as the gaze samples.

## Key findings

- **Metric definitions (Tobii Pro Lab).** TTFF runs from the start of the interval to the first fixation inside the AOI. A *visit* runs from the start of the first fixation in the AOI to the end of the last consecutive fixation in it, excluding entry and exit saccades. Visit count is the number of such entries.
- **Heatmaps.** Each fixation adds `d · exp(-r²/2σ²)`, with σ ≈ 1–2°. Common variants are fixation count, absolute duration, relative duration (normalized per participant, so no single participant dominates) and participant percentage. The kernel is often truncated at about 3σ.
- **Scanpath comparison.** ScanMatch aligns AOI or grid-letter strings with Needleman–Wunsch, using a substitution matrix based on AOI distance and optionally duration binning, and returns a single score. MultiMatch compares vectorized scanpaths on shape, length, position, direction and duration, giving five scores.
- **Commercial webcam tools.**
  - RealEye: up to 60 Hz, an I-VT-like fixation filter, about 110 px accuracy (best in the center of the screen), 39-point calibration plus a 3-point validation with a 150 px pass threshold. It auto-generates AOIs per SKU and reports TTFF and a "Visual Attention Index".
  - Tobii Sticky: webcam-based, reports AOI metrics.
  - GazeRecorder: about 1.75 cm error in one comparison, with about 9% degradation when the head is free to move *(single study)*.
- **Screen recording.** Since macOS 15, `SCRecordingOutput` writes the `SCStream` straight to .mov without AVAssetWriter, and has delegate callbacks for start and finish.

## How to program it

```swift
struct Fixation { let x, y: Double; let start, end: TimeInterval }  // screen pts
struct AOI { let id: String; let rect: CGRect }
struct AOIMetrics { var ttff: TimeInterval?; var fixCount = 0
                    var dwell: TimeInterval = 0; var visits = 0 }

func aoiMetrics(_ fx: [Fixation], aois: [AOI], trialStart: TimeInterval,
                marginPts: CGFloat) -> [String: AOIMetrics] {
    var out = Dictionary(uniqueKeysWithValues: aois.map { ($0.id, AOIMetrics()) })
    var prev: String? = nil
    var visitStart: TimeInterval = 0, visitEnd: TimeInterval = 0
    func closeVisit() { if let p = prev { out[p]!.dwell += visitEnd - visitStart } }
    for f in fx {
        let p = CGPoint(x: f.x, y: f.y)
        // Inflate AOIs by the tracker's accuracy; smallest hit wins on overlap.
        let hit = aois.filter { $0.rect.insetBy(dx: -marginPts, dy: -marginPts).contains(p) }
                      .min { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }?.id
        if let h = hit {
            out[h]!.fixCount += 1
            if out[h]!.ttff == nil { out[h]!.ttff = f.start - trialStart }
        }
        if hit != prev {                       // AOI transition
            closeVisit()
            if let h = hit { out[h]!.visits += 1; visitStart = f.start }
            prev = hit
        }
        visitEnd = f.end                       // visit = first fix start .. last fix end
    }
    closeVisit()
    return out
}
// AOI string for scanpaths: collapse consecutive repeats -> "ABCA", then Levenshtein.
```

A pixel-per-degree helper, `ppd = screenPx / (2 * atan(screenMM/2 / viewingMM) * 180/π)`, converts σ and the AOI margin from degrees. The viewing distance can come from iris size (see report 03).

## Recommendations for oculOS

1. Change `HeatmapRenderer` to take **σ in degrees** (default max(1.5°, measured validation error)) and a **weighting mode** (count vs duration). Its current radius is a fraction of image width, with σ = r/2.5.
2. Add a **validation step** after calibration, for example 5 points, that stores accuracy and precision in degrees in the session file. Use it to set heatmap σ and AOI margins automatically, and show it in the export.
3. Add an **AOI editor**: draw rectangles on the replay frame, or optionally import Accessibility-element frames as AOIs (ties in with report 09). Compute the metrics above and a per-AOI CSV.
4. Add **session replay**: an `SCRecordingOutput` .mov, plus a gaze CSV with `t_ms, x_px, y_px, valid, fixation_id` in the same time base (`mach_absolute_time`/`CACurrentMediaTime`). Record the video start offset.
5. Export formats: long-form CSV for samples, fixations (`id,start,end,dur,x,y`) and AOI metrics (`participant,aoi,ttff,dwell,fix_count,visits`). Optionally add a JSON sidecar with screen size, PPD, calibration error and app version. This loads directly into R, pandas or Tobii-style workflows. *(No single universal interchange standard exists, as far as I found.)*
6. Scanpaths: add Levenshtein/Needleman–Wunsch similarity on AOI strings. Leave MultiMatch for later.

## Pitfalls

- AOIs smaller than the error margin produce fake "misses" and spill-over into neighbouring AOIs. Report the AOI size in degrees.
- Accuracy is best at screen center and worst at the edges and corners (RealEye). Menu bars and docks are unreliable.
- Scrolling or dynamic content moves AOIs. Record scroll offsets, or define AOIs per video frame or time window.
- Duration weighting lets one long stare dominate. Offer relative (per-participant normalized) heatmaps.
- Fixation-filter parameters change every metric, so record them in the export.
- Screen recording needs the Screen Recording TCC permission. Capture at the display's point scale to match gaze coordinates.

## Sources

- https://connect.tobii.com/s/article/understanding-tobii-pro-lab-eye-tracking-metrics
- https://connect.tobii.com/s/article/What-are-AOI-metrics-in-Sticky
- https://www.realeye.io/features/online-webcam-eyetracking
- https://support.realeye.io/eye-tracking-glossary
- https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11289017/
- https://www.frontiersin.org/journals/robotics-and-ai/articles/10.3389/frobt.2024.1369566/full
- https://www.cambridge.org/core/journals/judgment-and-decision-making/article/webcambased-online-eyetracking-for-behavioral-research/B726E77B68A76577F9BC6BB8F1EBC6E4
- https://link.springer.com/article/10.3758/s13428-012-0212-2 (MultiMatch)
- https://www.researchgate.net/publication/295678842_ScanMatch_A_novel_method_for_comparing_saccade_sequences
- https://link.springer.com/article/10.1007/s11042-017-5091-1 (heatmap kernel/duration weighting)
- https://developer.apple.com/videos/play/wwdc2024/10088/
- https://charleswiltgen.github.io/Axiom/skills/macos/screencapturekit (SCRecordingOutput)

Note: these findings come from search-result summaries, and no pages were fetched in full. Verify the specific numbers before relying on them.
