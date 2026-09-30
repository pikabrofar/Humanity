# 05: Filtering and eye-movement event detection

Scope: denoising webcam gaze (about 30 fps, 2–4° accuracy) and hand-pointer landmarks, plus online fixation/saccade detection. Items marked **[unverified]** come from memory; I could not open the primary PDF (several publisher and author hosts were blocked by the egress proxy).

## TL;DR

- **Hand pointer: use the One Euro filter (1€).** It is a first-order low-pass filter whose cutoff rises with speed. Tune it in two steps: set `beta = 0` and lower `minCutoff` until the pointer stops jittering at rest, then raise `beta` until fast moves stop lagging.
- **Gaze: do not rely on a plain low-pass filter.** Webcam noise within a fixation is larger than the real eye motion, so any linear filter either jitters or lags. The saccade-aware "hold and jump" approach (Kumar et al. 2008, which oculOS's `FixationStabilizer` already follows) is the right design. Špakov (2012) found FIR filters with triangular or Gaussian kernels and state-dependent parameters worked best.
- **Event detection at 30 Hz:** a saccade (20–80 ms) covers only 1–3 frames, so velocity is a single frame difference and very noisy. Use an **adaptive** velocity threshold (Nyström & Holmqvist: PT = μ + 6σ, iterated), preferably a robust median+MAD version, combined with a dispersion or duration check.
- **Latency budget:** every stage adds delay: 4 confirmation samples at 30 fps is 133 ms, plus filter lag, plus the spring. Count the budget in milliseconds using timestamps, not samples. Short-horizon constant-velocity extrapolation can hide about one frame of hand lag. It does not help gaze.
- **Stabilization beats filtering for selection:** snap to targets (magnetic or sticky zones, Accessibility-API element snapping), use MAGIC-style gaze-coarse / hand-fine cascades, and freeze the cursor during a pinch.

## Key findings

**1€ filter (Casiez, Roussel, Vogel, CHI 2012).**
- Equations: `τ = 1/(2π·fc)`, `α = 1/(1 + τ/Te)`, `x̂ᵢ = α·xᵢ + (1−α)·x̂ᵢ₋₁`.
- The derivative `dx = (xᵢ − x̂ᵢ₋₁)/Te` is itself low-passed at `dcutoff` (default 1 Hz), and then `fc = minCutoff + beta·|dx̂|`.
- Reference defaults: `mincutoff = 1.0`, `beta = 0.0`, `dcutoff = 1.0`. The sampling rate is updated from timestamps when they are available (checked against Casiez's reference Python).
- The idea behind it: people notice jitter at low speed and lag at high speed.
- The paper compared 1€ with moving average, single exponential, DESP and Kalman filters. For the same jitter reduction, 1€ had less lag, and Kalman was harder to tune **[per the paper's own summary]**.
- `beta` depends on units: it is measured in Hz per (unit/s). Retune it whenever you change coordinates (normalized, pt, or degrees).

**Kalman, alpha-beta.**
- A constant-velocity Kalman filter (state = position and velocity; acceleration treated as white noise) is the optimal *linear* estimator. Gaze, however, is piecewise constant with jumps, which breaks the Gaussian motion model.
- Komogortsev's I-KF uses this Kalman model for *classification*: a saccade is flagged when the measured velocity departs from the predicted velocity (a χ² test).
- An alpha-beta filter is a Kalman filter with fixed steady-state gains. It is cheap and useful for hand prediction.

**Saccade-aware smoothing (Kumar, Klingner, Puranik, Winograd, Paepcke, ETRA 2008).**
- Keeps a "current fixation" window and a "potential fixation" window, returning a weighted mean in which newer samples weigh more.
- An outlier is held for one sample of look-ahead. If the next sample returns to the current fixation, the outlier is discarded. If it agrees with the outlier, the potential fixation becomes current.
- The paper also presents a trick for eye-hand latency (compensating for the fact that the eye has moved on by the time the hand clicks) and "focus points" (visual anchors that help users fixate precisely).

**Event-detection families.**
- I-VT (velocity threshold), I-DT (dispersion threshold plus minimum duration), I-HMM (2-state HMM on velocity), I-KF, and I-MST (Salvucci & Goldberg 2000; Komogortsev 2010).
- Komogortsev proposed "behavior scores" to pick thresholds automatically from a step stimulus.
- NSLR-HMM (Pekkanen & Lappi 2017, *Sci. Rep.*) fits a piecewise-linear function that denoises and segments the signal in one step, then classifies each segment as fixation, saccade, pursuit or PSO with an HMM. Its few parameters are estimated from the data, it is meant for high-noise field data, and it is open source (Python/C++). This is the best fit for **offline** analysis of recordings.
- Andersson et al. 2017 ("One algorithm to rule them all?") compared 10 detectors against human coders. Most agreed poorly, especially on PSOs and smooth pursuit **[details unverified]**.

**Adaptive threshold (Nyström & Holmqvist 2010).**
- Start with PT in the range 100–300°/s.
- Iterate on the samples below PT: compute μ and σ, set PT = μ + 6σ, and repeat until the change is below 1°/s.
- Saccade onset threshold = μ + 3σ **[unverified]**.
- A robust variant replaces mean/SD with median/MAD ("MAD saccade", Voloh et al. 2020).
- The adaptive-NH detector has also been revised specifically for noisy data (ETRA 2018).

**Stabilization and interaction.**
- **MAGIC pointing (Zhai 1999):** gaze warps the cursor to the target region and the hand does the fine positioning.
- **Gaze + pinch (Pfeuffer 2017):** the eyes select the target and a pinch confirms it.
- **Correcting gaze misses:** "sticky" and "magnetic" target fields fix near-misses (arXiv 2603.26608). A bubble cursor instead resizes the cursor's activation area dynamically so the nearest target is always selected.

## How to program it

### One Euro filter (Swift, timestamp-driven, 2D with a shared speed)

```swift
import CoreGraphics
import Foundation

struct LowPass {
    private(set) var value: Double?
    mutating func apply(_ x: Double, alpha: Double) -> Double {
        let y = value.map { alpha * x + (1 - alpha) * $0 } ?? x
        value = y
        return y
    }
    mutating func reset() { value = nil }
}

@inline(__always)
func smoothingFactor(cutoff: Double, dt: Double) -> Double {
    let tau = 1.0 / (2.0 * .pi * cutoff)
    return 1.0 / (1.0 + tau / dt)
}

/// 1€ filter (Casiez et al. 2012). `beta` has units Hz per (unit/s).
struct OneEuroFilter2D {
    var minCutoff: Double   // Hz, > 0
    var beta: Double        // >= 0
    var dCutoff: Double = 1.0
    private var x = LowPass(), y = LowPass()
    private var dx = LowPass(), dy = LowPass()
    private var lastTime: TimeInterval?

    init(minCutoff: Double, beta: Double, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff; self.beta = beta; self.dCutoff = dCutoff
    }

    mutating func filter(_ p: CGPoint, at t: TimeInterval) -> CGPoint {
        guard let last = lastTime, let px = x.value, let py = y.value else {
            lastTime = t
            return CGPoint(x: x.apply(p.x, alpha: 1), y: y.apply(p.y, alpha: 1))
        }
        // Guard against duplicate or out-of-order timestamps and huge gaps.
        let dt = min(max(t - last, 1e-4), 0.25)
        lastTime = t
        let aD = smoothingFactor(cutoff: dCutoff, dt: dt)
        let vx = dx.apply((Double(p.x) - px) / dt, alpha: aD)
        let vy = dy.apply((Double(p.y) - py) / dt, alpha: aD)
        // One cutoff for both axes, so diagonal motion lags evenly.
        let speed = (vx * vx + vy * vy).squareRoot()
        let a = smoothingFactor(cutoff: minCutoff + beta * speed, dt: dt)
        return CGPoint(x: x.apply(Double(p.x), alpha: a),
                       y: y.apply(Double(p.y), alpha: a))
    }

    mutating func reset() {
        x.reset(); y.reset(); dx.reset(); dy.reset(); lastTime = nil
    }
}
```

**Note on the 2D variant.** The reference filters each axis independently. The shared-speed version above is a common variant, not the paper's exact method. The first sample uses α = 1, which gives the same derivative-0 behavior as the reference.

### Online I-VT with a robust adaptive threshold

```
state: prev (pos in deg, t), noise = RingBuffer(capacity ~ 3 s of fixation velocities)
       T = 150 deg/s initial; inSaccade = false; lastSaccadeEnd = -inf
on sample (p, t):
  v = |p - prev.p| / (t - prev.t)            // deg/s; skip if a blink or gap > 100 ms
  if !inSaccade and v < T: noise.push(v)
  if noise.count >= 30:                       // re-estimate about every 10 samples
      med = median(noise); mad = 1.4826 * median(|noise - med|)
      T = clamp(med + k*mad, 60, 400)         // k = 6 (NH-style); lower for 30 Hz, see below
  if v > T: inSaccade = true
  else if inSaccade and v < 0.5*T:            // hysteresis
      inSaccade = false; lastSaccadeEnd = t
  // accept a fixation only if it lasts >= 100 ms (3 frames at 30 fps)
  // and its dispersion is <= R (I-DT check)
```

Because 30 Hz under-samples saccades, the peak velocity is underestimated. Also require the **amplitude** (displacement over 2 frames) to exceed about 2× the precision SD, so that large, slow-looking jumps are still caught.

### Starting parameters

| Signal | minCutoff | beta | dCutoff | Other |
|---|---|---|---|---|
| Hand pointer, screen points @30 fps | 1.0 Hz | 0.005–0.02 per (pt/s) **[tune]** | 1.0 | Filter a stable landmark (index MCP or palm centroid), not the fingertip |
| Hand, normalized 0–1 coordinates | 1.0 Hz | about 5–20 **[tune]** | 1.0 | beta scales by 1/screen size |
| Gaze, within a fixation (optional) | 0.3–0.5 Hz | about 0 | 1.0 | Reset on each confirmed saccade |
| Gaze stabilizer radius | – | – | – | 2–2.5 × the validation precision (RMS-S2S or SD), in pt |
| I-VT threshold floor / ceiling | – | – | – | 60 / 400 °/s, k = 5–6 |

## Recommendations for oculOS

**VisionGaze**
1. **Keep `FixationStabilizer`.** It is a multi-sample generalization of Kumar's look-ahead. Changes worth making:
   - Tie `radius` to the precision measured at calibration validation (per user and per session) instead of a constant.
   - Make the confirmation count depend on the jump: 2 samples when the candidate is more than 3·radius away (an unambiguous saccade), 4 when it is close. This cuts large-jump latency from 133 ms to 67 ms.
   - Express `maxWindow` and the confirmation rule in milliseconds using frame timestamps, so dropped frames don't change behavior.
2. Within a fixation, a 1€ filter with a low cutoff (reset at each saccade) could replace the running mean. It follows slow drift more smoothly than a capped cumulative mean **[worth A/B testing]**.
3. Critically damped spring: pick ω so the 95% settle time is at most 100 ms, or skip it for saccade jumps and use it only for within-fixation drift.
4. Snap the cursor to UI elements from the Accessibility API (a magnetic field around targets) when dwell- or pinch-selecting. At 2–4° accuracy this matters more than any filter.
5. Offline recordings: add NH-adaptive or NSLR-HMM classification alongside I-DT, and report its thresholds.
6. `PursuitFilter`: during detected smooth pursuit, switch the stabilizer to a 1€ or alpha-beta filter. Holding still during pursuit gives stair-step output.

**Hand app**
1. Run a 1€ filter on the filtered pointing landmark. Map the result through a pointer-acceleration (CD-gain) transfer function, with a small dead zone (about 0.5–1 pt of filtered motion) to kill residual creep.
2. **Pinch click without moving the target:** the pinch itself moves the fingertip. When a pinch starts, lock the cursor at its position from about 100 ms earlier; keep a ring buffer of cursor history for this.
3. Pinch detection: use hysteresis thresholds (for example, close below 0.25 and open above 0.35 × hand size) plus 2-frame debouncing.
4. Latency: add alpha-beta prediction of 1 frame (≤ 33 ms) only at high speed, and clamp the extrapolation distance.
5. Consider a MAGIC-style mode that combines both apps: gaze warps the cursor, and the hand refines and pinches.

## Pitfalls

- Using sample counts instead of timestamps: AVCapture frame rates vary with low light and with auto-exposure.
- Leaving 1€ `beta` unchanged after changing units. Filtering the fingertip, which moves during a pinch.
- Computing velocity in pixels while thresholds are in °/s. Convert using the estimated viewing distance.
- Letting blinks and tracking dropouts feed velocity spikes. Gate them out and reset the filters after gaps longer than about 150 ms.
- Stacking filters (stabilizer, then 1€, then spring), which adds up their lags.
- Trusting PSO or pursuit labels at 30 Hz. Most detectors disagree with human coders even at 500 Hz or more.

## Sources

- https://pypi.org/project/OneEuroFilter/ and https://raw.githubusercontent.com/casiez/OneEuroFilter/main/python/OneEuroFilter/OneEuroFilter.py
- https://dl.acm.org/doi/abs/10.1145/2207676.2208639 (1€ CHI 2012); https://gery.casiez.net/1euro/ (tuning procedure, via search snippet)
- https://dl.acm.org/doi/10.1145/2168556.2168616 (Špakov 2012)
- https://dl.acm.org/doi/10.1145/1344471.1344488; https://hci.stanford.edu/cstr/reports/2007-03.pdf (Kumar et al., via search snippet)
- https://www.researchgate.net/publication/41452096 (Nyström & Holmqvist 2010); https://dl.acm.org/doi/10.1145/3205929.3205938 (NH for noisy data)
- https://www.researchgate.net/publication/349682425 (MAD saccade)
- https://www.nature.com/articles/s41598-017-17983-x (NSLR-HMM)
- https://userweb.cs.txstate.edu/~ok11/eye_movement_classification.html; https://dl.acm.org/doi/10.1145/1743666.1743682 (Komogortsev, I-KF, behavior scores)
- https://link.springer.com/article/10.3758/s13428-016-0738-9 (Andersson et al. 2017, not opened)
- https://arxiv.org/html/2603.26608 (sticky and magnetic gaze-and-pinch); https://dl.acm.org/doi/10.1145/3131277.3132180 (Gaze + pinch)
