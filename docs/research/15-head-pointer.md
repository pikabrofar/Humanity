# 15 — Head pointer / nose-tracking cursor control

## TL;DR

- A head pointer moves the cursor with head motion instead of gaze. It is slower than gaze but **much more precise and stable**, because the head doesn't saccade and a webcam can track a nose to sub-pixel accuracy.
- Mainstream tools (Camera Mouse, eViacam, Project Gameface, and macOS Head Pointer's "Relative to Head" mode) all use **relative (rate/delta) mapping**: speed, then acceleration, then smoothing, with a dead zone.
- Track a **rigid, high-texture point** such as the nose tip. For translation invariance, use the nose tip's offset from the face-box centre, or head yaw/pitch.
- The best-supported design is **gaze for the coarse jump, head for the fine correction** (MAGIC-style; BimodalGaze, GazeSwitch, Kytö et al. "Pinpointing").
- oculOS can build a head pointer from the `VNFaceObservation` it already computes, so it costs no extra model.

## Key findings

- **Apple Head Pointer** (macOS Accessibility → Pointer Control) has two modes:
  - *Relative to Head*: the pointer follows head movement wherever you face.
  - *When Facing Screen Edges*: a joystick/rate mode. The pointer moves toward whichever edge you face, and a "Distance to Edge" setting acts as a dead zone.
  - Both modes have speed settings and camera choice, and facial expressions can be mapped to clicks.
- **Project Gameface (Google, Apache-2.0; repo archived Sep 2025):**
  - Uses MediaPipe Face Landmarker, and the cursor "follows my nose".
  - Has separate speeds per direction (up/down/left/right), `mouse_acceleration`, and smoothing.
  - Facial gestures (mouth open, brow raise) click.
  - *(unverified)*: the exact landmark (nose tip vs. between the brows) and the recentering hotkey.
- **Enable Viacam (eViacam, GPL):**
  - Settings: speed, *acceleration* ("faster when you move your face faster"), *smoothness* (filters tremor), and dwell click.
  - It auto-detects the face to recentre the tracking area.
  - *(from memory)*: it computes optical flow over a face ROI, not a single landmark, and has an "easy stop" motion threshold.
- **Camera Mouse (Boston College, Betke/Gips 2002)** *(from memory)*: the user clicks a feature, usually the nose tip or between the eyebrows. That patch is tracked by template correlation, and its displacement drives the pointer. Clicking is by dwell.
- **Transfer functions:**
  - *Absolute* mapping (head angle → screen position) needs calibration and forces uncomfortable poses to reach the corners.
  - *Relative* mapping with velocity-dependent gain (like OS pointer acceleration) lets small, slow motions do fine work and fast flicks cross the screen.
  - *Rate* (joystick) mapping is good for low-mobility users but poor for precision.
- **Gaze+head:**
  - Eye pointing is faster but less accurate than head pointing *(ScienceDirect 2022, abstract)*.
  - BimodalGaze and GazeSwitch switch automatically from gaze mode to head mode by classifying "gestural" head movement versus natural eye-head coordination. When the eyes move, the head naturally follows, so that movement must not be read as a correction.

## How to program it

```swift
import CoreGraphics

/// Relative head pointer: nose delta -> cursor delta.
struct HeadPointer {
    var gain: CGFloat = 900            // px per unit of normalized face-box offset
    var accelExp: CGFloat = 1.6        // >1 = acceleration
    var deadzone: CGFloat = 0.0015     // normalized units, kills tremor/jitter
    private var last: CGPoint?

    /// `nose` = nose tip minus face-box centre, divided by face-box width
    /// (translation- and distance-invariant, which leaves mostly rotation).
    mutating func update(nose: CGPoint, dt: CGFloat) -> CGVector {
        defer { last = nose }
        guard let p = last, dt > 0 else { return .zero }
        var d = CGVector(dx: nose.x - p.x, dy: nose.y - p.y)
        let mag = hypot(d.dx, d.dy)
        guard mag > deadzone else { return .zero }
        // Power-law CD gain: slow = precise, fast = travel.
        let v = (mag - deadzone) / dt                  // units/s
        let k = gain * pow(v, accelExp - 1) * dt / mag
        d.dx *= -k                                     // mirror: camera faces user
        d.dy *= -k                                     // Vision y-up -> screen y-down
        return d
    }
    mutating func clutch() { last = nil }             // recentre / lift the "mouse"
}
```

Before calling `update`, run the input through a One Euro filter (see 05). Clamp the output to the screen, then post it with `CGEvent` (see 08).

## Recommendations for oculOS

1. **Add a "Head" pointer mode to VisionGaze** that reuses the existing face landmarks: the nose tip (`landmarks.nose` / `noseCrest`) relative to the face box, or yaw/pitch from `VNFaceObservation` on macOS 12+.
2. **Default to gaze-coarse, head-fine:**
   - A large gaze jump (a saccade over about 5°) warps the cursor to the gaze point.
   - After that, only relative head deltas move it until the next saccade.
   - Suppress head input for about 200 ms after each warp, so the natural head follow isn't applied twice *(tuning guess)*.
3. **Expose three settings, as eViacam and Gameface do:** speed, acceleration, and smoothing. Also offer separate X/Y gain, since vertical head range is smaller.
4. **Provide a clutch/recentre:**
   - A hotkey, a blink-hold, or the hand app's clutch gesture (see 07) resets `last`.
   - Also recentre automatically when the face is re-acquired after being lost.

## Pitfalls

- **Raw nose image position mixes translation and rotation.** Leaning makes the cursor drift. Normalize by the face box, or use pose angles.
- **Neck fatigue:** absolute mapping to the corners is tiring. Keep gain high enough that ±10–15° of head turn covers the screen *(uncertain figure)*.
- **Facial-expression clicks move the nose.** A mouth-open or brow-raise click shifts the landmark. Freeze the cursor while a gesture is being detected (as in 07's freeze-on-pinch).
- **Vision's y-axis points up, and the camera image is mirrored.** Getting either wrong inverts an axis.
- **Low camera frame rate** (Reactions or low light, see 02) makes the acceleration curve feel jumpy. Compute velocity from real timestamps.
- **License:** eViacam is GPL, so don't copy its code. Gameface is Apache-2.0, so its ideas and code can be reused with attribution.

## Sources

- https://support.apple.com/guide/mac-help/use-head-pointer-mchlb2d4782b/mac
- https://mcmw.abilitynet.org.uk/how-to-control-your-computer-with-head-movement-in-macos-15-sequoia
- https://github.com/google/project-gameface
- https://www.digitaltrends.com/computing/project-gameface-turning-my-face-into-a-controller/
- https://eviacam.crea-si.com/help/en/options.htm (blocked; seen only through search snippets)
- https://www.researchgate.net/publication/341181256_BimodalGaze_Seamlessly_Refined_Pointing_with_Gaze_and_Filtered_Gestural_Head_Movement
- https://www.researchgate.net/publication/380359478_GazeSwitch_Automatic_Eye-Head_Mode_Switching_for_Optimised_Hands-Free_Pointing
- https://www.sciencedirect.com/science/article/abs/pii/S0003687022001089
- https://dl.acm.org/doi/10.1145/3544548.3581201
