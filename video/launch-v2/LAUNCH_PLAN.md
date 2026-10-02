# sentidoS — Launch Film (9:16, ~47 s)

## 0. Inputs and constraints

- **Deliverables:** 9:16, 1080×1920, 30 fps. Two mixes from the same picture:
  - **A:** original score + SFX + ambience.
  - **B:** SFX + ambience only, for a trending sound.
- **Where it runs:** TikTok, Reels and Shorts, so most people watch with the **sound off** and decide in about 1 s whether to keep watching.
- **CTA (decided with the owner):** "Free for Mac · Out now", the URL **pikabrofar.github.io/sentidoS**, and "Link in bio".
- **Claims come only from the README, PRIVACY.md and the source:**
  - free and MIT
  - macOS 14+ on Apple silicon
  - uses the webcam and mic you already have
  - video and audio processed on the Mac
  - no account, subscription, analytics or telemetry
  - default dwell 1.0 s
  - hotkeys ⌃⌥⌘D, ⌃⌥⌘G and ⌃⌥⌘H
  - cleanup removes fillers ("um so I think we should uh…" becomes "So I think we should…")
  - we never claim perfect accuracy
- **UI accuracy:** the on-screen product UI is rebuilt from the SwiftUI source, not from the marketing site. That covers the panel, gaze ring, dwell arc, pinch HUD, dictation pill and summary card (spec in PROCESS.md).
- **Reading budget:** 200 wpm, which works out to 9 frames per word plus 8 frames to find the line. A render-time audit enforces it.

## 1. What the teaser did, and what the launch must do better

| Teaser | Weakness | Launch fix |
|---|---|---|
| Each sense was a symbol (an eye drawing, a stick hand, bars) with a one-word caption | It shows **what** the product is, never **what happens on your Mac**. Nobody sees a cursor actually move | Every demo pairs **input → result**: the eye or hand above and the Mac screen below, moving together in the same frame |
| Hook: a faint dot grid, then "Look." | The first second is mostly black, and it's an icon rather than an event | The first frame is mid-action: an iris darts and a real gaze ring jumps to **Send**. Cause and effect are readable in about 0.5 s, sound off |
| Same scale-and-blur slam on every caption | Monotone. The emphasis wears out fast | Typography hierarchy: line-mask reveals for headlines, one slam for the peak line, mono labels for chapters |
| The Mac was a flat CSS card that appeared once | Low perceived quality, and the product UI was small | The product UI is the hero, at legible size and pixel-faithful to the app. The device comes in at the 75% mark as a proper hero shot |
| Generic hits on every caption | The sound didn't describe the product | Foley tied to UI physics: lock-on, dwell fill, click, pinch, drag, flick, keycaps, typing, filler strike-outs |
| No privacy story, no combined interaction | Missed the two most distinctive things the product does | Two new beats: **look + pinch (no headset)** at the novelty peak, and **"never leaves your Mac"** as the trust beat |
| Grain and zoom punches as the "VFX" | Felt like a template | Restrained VFX that make the product read better: real motion blur, depth of field, glow on light-emitting UI, one pupil push-through |

## 2. Creative concept: "Cause above, effect below"

The frame is split vertically:

- **Top: input.** An eye, a hand, or a voice, as the camera and mic sense it.
- **Bottom: output.** The Mac's screen. The **camera notch is visible on its top edge**, facing the input above it.

The viewer learns this grammar in the hook and reuses it three times, so each new sense costs almost no attention. The split collapses for the "ensemble" moments (title, privacy, device, CTA), so those moments feel bigger.

**Narrative arc:**

1. **Hook:** show it working.
2. **Name it:** sentidoS, "Spanish for senses".
3. **Three senses**, building up.
4. **The two senses combined** (the peak).
5. **Why it's safe.**
6. **It's one small app.**
7. **Get it.**

**Recurring device:** a three-light "senses" HUD at the top of the frame. It lights in each module's colour as that chapter starts, and works like a progress bar the viewer wants to see filled. All three light together on the device shot.

## 3. Beat sheet (exact timing; 30 fps; music grid 120 BPM = 15 frames per beat)

| # | Time (s) | Beat | Picture | On-screen text (reading check) | Sound |
|---|---|---|---|---|---|
| 1 | 0.0–3.0 | **Hook** | Split. **Top:** a macro iris (WebGL shader: fibres, limbal ring, wet highlight, screen reflection). **Bottom:** the MacBook screen with the notch and green camera LED. Mail compose is open. Frame 0 is already mid-motion: at 0.27 s the iris darts down-right, and the ring springs to **Send** (spring 0.28 s, no overshoot, as in the code). The dwell arc fills for **1.0 s**, then the click sends the mail and the window flies off | "It clicks where you look." (5 words, needs 53 f; on screen 78 f) | Soft lock-on tick, a rising dwell tone, a crisp click, a send whoosh. Score: muted pulse and riser |
| 2 | 3.0–6.0 | **Name it** | A push through the pupil goes to black. Three glass discs (blue, purple, orange) rise out of the dark and land in the icon. A light sweep crosses it | "Meet sentidoS." · label "sentidos — Spanish for “senses”" | Air whoosh into the pupil, then a cinematic hit with shimmer. The three-note "senses" motif plays |
| 3 | 6.0–9.5 | **Eyes 1** | HUD light 1 comes on. The split returns. A document fills the bottom. Faint **raw gaze samples** jitter around a **steady ring** (the fixation stabilizer, made visible); the ring then jumps word cluster to word cluster | chapter "01 · ojoS · eyes" · "Steady while you read." (4 w) | Tiny ticks on each saccade. The groove begins: pluck arpeggio, soft bass pulse, no kick |
| 4 | 9.5–13.0 | **Eyes 2** | The gaze lands on a link, and the keycaps ⌃⌥⌘G press in sync. The link opens with a page slide | "Or look, then press ⌃⌥⌘G." (4 w + keys) | Mechanical keycap clacks, a click, a page swish |
| 5 | 13.0–16.8 | **Hands 1** | The iris breaks into landmark points, which fly together into a **21-joint hand** (point morph). The bottom swipes to a new Space (Photos). An open palm moves the pointer; the manoS HUD ring closes as you pinch; the photo is dragged into the album, with the ring turning green while dragging | "02 · manoS · hands" · "Pinch to click. Hold to drag." (6 w) | A pinch "pop", a drag swish, a drop thunk. A counter-melody layer joins |
| 6 | 16.8–20.5 | **Hands 2** | A V-sign flicks up twice and Keynote-style slides advance, with the chevron HUD symbol | "Flick a V for the next slide." (6 w) | Two flick whooshes and slide clicks |
| 7 | 20.5–25.5 | **Peak: look + pinch** | The top panel splits into **iris + hand**. A "Save changes?" dialog sits below. The gaze ring travels to **Save**, the hand pinches, and you see "Saved". At 23.6 s the music cuts to silence for 0.4 s; then the headline slams | "Look at it. Pinch to click." (6 w), then "No headset required." (3 w; the only slam) | Silence, then the biggest hit after the title. The full chord returns |
| 8 | 25.5–31.0 | **Voice 1** | The hand joints flatten into a line that becomes a **waveform**. Keycaps ⌃⌥⌘D are **held**. Bottom: Mail, with the real **bocaS pill** (black capsule, pulsing red dot, 5 level bars, live words, an "esc" keycap). The live words read "um so I think we should uh move the launch to thursday". **Release:** "um" and "uh" strike out and disappear, and the clean sentence types into the mail: "So I think we should move the launch to Thursday." | "03 · bocaS · voice" · "Hold ⌃⌥⌘D and talk." (4 w + keys) → "Let go. It types it, cleaned up." (7 w) | Start chime (two notes), soft typing, filler "zips", a typing burst |
| 9 | 31.0–33.0 | **Voice 2** | A voice-note **Summary** card (sparkles) with three action items checking in | "Notes that summarize themselves." (4 w) | Card whoosh and three check pops |
| 10 | 33.0–37.6 | **Trust** | A pattern break: the split closes. Frames stream from the notch camera into a rounded "Mac" boundary, are analysed (landmark dots) and **dissolve inside**. Nothing crosses the boundary. A lock settles | "Video and audio never leave your Mac." (7 w) → "No account. No subscription. No telemetry." (6 w) | Breakdown: pad and felt piano only. Digital chirps as frames dissolve; a lock "clunk" |
| 11 | 37.6–40.6 | **Device** | Pull back to a full 3D MacBook (aluminium shading, reflections). The `figure.arms.open` icon opens the real QuickPanel; the three tiles switch on (Tracking · Active · Ready). All three HUD lights come on | "All three. One menu bar app." (6 w) | Three toggle pops in rising pitch; the arpeggio and a riser build |
| 12 | 40.6–47.0 | **CTA** | Match cut: the menu bar icon scales into the lit 3D logo. Then the wordmark, then the tagline. At 43.0 the CTA stack: "Free for Mac · Out now" (pill), the URL, "Link in bio". The last 1.5 s holds still | "sentidoS" · "Control your Mac with your eyes, hands and voice." (9 w, needs 89 f; on screen 190 f) · CTA (≈11 w, needs 107 f; on screen 120 f) | Resolve chord, bell motif, a soft sub swell, then the tail rings out |

## 4. Retention strategy

- **0–1 s:** the action starts before any explanation. Sound-off viewers get cause and effect from the split frame alone.
- **Every 2.5–3.5 s, something new happens**: a new shot, headline or interaction. There are no stretches of only motion or only text.
- **Open loop:** the three-light HUD tells viewers there are three things to see.
- **Escalation:** single sense → combined senses (the peak at about 50%) → voice with a twist (cleanup) → trust → payoff. Energy dips only once, at the trust beat, so the CTA can rise.
- **One silence**, right before the peak line, to break the pattern.
- **The CTA holds long enough to act:** the URL is on screen for 4 s or more.

## 5. Typography

- **Brand fonts, served locally and checked before rendering:**
  - Instrument Sans 600 for headlines
  - Fragment Mono for labels
- **Sizes:**
  - Headline 44–52 px (CSS at 540 wide), tracking −0.035em, sentence case, at most 2 lines.
  - Chapter label 12 px mono with +0.16em tracking.
- **Motion:**
  - Headlines reveal with a line mask (rise 110% to 0 over 0.5 s, expo-out) and leave by fading upward.
  - Only "No headset required." uses a slam.
- **Keycaps** are drawn as real key objects (⌃ ⌥ ⌘ + letter) that physically press.
- **Safe zones** (checked automatically on every frame):
  - Key text stays out of the top 8%, the bottom 20% (caption area) and the right-hand action rail.
  - Text never touches the frame edge (24 px or more).

## 6. Picture and VFX

- **Product UI is the hero:** large, crisp, faithful to the code (sizes, colours, strings, timings).
- **Motion blur:** frames with fast movement are rendered as 4 sub-frames and averaged (a 180° shutter). This gives true blur on saccades, flicks and flies instead of judder.
- **Depth:** background windows soften (blur) when the foreground has focus, and the split halves sit on separate layers.
- **Light:** subtle bloom only on things that emit light (gaze ring, LED, logo highlights). Fine grain and a vignette tie the shots together.
- **Never:** constant zoom punches, glitch spam, or RGB split on body text.

## 7. Sound

- **Score: original, 120 BPM, no kick drum.** It builds from a muted pulse to plucks, then adds a counter-melody, then breaks down, then resolves.
  - A three-note "senses" motif ties the title to the CTA.
  - Percussion comes from the UI foley itself.
- **SFX:** matched to UI physics: lock-on, dwell fill, click, pinch, drag, drop, flick, keycaps, typing, strike-outs, toggles, lock.
- **Ambience:** low room tone, so silence never sounds empty.
- **Loudness:** mix A at −14 LUFS, true peak −1 dBTP. Mix B at −16 LUFS (it sits under a trending sound).

## 8. QA gates (automated where possible)

1. Fonts loaded (otherwise the render fails).
2. No text outside the frame.
3. Key text inside the safe zones.
4. Every text block on screen for at least its 200 wpm reading time.
5. Claim audit against the README and PRIVACY.md.
6. Contact sheet plus full-res frame review of every beat.
7. Loudness measured.
8. A final review of the whole film.
