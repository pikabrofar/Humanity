# Process notes: the sentidoS launch film

These notes record the decisions, techniques, problems and lessons from making the 9:16 launch film, in a form another creator or model can reuse. They describe what was decided and why, not how the thinking went.

The creative brief and the beat sheet are in [`LAUNCH_PLAN.md`](LAUNCH_PLAN.md).

---

## 1. What came before, and why it wasn't good enough

| Attempt | What it was | What the owner said / what was wrong |
|---|---|---|
| Launch v1 | Screen capture of the marketing site, with music and SFX | "Too much copied from the website." It also had a thumping kick drum the owner disliked. It explained the website, not the product |
| Teaser | Original motion graphics (an eye drawing, a stick hand, bars) with one-word captions | Good for a teaser, but it showed **symbols** of the product, never the product working |
| Launch v2, first cut | This film, before review | UI too small on a phone; one composition for 27 s; static holds |

**Takeaway:** a launch film has to show **the product doing something to the viewer's own screen**, big enough to read on a phone, and it must not feel like a website tour.

## 2. Key creative decisions

| Decision | Alternatives considered | Why this one |
|---|---|---|
| **"Cause above, effect below."** A split frame: the input (eye, hand, voice) on top, and the Mac screen with its **camera notch** underneath | Website capture; symbolic motion graphics; live action; full-frame UI only | Cause and effect read in under 1 s with the sound off. One grammar, reused three times, costs the viewer no attention. The notch silently says "the camera you already have" |
| **Rebuild the product UI from the source code**, not from marketing art | Copy the site's demos; invent generic UI | The UI is credible because it's faithful to the code: 44 pt gaze ring, 1.0 s default dwell, 0.28 s critically damped spring, 48 pt dictation pill, 236 pt menu bar panel. A subagent pulled these constants from the SwiftUI source |
| **The hook starts mid-action.** Frame 0 already shows the eye, Mail and the gaze ring. At 0.27 s the ring springs to Send. Headline: "It clicks where you look." | "No mouse. No trackpad." (negative framing, reused from the teaser); logo first | Action before explanation. The claim is literal and visible right away |
| **Explain the name once.** "Meet sentidoS.", labelled "Spanish for 'senses'" | No explanation | It turns an odd word into a memorable one, at the cost of 3 words |
| **The peak is the combination, not a feature:** look at Save, pinch, saved. Then 0.3 s of silence, then the only slam in the film: "No headset required." | A feature list; ending on privacy | It's the most novel thing the product does (headset-style interaction on a normal Mac), placed around 50% in, where retention dips |
| **Trust is the one full-frame pattern break mid-film.** Frames fall into an "on-device" chip, and the path to the cloud is crossed out | A list of privacy bullets | A visual metaphor reads faster than bullets, and the change of layout resets attention before the final third |
| **The device hero shot comes late** (about 80%): a MacBook in 3D, then a push-in on the real menu bar panel | Opening on the device | Early on, the viewer cares what it does. Late, "it's one small app" closes the loop |
| **CTA:** logo, tagline, "Free for Mac · Out now", URL and "Link in bio", held for 3.8 s or more | "Link in bio" only | The owner chose to show the URL, which works even when the caption is hidden |
| **Music without a kick drum** (the owner disliked thumping). The groove comes from a gentle duck on every beat plus UI foley as percussion. A three-note motif stands for the three senses. Also shipped as an SFX-only mix | A beat with drums; a library track | Matches the owner's taste and stays rhythmic. The no-music mix lets them use a trending sound |
| **Restrained VFX:** real motion blur (sub-frames), glow only on emissive UI, a 2% push only on three impacts | Zoom punches on every beat; glitch and RGB split | The teaser's punches read as a template. Restraint reads as premium and keeps the UI legible |

## 3. Production methods

**Rendering:**
- **Deterministic HTML film.** One page exposes `draw(t)` for any time `t`. Playwright renders frames at 1080×1920 (540×960 CSS at 2×), so nothing depends on real time.
- **Motion blur from sub-frames.** Fast spans declare `fast(a, b, n)`. Those frames render n sub-frames across a 180° shutter, and the finishing pass averages them. Only about 25% of frames pay for this.

**Picture:**
- **Shader iris.** A WebGL fragment shader draws:
  - the iris: fibres in polar 3D noise, the collarette, crypts and the limbal ring;
  - the eye around it: a sphere-shaded sclera, lids with a lash line and a cast shadow;
  - the cornea's reflections, including the Mac's screen.

  It is foreshortened by the look vector, and zoom is in the shader, so the push through the pupil stays sharp.
- **Hand.** 21 joints with forward kinematics and two-bone IK for the thumb. A **3/4 yaw (−30°)** is what makes a pinch readable; head-on it collapses.
- **Logo.** three.js: an extruded squircle with a clearcoat, under a RoomEnvironment. **NeutralToneMapping**, because ACES desaturated the brand gradient.
- **A virtual camera inside the device screen.** Every action gets a push-in to 1.3–1.6× and, where relevant, a soft follow of the gaze or pointer, then a pull-back before each Spaces swipe. This one change fixed most of "the UI is too small on a phone".
- **Vision-style overlays.** Lid contour points and a tracked pupil crosshair with live coordinates make the technology visible without words.

**Sound:**
- **Synthesized from the same event list as the picture**, so it's in sync by construction.
- **Instruments:** additive plucks and felt piano (exact tuning, high partials decay faster), FM bells, detuned saw pads, and a three-band reverb.

## 4. Automated QA gates (run on every frame)

1. **Fonts actually loaded.** The render aborts otherwise. Google Fonts failed silently in headless Chromium behind the TLS proxy, so launch v1 shipped in Arial. Fonts are now local files.
2. **Text inside the frame.** Measure glyph rects (text nodes), not element boxes.
3. **Platform safe zones** at 540×960 CSS:
   - top 78 px is off limits;
   - nothing key below y 772;
   - right action rail: x > 476 for y 430–840.
4. **Reading time** at 200 wpm: `words × 9 + 8` frames minimum on screen, at full opacity.
5. **Audio.** Loudness: −14 LUFS / −1 dBTP (full mix), −16 LUFS (no-music mix). Energy below 60 Hz under −35 dB, which backs up "no thumping". The pre-peak silence is checked at −62 dBFS.
6. **UI target positions** are measured from the DOM and asserted non-zero.
7. **Human review:**
   - contact sheets every 0.33 s of the *sequential* render;
   - full-resolution spot checks of every camera move;
   - a spectrogram of the stems with section markers.

## 5. Problems and their fixes

| Problem | Cause | Fix |
|---|---|---|
| Whole first video in Arial | Google Fonts blocked by TLS in headless Chromium, failing silently | Serve local font files; assert `document.fonts` loaded |
| Layers never appeared | `display = ''` falls back to a CSS `display: none` | Set an explicit `block` |
| Pointer drag ran to the corner | UI targets were measured while their layer was hidden, giving (0,0) | Measure with the layer visible; assert non-zero |
| Old overlays appeared over later beats in stills | Chromium can keep a cleared canvas's old texture in the compositor | Hide overlay canvases (`display: none`) whenever unused |
| `pkill -f "node render.js"` killed its own shell | The pattern matched the command line running it | Use a bracketed pattern (`render[.]js`) |
| Render took about 1.5 s per frame | A full-frame shader was evaluated outside its panel | Early-out outside the panel rect (about 4× faster) |
| Pale, washed-out logo on entry | Clearcoat reflecting the bright environment when tilted toward the camera | Enter tilted away, matching the title shot |
| Brand gradient looked pastel | ACES tone mapping | NeutralToneMapping |
| Pinch unreadable | Head-on view hides index curl | 3/4 yaw, deeper index flexion |
| Dictation pill text too small | True-to-scale UI on a phone | Narrower pill plus a 1.34× camera push |
| The silence before the peak wasn't silent | Reverb tail added after the gate | Gate after the reverb as well |
| Site capture lagged scroll (v1) | CSS `scroll-behavior: smooth` without Lenis | Force `scroll-behavior: auto` in captures |

## 6. Lessons for future launch videos

1. **Show the input and the result in the same frame.** If a viewer must infer causality across a cut, many won't.
2. **Rebuild the product's UI from its own constants** (sizes, colours, strings, timings). It's more credible, and the owner can verify it.
3. **Design for a 6-inch screen first.** Key UI text should be ≥ 16 CSS px at 540 wide, and every interaction gets a 1.3–1.6× push-in.
4. **One grammar, many beats.** Keep the layout constant so attention goes to what changes, and break it exactly twice: trust and the CTA.
5. **One emphatic moment.** A single slam after a single silence lands; ten of them don't.
6. **Restraint reads as quality:** motion blur over glitch, glow only on things that emit light.
7. **Measure, don't assume:** fonts, positions, reading time, loudness, low end and silence are all checkable by script.
8. **Review the real sequential render**, not just stills. Stills can hide or invent state bugs.
9. **Write the claim list first.** Every on-screen claim maps to a line in the README or PRIVACY.md.
10. **Ship two mixes** (full and no-music). Social platforms reward trending sounds.

## 7. Reusable checklists

**Before building:** the claim list with sources; the owner's constraints (CTA, music taste, length, platforms); the UI spec from code; a beat sheet with reading-time math; safe-zone overlay.

**Per beat:** an input, an effect and a headline; one camera move; sound events registered with times; fast spans flagged for motion blur.

**Before delivery:** all audit gates pass; a contact sheet of the sequential render reviewed; full-resolution checks of the hook, peak and CTA; loudness and peaks measured; both mixes encoded; a preview under the chat upload limit.

## 8. Files

| File | What it is |
|---|---|
| `LAUNCH_PLAN.md` | The brief, concept, beat sheet and retention plan |
| `film/` | The film as a web page: `core.js` (engine and audits), `scenes.js` (beats), `iris.js`, `hand.js`, `ui.js`, `logo.js` |
| `render.js` | Frame renderer with sub-frame blur and audits; writes `events.json` and `audit.json` |
| `audio/` | `lib.py` (DSP and instruments), `build.py` (stems and mixes from `events.json`) |
| `vfx.py` | Finishing pass and encode |
| `tiktok-rebrand/` | Profile kit for the account |
