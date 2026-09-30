# 18: Reading detection and gaze-driven scrolling

## TL;DR

- Only scroll while the user is actually reading. A Campbell & Maglio style evidence accumulator (points for rightward saccades and return sweeps, a threshold to enter "reading" mode) filters out glances and prevents most unintended scrolling.
- With webcam gaze at 2–4°, individual reading saccades (about 2°) are barely detectable, but **return sweeps** (large leftward jumps plus a small drop, often 10–20°) are robust. Build the detector around sweeps, not fixations.
- Kumar & Winograd (UIST 2007) found that gaze-enhanced Page Up/Down was universally preferred, and that continuous scrolling should aim to keep the eyes in the middle third of the window, with speed matched to measured reading speed.
- On macOS, inject pixel-unit `CGEvent` scroll wheel events at display rate (60 Hz) with a velocity ramp. Don't set phase fields (see report 08).

## Key findings

- **Campbell & Maglio 2001, "A robust algorithm for reading detection" (PUI).** A rule-based detector. Each saccade is classified per axis by size and direction (read forward, skim forward, regression, reset/return sweep, skim jump). Each class carries points: for example "read forward" (X) is +10 and "skim jump" (Y) is −5. Points go into a pooled evidence counter, and reading mode starts once the counter passes **30**. The system starts in scanning mode and drops back to it on non-reading events. The other point values and pixel/character cutoffs in the sketch below are *(unverified)* reconstructions. Tune them on our own data.
- **Later work.** Biedert et al. (ETRA 2012) built a realtime reading-versus-skimming classifier, and Buscher's eyeBook work used reading detection for implicit feedback. Both take the same approach: features from saccade length and direction, plus a smoothing state.
- **Kumar & Winograd, "Gaze-enhanced Scrolling Techniques" (UIST 2007):**
  - *Gaze-enhanced Page Up/Down.* The line the user was looking at moves to the top of the viewport. All participants preferred it over normal paging.
  - *Smooth scrolling with gaze repositioning.* When gaze falls below a start threshold, the view starts scrolling slowly, a little faster than the user reads, so the gaze drifts back upward. Scrolling stops above a stop threshold.
  - *Eye-in-the-middle.* Reading speed is estimated as vertical pixels advanced divided by the time per horizontal sweep, then smoothed to handle images and column width changes. Scroll rate adapts to keep gaze in the middle third.
  - *Discrete scrolling.* The view pages once the user reads to the bottom.
  - *(Unverified, from memory.)* The paper also describes off-screen "look past the edge" scroll zones, and it uses reading detection so a glance at the bottom doesn't trigger scrolling.
- **Follow-up studies** (Räihä and colleagues 2014; Turner et al., PETMEI 2015, Microsoft Research) found that readers differ a lot: some prefer to read at the top of the screen, others at the bottom. Fixed thresholds annoy some users. Haptic or other feedback at scroll onset helped *(unverified detail)*.
- **macOS injection.** Use `CGEvent(scrollWheelEvent2Source:units:.pixel,...)`. Pixel-unit events set `scrollWheelEventIsContinuous = 1`, so apps read `PointDeltaAxis1`. Many small events at 60 Hz look smooth. Line-unit events look jerky.

## How to program it

```swift
enum Mode { case scanning, reading }

final class ReadingDetector {
    // Inputs: fixation-to-fixation saccades from the I-VT/hold-and-jump layer (report 05), in degrees.
    private(set) var mode: Mode = .scanning
    private var evidence = 0.0
    let enter = 30.0, exit = 0.0, cap = 60.0

    func onSaccade(dx: Double, dy: Double, lineHeightDeg: Double) {
        var pts = 0.0
        // X axis (thresholds are illustrative; ~1 char ≈ 0.25–0.3° at 60 cm)
        if dx > 0.5 && dx < 4 { pts += 10 }           // read forward
        else if dx >= 4 && dx < 8 { pts += 5 }        // skim forward
        else if dx < -8 && dy > 0 && dy < 3*lineHeightDeg { pts += 15 } // return sweep: key webcam cue
        else if dx < 0 && dx > -3 { pts -= 5 }        // regression (weak evidence)
        else { pts -= 10 }                            // long/odd jump
        if abs(dy) > 3*lineHeightDeg { pts -= 5 }     // Y skim jump
        evidence = min(cap, max(-cap, evidence + pts))
        if mode == .scanning && evidence >= enter { mode = .reading }
        if mode == .reading  && evidence <= exit  { mode = .scanning; evidence = 0 }
    }
    func onLongFixationOffText() { evidence -= 20 }  // e.g. gaze left window
}

final class ScrollController {
    var velocity = 0.0                   // px/s, positive = content moves up
    var readRatePxPerS = 40.0            // EMA of (Δy between sweeps)/(sweep period)
    func tick(dt: Double, gazeYNorm: Double, reading: Bool) {  // gazeYNorm: 0 = top, 1 = bottom of window
        var target = 0.0
        if reading && gazeYNorm > 0.66 {           // lower third: go
            let k = (gazeYNorm - 0.66) / 0.34      // 0…1
            target = readRatePxPerS * (1.1 + 1.5*k)
        } else if gazeYNorm < 0.5 || !reading {    // hysteresis: stop above middle
            target = 0
        } else { target = velocity }               // middle band: hold
        let a = target > velocity ? 2.0 : 6.0      // ramp up slowly, stop fast
        velocity += (target - velocity) * min(1, a*dt)
        let px = Int32((velocity*dt).rounded())
        if px != 0 { postScroll(px) }
    }
    func postScroll(_ px: Int32) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                wheel1: -px, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    }
}
```

Drive `tick` from a `CVDisplayLink` or a 60 Hz timer rather than the 30 fps camera loop, and carry sub-pixel remainders over to the next tick. Target the window under the gaze. Scroll events go to the window under the cursor, so either warp the cursor into the window first or skip scrolling when the cursor is somewhere else.

## Recommendations for oculOS

1. Ship **gaze Page Down** (dwell in the bottom band plus reading mode, or a hand-gesture confirm) before continuous auto-scroll. It's simpler and the best-liked technique.
2. Make continuous auto-scroll opt-in, per app (browsers, Preview, Books), with a menu-bar pause toggle and a visible edge glow when scrolling is armed.
3. Learn per-user thresholds and reading speed from the sweep period. Let the start band be adjustable (some users read low on the screen).
4. Stop scrolling right away on blinks longer than 300 ms, when face tracking is lost, when gaze leaves the window, or on any manual scroll or keypress.
5. Don't use gaze to scroll up. Use gaze-to-top dwell with a gesture, or a hand gesture (report 07).

## Pitfalls

- **Vertical drift and offset errors** (2–4°) are bigger than a line height. Use normalized window position with wide bands, not line-level targets, and recalibrate the Y offset from return-sweep landing points.
- **Midas touch.** Looking at an image or at the Dock near the bottom must not scroll. Require reading mode.
- **Feedback loop.** Scrolling moves the text under a fixating eye and causes smooth pursuit, which I-VT may misclassify. Subtract the known scroll offset from gaze before detecting saccades.
- 30 fps undersamples 20–40 ms saccades. Use fixation displacements, not velocities.
- Code, tables, and right-to-left scripts break the left-to-right assumption. Mirror dx for RTL locales.

## Sources

- https://www.researchgate.net/publication/2846409_A_Robust_Algorithm_for_Reading_Detection (via search summary)
- https://arxiv.org/pdf/2501.18468 (describes the Campbell & Maglio point scheme and threshold of 30)
- https://dl.acm.org/doi/10.1145/2168556.2168575 (Biedert et al., reading-skimming classifier)
- https://hci.stanford.edu/publications/2007/168-kumar.pdf (blocked; content from search summaries)
- https://dl.acm.org/doi/10.1145/2639189.2639242 (Räihä, gaze-contingent scrolling)
- https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/PETMEI2015scrolling_petmei_15_final.pdf
- https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventiscontinuous
- https://gist.github.com/svoisen/5215826 (low-level macOS scroll events)
