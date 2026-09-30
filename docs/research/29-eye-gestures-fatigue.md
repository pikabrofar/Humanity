# 29. Eye gestures and eye-state analytics

## TL;DR

- Use **duration** to tell deliberate blinks from spontaneous ones. Spontaneous blinks last about 100–400 ms. Voluntary blinks average about 570 ms in one high-speed-camera study. A **long blink of 600 ms or more** is a safe command threshold. Anything under 400 ms is spontaneous and should only freeze the cursor.
- **Winks** (one eye closed, the other open) are more distinctive than long blinks, but many people can't wink cleanly, and the open eye often narrows too. Always make winks optional, calibrate them per eye, and offer long blinks as the fallback.
- **Gaze gestures** (Drewes & Schmidt 2007) use relative stroke directions, so calibration offset matters much less, which suits webcam gaze at 1.5–4°. Off-screen glances (Isokoski 2000) work as a few coarse commands that don't trigger by accident.
- **Fatigue**: PERCLOS (P80) is the share of time the eye is at least 80% closed, over a window of about 1 minute. Common bands: under 7.5% awake, 7.5–15% questionable, over 15% drowsy. Blink rate drops from about 15–20/min to about 4–7/min during screen work.
- Offer **20-20-20 break reminders**. The idea is sound (breaks help), but the exact numbers aren't validated.

## Key findings

- **Blink timing.** A spontaneous blink lasts about 100–400 ms. The eyelid pause at closure is about 14 ms for spontaneous blinks and about 44 ms for voluntary ones. Mean voluntary blink duration is 572 ± 25 ms (PMC4043155). At 30 fps one frame is 33 ms, so a spontaneous blink covers only 3–12 frames, and the fastest may show only 1–2 partly closed frames. Duration can therefore only be measured to about ±33 ms. Many assistive systems threshold on duration alone (ScienceDirect 2021 webcam paper).
- **Openness from 2D landmarks.** Compute a per-eye EAR-like ratio from Vision's `leftEye`/`rightEye` regions (report 03 covers EAR itself). Normalize it per user: `openness = (ear - earClosed) / (earOpen - earClosed)`, clamped to 0…1. Take `earOpen` from a rolling 90th percentile and `earClosed` from a "close your eyes" calibration step. PERCLOS P80 then means `openness < 0.2`.
- **Gaze gestures.** Drewes & Schmidt used 8 stroke directions, with each gesture made of 4–6 strokes. Gestures take no screen space and hold up against calibration shift. They take longer to perform than dwell: roughly 0.5 s per stroke *(unverified, the paper PDF was blocked)*. Accidental matches are rare for gestures of 4 or more strokes *(unverified)*. Users find off-screen targets hard to locate, so keep them to screen edges and corners.
- **Digital eye strain.** Blink rate falls sharply during screen work, and there are more **incomplete blinks**. Wolffsohn et al. (2022) found that 20-20-20 breaks reduced symptoms over 2 weeks. The same study questions whether "20" is special.

## How to program it

```swift
struct EyeSample { let t: TimeInterval; let left: Double; let right: Double } // normalized openness 0…1

enum EyeEvent { case spontaneousBlink, longBlink, winkLeft, winkRight, closedHold }

final class BlinkClassifier {
    var closeT = 0.25, openT = 0.45          // hysteresis on openness
    var longBlinkMin = 0.60, maxBlink = 0.40 // seconds
    var winkMargin = 0.35                     // open-eye minus closed-eye openness
    private var closedSince: TimeInterval?
    private var winkSide: Int = 0             // -1 left, +1 right, 0 both
    private var winkVotes = [Int]()

    func update(_ s: EyeSample) -> EyeEvent? {
        let both = min(s.left, s.right), diff = s.right - s.left
        if closedSince == nil {
            if both < closeT || abs(diff) > winkMargin && min(s.left, s.right) < closeT {
                closedSince = s.t; winkVotes.removeAll()
            }
            return nil
        }
        // accumulate per-frame side votes while closed
        winkVotes.append(abs(diff) > winkMargin ? (diff > 0 ? -1 : 1) : 0)
        let reopened = max(s.left, s.right) > openT && both > closeT
        guard reopened, let start = closedSince else { return nil }
        closedSince = nil
        let dur = s.t - start
        let side = majority(winkVotes)        // require >70% agreement
        if side != 0 && dur >= 0.25 && dur <= 1.5 { return side < 0 ? .winkLeft : .winkRight }
        if dur < maxBlink { return .spontaneousBlink }
        if dur >= longBlinkMin && dur < 2.0 { return .longBlink }
        return dur >= 2.0 ? .closedHold : nil // 0.4–0.6 s: ambiguous, ignore
    }
    private func majority(_ v: [Int]) -> Int {
        guard !v.isEmpty else { return 0 }
        for side in [-1, 1] where Double(v.filter { $0 == side }.count) / Double(v.count) > 0.7 { return side }
        return 0
    }
}

// PERCLOS over a sliding 60 s window
struct Perclos {
    private var buf: [(TimeInterval, Bool)] = []
    mutating func add(t: TimeInterval, openness: Double) -> Double {
        buf.append((t, openness < 0.2)); buf.removeAll { t - $0.0 > 60 }
        return Double(buf.filter { $0.1 }.count) / Double(max(buf.count, 1))
    }
}
```

Because of mirroring, "left" must be decided in one place, as either the user's eye or the image-side eye. Emit `closedHold` so VisionGaze keeps freezing the cursor while the eyes are shut.

## Recommendations for oculOS

1. Keep the current rule that any closure freezes the cursor. Also rewind the cursor to its position about 100 ms before the closure started (see report 05).
2. Commands: long blink = click (opt-in). Left wink = right-click and right wink = click, each only after the calibration checks the user can wink. Add a **cooldown of about 500 ms** and play a sound on every event.
3. Add a small gaze-gesture set, such as a corner glance or a 4-stroke "unlock/pause", as the clutch for turning tracking on and off.
4. Show an optional wellness panel with blink rate/min, PERCLOS, and time since the last break, plus 20-20-20 nudges and a nudge to blink when the rate stays under about 8/min for 5 min. Process everything on-device. Don't market it as drowsiness *safety* detection.

## Pitfalls

- Glasses glare, downward gaze (reading or the keyboard), and head pitch all lower EAR and look like closure. Gate eye events on head pose and landmark confidence.
- Squinting, smiling, and speaking narrow the eyes. The wink margin has to beat these, so calibrate it per user.
- Dropped frames stretch durations. Use timestamps, not frame counts.
- PERCLOS thresholds come from driving studies with IR cameras. Webcam values at a desk are not validated *(uncertain)*.
- Voluntary blinks get shorter with practice. Let users tune `longBlinkMin`.

## Sources

- https://pmc.ncbi.nlm.nih.gov/articles/PMC4043155/ (voluntary blink kinematics)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6427357 (blink 100–400 ms)
- https://www.sciencedirect.com/science/article/pii/S0957417421014111 (webcam voluntary blink detection)
- https://dl.acm.org/doi/10.1145/3749012.3749079 (voluntary vs involuntary via openness)
- https://link.springer.com/chapter/10.1007/978-3-540-74800-7_43 (Drewes & Schmidt 2007)
- https://faculty.washington.edu/wobbrock/pubs/cogain-07.pdf (Isokoski off-screen targets context)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC9323611/ (PERCLOS P80 and thresholds)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/ (digital eye strain review)
- https://www.sciencedirect.com/science/article/pii/S1367048422001990 (testing 20-20-20)
