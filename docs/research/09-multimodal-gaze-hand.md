# 09 — Multimodal gaze + hand interaction

Scope: how to combine VisionGaze (webcam gaze, ~2–4° ≈ 80–150 pt error) with the planned hand-gesture app (point, pinch-click, scroll). Covers HCI research and shipped products.

## TL;DR

- **Gaze targets, the hand commits.** Every successful design (MAGIC pointing, Gaze + Pinch, Vision Pro, Tobii "warp", EyePoint) uses gaze for the coarse jump and a manual action to confirm or refine. Gaze alone with dwell is the fallback for users who can't use their hands. It is not the default.
- **At 2–4° oculOS cannot select a target from raw gaze.** It must snap to UI elements (Accessibility tree), use sticky/magnetic targets, or hand off to the hand for the last ~150 pt. Vision Pro needs ≥60 pt targets even with its IR tracker, so webcam gaze needs more.
- **The main failure is timing, not position.** In gaze + pinch, *late-trigger* errors (the eyes have already left for the next target when the pinch lands) account for ~87% of eye-hand coordination errors, with a ~100 ms mean offset. Fix: select using the gaze from ~100–150 ms *before* the pinch, or use a gaze-lock.
- **Don't show a raw gaze cursor while in control mode.** A visible jittery cursor pulls the eye (a feedback loop) and adds to Midas-touch problems. Highlight the snapped target instead (Vision Pro's hover effect), and show a pointer only once the hand takes over.
- **Gaze is sensitive data.** Apple renders hover effects outside the app's process and never shares gaze with apps. oculOS should keep gaze in-process, never log it by default, and expose only "selected element" events.

## Key findings

**MAGIC pointing (Zhai, Morimoto, Ihde, CHI 1999).** Gaze "warps" the cursor near the target, then a small manual movement does the final positioning and selection. There were two variants. *Liberal* warps the cursor to every new fixation. *Conservative* warps only when the manual device starts moving, so the cursor doesn't jump around distractingly. The claimed benefits over manual pointing are less effort and fatigue and possibly more speed. Over gaze-only pointing, the gain is accuracy and naturalness. This is the direct template for "gaze warp + hand refine." Tobii's shipped "Warp on Mouse Move" and "Warp on key" are the same idea as the conservative and hotkey variants.

**EyePoint (Kumar, Paepcke, Winograd, CHI 2007).** Look, press a hotkey, look again, release. On key press the region around the gaze point is magnified, and the second look inside the magnified view selects precisely. This progressive refinement was designed explicitly to work around tracker inaccuracy. The same GUIDe project did gaze-enhanced scrolling (UIST 2007): automatic scrolling when the reader's gaze nears the bottom of the view, paced by an estimated reading speed. *Exact thresholds not verified; the PDF could not be fetched.*

**Gaze + Pinch (Pfeuffer, Mayer, Mardanbegi, Gellersen, SUI 2017)** applies the "look-that-there" principle with free-hand gestures: you look at any object, near or far, and a pinch applies a direct-manipulation-style gesture to it. The follow-up paper (Pfeuffer, Gellersen, Gonzalez-Franco, *IEEE CG&A* 44(3), 2024) gives five principles. The ones that matter for oculOS: **division of labor** (eyes select, hands manipulate), **minimal timing** (the pinch commits at once, with no dwell), indirect manipulation, and gaze-based drag & drop. It also names early- and late-trigger errors. GazeHandSync (ETRA 2025) measured late triggers at 86.57% of coordination errors, with a mean offset of 100.75 ms. Other follow-ups: "Sticky and Magnetic" (2026) on error correction, and PinchCatcher (2025) on multi-selection.

**Gaze-lock cursor (Ergonomics, 2020).** Once gaze has stayed on a target past a time threshold, the cursor locks to that target, which makes it immune to jitter and early look-away. Compared with a free gaze cursor, this made selection faster and cut errors significantly. A related eye-hand study found that a sensing radius of **~1.8–2.2× the target diameter** balances accuracy and comfort.

**Midas touch and dwell (Jacob 1990).** The eyes scan all the time, so looking can't mean clicking. Dwell thresholds in the literature range from **~200 ms to 1000 ms**. Short dwell suits experts and small command sets, long dwell suits novices. Apple's iOS 18 Eye Tracking, Windows Eye Control and Tobii Dynavox all use dwell and let the user set the time. Explicit confirmation (a key, pinch, blink or facial gesture) is faster and less error-prone whenever the user can do it.

**Apple Vision Pro / visionOS.** The eyes are the primary targeting mechanism and the pinch confirms. Interactive elements need **≥60 pt** of hit area (a 44 pt button plus padding). The hover highlight is drawn by the system outside the app's process, so apps see only the final tap, never the gaze.

**Accessibility baselines.**
- **iOS/iPadOS 18 Eye Tracking** uses the front camera and on-device ML, calibrates in under a minute, and combines Dwell Control with AssistiveTouch.
- **macOS Head Pointer** (since Catalina) moves the pointer with head motion from the webcam. Pointer Control maps facial expressions (raised eyebrows, open mouth, pucker, tongue) to clicks and drags, with an adjustable expressiveness threshold.
- **Google Project Gameface** (open source, MediaPipe) moves the cursor with the head and uses 52 face blendshapes as gestures.

Head pointing is steadier than webcam gaze but costs more effort. It is the natural "fine" channel for users who can't use their hands. *Whether macOS itself ships eye tracking (not just Head Pointer) is uncertain; not verified.*

## How to program it

### Architecture

```
VisionGaze (GazeKit)            Hand app (Vision VNDetectHumanHandPoseRequest)
  gaze point + confidence  ──┐   ┌── fingertip ray / relative motion, pinch state, scroll delta
  FixationDetector (I-DT)    │   │
                             ▼   ▼
               InteractionCoordinator (single process, one camera session)
                 ├─ GazeHistory ring buffer (≥300 ms, timestamped)
                 ├─ TargetResolver: AX tree hit-test around gaze (AXUIElementCopyElementAtPosition
                 │    sampled on a grid within radius r ≈ 1.5× error estimate), score candidates
                 ├─ State machine (below)
                 └─ Output: CGEvent warp/click/scroll + overlay highlight
```

Sharing one `AVCaptureSession` for face and hands avoids fighting over the camera. Both Vision requests can run on the same frame.

### State machine (MAGIC-conservative + Gaze + Pinch)

```
IDLE        ── fixation stable >150 ms ─────────────► GAZE_HOVER (highlight snapped target, no cursor move)
GAZE_HOVER  ── hand appears / starts moving ───────► WARPED (cursor jumps to snapped target centre)
GAZE_HOVER  ── pinch (hand idle) ──────────────────► COMMIT(target = resolve(gaze @ t_pinch − 120 ms))
WARPED      ── hand relative motion ───────────────► REFINE (cursor += gain·Δhand, gaze ignored)
REFINE      ── pinch ──────────────────────────────► click at cursor; → REFINE
REFINE      ── hand still >800 ms AND gaze >2× error radius away ─► GAZE_HOVER (allow a re-warp)
any         ── pinch-hold + hand vertical motion ──► SCROLL (element under snapped target)
any         ── face/hand lost ─────────────────────► IDLE
```

The rule that matters most: **don't re-warp while the hand is refining**. That is exactly the case conservative MAGIC exists to avoid.

### Target snapping (Swift sketch)

```swift
struct Candidate { let element: AXUIElement; let frame: CGRect; let role: String }

func resolveTarget(gaze: CGPoint, errorPt: CGFloat, sys: AXUIElement) -> Candidate? {
    let r = errorPt * 1.5
    var seen = [CGRect: Candidate]()
    for dx in stride(from: -r, through: r, by: r / 3) {
        for dy in stride(from: -r, through: r, by: r / 3) {
            var el: AXUIElement?
            let p = CGPoint(x: gaze.x + dx, y: gaze.y + dy)
            guard AXUIElementCopyElementAtPosition(sys, Float(p.x), Float(p.y), &el) == .success,
                  let e = el, let c = actionable(e) else { continue }   // walk up to AXButton/AXLink/AXTextField…
            seen[c.frame] = c
        }
    }
    // score: gaussian on distance to rect (not centre), + bonus if it's the current hover (hysteresis)
    return seen.values.max { score($0, gaze, errorPt) < score($1, gaze, errorPt) }
}

func onPinch(at t: TimeInterval) {
    let g = gazeHistory.median(in: (t - 0.20)...(t - 0.08))    // late-trigger compensation
    if let c = resolveTarget(gaze: g, errorPt: calib.errorPt, sys: AXUIElementCreateSystemWide()) {
        click(at: CGPoint(x: c.frame.midX, y: c.frame.midY))
    }
}
```

Keep a hover hysteresis: switch the snapped target only when a new candidate scores more than about 1.3× the current one. This works like the gaze-lock.

## Recommendations for oculOS (roadmap)

1. **Hand app v1 stands alone.** Relative "air-trackpad" motion, pinch = click, pinch-drag = scroll. This proves the hand pipeline and gives a precise channel.
2. **Shared `InteractionCoordinator` package** (a sibling to GazeKit) with the gaze ring buffer, one camera session and CGEvent output.
3. **Gaze warp (MAGIC-conservative).** Warp the cursor to the gaze point on hand onset only, then let the hand refine. No AX needed yet. This works even at 150 pt error and is the quickest useful combination.
4. **AX snapping + Gaze + Pinch.** Pinch without moving the hand clicks the snapped element. Use a system-drawn highlight (no raw gaze cursor). Apply the −120 ms gaze lookback. Measure the late-trigger rate.
5. **Gaze-aware scrolling.** Pinch-hold scrolls whatever you're looking at, not what's under the cursor. Optional auto-scroll when fixations stay in the bottom ~15% while reading (off by default).
6. **Accessibility mode.** Dwell (default 800 ms, adjustable 300–1500 ms) with a radial progress ring on the snapped target, plus a large "pause" zone. Offer blink or facial-gesture confirmation (like Pointer Control) and head-pointer refinement for users without hands.
7. **Privacy by construction.** Gaze never leaves the process and isn't written to disk outside explicit recordings. Show a clear on-screen indicator while the camera is active.

## Pitfalls

- **Visible gaze cursor feedback loop.** The eye chases the lagging, offset cursor. Hide it in control mode or show only the target highlight.
- **Late and early triggers.** Pinch detection latency (camera + Vision, ~50–100 ms) adds to the human offset. Timestamp at frame capture and look up gaze by that timestamp.
- **Pinch-induced gaze shift.** Raising a hand into view can move the head, and head motion degrades webcam gaze. Filter gaze for ~200 ms after hand onset.
- **AX coverage.** Electron, games and canvas apps expose poor AX trees. Fall back to plain MAGIC warp + hand refine.
- **AX latency.** `AXUIElementCopyElementAtPosition` can block for tens of ms on busy apps *(unverified magnitude)*. Run it off the main thread and cache by window.
- **Dwell fatigue and Midas touch** in accessibility mode. Always provide a way to pause.
- **Permissions.** Camera, Accessibility (AX + CGEvent posting) and possibly Input Monitoring. A sandboxed App Store build can't post events, so distribute outside the store.

## Sources

- https://research.google/pubs/manual-and-gaze-input-cascaded-magic-pointing/
- https://www.semanticscholar.org/paper/Manual-and-gaze-input-cascaded-(MAGIC)-pointing-Zhai-Morimoto/449a34976985c0f858ff2c0541fc6c35f47e1b80
- https://eprints.lancs.ac.uk/id/eprint/156432/ (Gaze + Pinch, SUI 2017)
- https://research.google/pubs/design-principles-and-challenges-for-gaze-pinch-interaction-in-xr/ (CG&A 2024)
- https://dl.acm.org/doi/10.1145/3715669.3723126 (GazeHandSync, late-trigger stats)
- https://arxiv.org/html/2603.26608 (Sticky and Magnetic) and https://arxiv.org/pdf/2503.05456 (PinchCatcher). Seen in search results only.
- https://pubmed.ncbi.nlm.nih.gov/32348191/ (gaze-lock cursor)
- https://arxiv.org/pdf/2204.08156 (dwell selection design) and https://arxiv.org/html/2002.08455v2 (Midas touch / EyeTAP)
- https://hci.stanford.edu/publications/2007/chi253-kumar.pdf (EyePoint) and the GUIDe scrolling tech note. Search summaries only.
- https://developer.apple.com/videos/play/wwdc2023/10073/ (Design for spatial input)
- https://appleinsider.com/articles/24/02/13/apple-vision-pro-privacy-means-apps-cant-access-details-of-users-surroundings
- https://appleinsider.com/articles/24/06/13/eye-tracking-lets-you-navigate-ios-18-without-touching-your-iphone
- https://support.apple.com/guide/mac-help/use-head-pointer-mchlb2d4782b/mac
- https://blog.google/innovation-and-ai/products/google-project-gameface/
- https://support.microsoft.com/en-us/windows/eye-control-basics-in-windows-97d68837-b993-8462-1f9d-3c957117b1cf
- https://help.tobii.com/hc/en-us/articles/214220965-Windows-Interaction-features-for-Predator (Mouse Warp)

Note: arxiv.org, medium.com, hci.stanford.edu and eprints.lancs.ac.uk were blocked for full-text fetch. The numbers above come from search-result abstracts.
