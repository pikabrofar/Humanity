# 17 — Dwell selection and accessibility/AAC use of gaze

## TL;DR

- Dwell time must be **user-adjustable**. Novices start near 900–1000 ms. In Majaranta et al. (CHI '09), users who could adjust it went from 876 ms to 282 ms over ten sessions, and their typing speed rose from 6.9 to 19.9 wpm. A fixed 1 s default leaves people stuck at the novice level.
- **Show progress while the user dwells** (a filling or shrinking ring, plus an optional click sound when it fires). Feedback affects speed, errors, and comfort. Short dwell times need an audible or visual "fired" cue more than long ones do.
- At VisionGaze's 2–4° accuracy, targets must be **large** (at least about 2× the error radius, so roughly 150–250 px at 60 cm). Anything smaller needs a **two-step zoom**, as in Grid 3, or snapping to targets.
- Copy the AAC conventions: a **pause/rest area**, a dwell cool-down after each selection, movement tolerance, and hot corners, as in macOS Dwell Control. Always give an easy way to stop tracking.
- For text, a large-key keyboard with **word prediction** is the baseline. Dasher, which needs no dwell, reaches about 25 wpm after an hour of practice (34 wpm for experts) and suits low-precision trackers.

## Key findings

**Dwell-time choice.** Majaranta, Ahola and Špakov (CHI '09) ran a longitudinal study with adjustable dwell. Mean dwell fell from 876 to 282 ms, speed rose from 6.9 to 19.9 wpm, and errors fell from 1.28% to 0.36%. Majaranta and MacKenzie (UAIS 2006) found feedback type interacts with dwell length. A click sound helped at short dwell, and visual cues mattered more at long dwell *(details from memory, unverified)*. Research on adaptive dwell includes:
- Cascading dwell (Mott et al., CHI '17): per-key dwell shrinks for letters the language model rates likely *(reported gain about 10–15%, unverified)*.
- Variable dwell for two-step web selection (arXiv 1704.06399).
- Multi-threshold dwell (CHI '25).

**macOS Dwell Control** (Accessibility Keyboard):
- Separate default and panel dwell times, with a default of about 3 s *(per AbilityNet)*.
- Movement tolerance, default 20 px.
- Hot corners: toggle dwell pause, left or right click, drag, scroll menu, options.
- A dwell action menu for choosing the next click type.

This is the model macOS users already know. The oculOS pointer could drive it, but a native implementation gives gaze-aware tolerance (in degrees, not px).

**Tobii Dynavox / Grid 3.** Grid 3 offers blink, dwell, or switch activation. Its "Gaze Selection" mode is two-step: dwell, a region zooms in, then you dwell again. Precision sets how wide the zoom starts, and Speed sets how fast it zooms. Zero on both is roughly a direct click, meant for users with very good calibration. AAC grids use big cells, reserve a rest cell or area, and allow a switch as an alternative way to activate.

**User needs (ALS/MND, cerebral palsy).**
- ALS: users may develop drooping eyelids, dry eyes, and a reduced range of eye movement over time. Needs change as the disease progresses, so settings must be easy for a carer to re-tune.
- Cerebral palsy: involuntary head and eye movement *(general AAC knowledge)* means bigger tolerance and larger targets.
- Fatigue and the Midas-touch problem (things firing just because the user looked at them) are the main complaints. Long dwell is safe but tiring. Blink activation misfires when eyes are dry or tired.

## How to program it (Swift)

```swift
enum DwellState { case idle, pending(target: AnyHashable, start: TimeInterval),
                  fired(target: AnyHashable, at: TimeInterval), paused }

final class DwellController {
    var dwell: TimeInterval = 0.9            // user-adjustable 0.25–3 s
    var toleranceDeg: Double = 1.5           // leave-grace, in degrees
    var graceTime: TimeInterval = 0.15       // brief exits don't reset
    var cooldown: TimeInterval = 0.6         // no re-fire on same target
    private(set) var state: DwellState = .idle
    private var lastInside: TimeInterval = 0
    var onProgress: (AnyHashable?, Double) -> Void = { _, _ in }  // 0…1 ring
    var onFire: (AnyHashable) -> Void = { _ in }

    /// Call per gaze sample with the snapped/hit-tested target (nil = none).
    func update(target: AnyHashable?, t: TimeInterval) {
        switch state {
        case .paused: return
        case .idle:
            if let tg = target { state = .pending(target: tg, start: t); lastInside = t }
        case .pending(let tg, let start):
            if target == tg { lastInside = t }
            else if t - lastInside > graceTime {            // really left
                state = target.map { .pending(target: $0, start: t) } ?? .idle
                onProgress(nil, 0); return
            }
            let p = min(1, (t - start) / dwell)
            onProgress(tg, p)
            if p >= 1 { onFire(tg); state = .fired(target: tg, at: t) }
        case .fired(let tg, let at):
            if target != tg || t - at > cooldown * 3 {       // must look away
                if t - at > cooldown { state = .idle }
            }
        }
    }
    func togglePause() { state = (state == .paused) ? .idle : .paused }
}
```

Draw the ring as a `CAShapeLayer` with `strokeEnd = p`, placed at the **target centre** and not at the noisy gaze point. Hit-test on smoothed gaze (see report 05) and snap to Accessibility elements (see report 09). Add hysteresis: a target is "entered" at its bounds but only "left" at bounds plus the tolerance in degrees.

## Recommendations for oculOS

1. Default dwell 1.0 s, adjustable from 0.25 to 3 s, with an optional **auto-adapt** mode that slowly shortens dwell when the user rarely cancels or undoes, and lengthens it after undos (clamped, with notice to the user).
2. Show a ring at the target centre and play a subtle click when it fires. After firing, require the user to look away before the same target can fire again.
3. Treat targets smaller than about 3° as "zoom first". Dwell magnifies a 2× to 3× region (as Grid 3 does), then a second dwell selects.
4. Add a gaze-reachable **pause** (hot corner or off-screen glance), a click-type menu (left, right, double, drag, scroll) like macOS Dwell Control, and an optional switch/keyboard/hand pinch to commit (see report 09).
5. Text: point users to the macOS Accessibility Keyboard with large keys and prediction, and consider a Dasher-style mode later.
6. Carer-friendly settings: presets such as "ALS early", "ALS late / low accuracy", and "CP / high tremor", plus prompts to recalibrate.

## Pitfalls

- The Midas touch problem: dwell everywhere, including on text you are only reading, fires by accident. Scope dwell to actionable elements.
- Dwell times set too short for novices, and ring feedback drawn at the jittery gaze point, which is distracting.
- Blink-to-click with dry or tired eyes. Long sessions without breaks cause fatigue.
- Tolerance measured in pixels breaks on Retina and multi-monitor setups. Use degrees.
- No reliable way to stop: the user must always be able to pause or exit by gaze alone.

## Sources

- https://homepages.tuni.fi/oleg.spakov/publications/Majaranta_CHI_09.pdf
- https://www.yorku.ca/mack/uais2006.html
- https://cs.stanford.edu/~merrie/papers/cascading_dwell.pdf
- https://arxiv.org/pdf/1704.06399
- https://dl.acm.org/doi/full/10.1145/3706598.3713781
- https://mcmw.abilitynet.org.uk/how-to-use-dwell-with-the-on-screen-accessibility-keyboard-in-macos-12-monterey
- https://mcmw.abilitynet.org.uk/how-to-use-hot-corners-with-the-on-screen-accessibility-keyboard-in-macos-13-ventura
- https://hub.thinksmartbox.com/knowledgebase/eye-gaze-settings-in-grid-3/
- https://www.tobiidynavox.com/blogs/support-articles/what-do-the-options-listed-in-gaze-selection-settings-mean
- https://eyegaze.com/users/als/
- https://arxiv.org/pdf/2204.08156
- https://www.nature.com/articles/418838a
- https://wiki.cogain.org/index.php/Eye_Typing_Systems
