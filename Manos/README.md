# manoS

Part of [sentidoS](../README.md). Control your Mac with your hand through the
webcam: point with your palm, pinch to click, drag and scroll. It uses Apple
Vision hand-pose detection on-device. There's no extra hardware, and no video
leaves your Mac.

## Gestures

| Gesture | Action |
|---|---|
| Move your palm | Move the pointer. Slow movements are precise; fast ones cross the screen. |
| Pinch thumb + index | Click (two quick pinches double-click). Hold and move to drag. |
| Pinch thumb + middle | Right-click. Hold and move to scroll. |
| Make a fist | Hold the pointer still while you reposition your hand (clutch) |
| Curl middle, ring and little fingers, then pinch thumb + index | **Anchored click:** the pointer locks in place, so the click lands exactly there |
| Hold up two fingers (V) and flick up / down | Next / previous item: Shorts, TikTok, Reels, feeds, pages, slides. The pointer holds still while the V is up. Scrolls the window under the pointer by one screen, or sends ↓/↑ keys (Settings → Flick) |
| Spread your hand and hold still for 1.5 s | Pause or resume (⌃⌥⌘H also resumes) |
| **⌃⌥⌘H** | Turn hand control on or off from anywhere (kill switch) |

Touching the real mouse or trackpad pauses hand input for 1.5 s, so the two
never fight.

## Install

Download the DMG from [Releases](https://github.com/pikabrofar/sentidoS/releases),
or build it from source:

```sh
git clone https://github.com/pikabrofar/sentidoS.git
cd sentidoS/Manos
make run
```

On first launch, **Quick Setup** walks you through three steps. It takes about a
minute.

1. **Camera:** manoS watches your hand.
2. **Accessibility:** lets manoS move the pointer and click.
3. **Fit to your hand:** hold your hand relaxed, then pinch three times. This
   sets your personal click thresholds.

A **Practice** page then lets you click targets, drag a card, and scroll a list.

**Tip:** rest your elbow on the desk and keep your hand low in the camera's
view. Pointing is relative, like a trackpad, so small wrist movements are
enough, and the fist clutch lets you re-center.

## How it works

| Stage | What happens |
|---|---|
| Camera | 720p feed |
| Vision | `VNDetectHumanHandPoseRequest`, 21 joints |
| `HandPose` | The view is mirrored and aspect-corrected. Distances are measured in "palm units" (the mean size of the wrist / index-MCP / little-MCP triangle), so thresholds work at any distance from the camera. |
| `GestureRecognizer` | A state machine: engage dwell, pinch hysteresis plus debounce, click rewind, drag slop, scroll, clutch, pause |
| `PointerMapper` | Relative pointing with acceleration |
| `EventInjector` | Posts `CGEvent` mouse and scroll events |

Safeguards against accidental input (the "Midas touch" problem):

- **Engage delay:** nothing happens until a hand has been steady in view for
  250 ms.
- **Pinch thresholds:** a pinch must hold for two frames. It starts below one
  threshold and ends above a higher one, so a pinch near the threshold doesn't
  flicker.
- **Open between clicks:** the fingers must open before the next click, so a
  hand that comes into view already pinched (holding a pen or a mug) doesn't
  click.
- **Click rewind:** the click lands where the pointer was when the fingers
  started closing (50–250 ms earlier), which undoes the drift that pinching
  causes. It never reaches back past the end of a drag.
- **Drag slop:** a held pinch only becomes a drag after moving past a small
  distance.
- **Leaning:** the pointer follows the palm's position measured from the image
  centre, in palm widths, so leaning toward or away from the camera barely
  moves it.
- **Tracking loss:** losing the hand, or frames stopping, releases any held
  button or scroll.

`HandKit` has no UI and is fully unit-tested with synthetic hand-pose sequences
(`make test`).

## Permissions after rebuilding

The default ad-hoc signature changes on every build, so macOS may forget the
Accessibility grant. If you see the toggle on but manoS can't click, remove
manoS from the list with **–**, then add it again. Or sign with a stable
certificate: `SIGN_ID="sentidoS Self-Signed" make app`.

## License

MIT
