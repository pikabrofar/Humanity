# Multimodal Interaction Design for Humanity: Gaze + Hand + Voice

## Summary

The best-tested hands-free model is to **look to target, then act with a second modality to commit**. visionOS ships it as "look and tap" (gaze plus indirect pinch). Pfeuffer et al. showed it in research as Gaze + Pinch, Bolt's "Put-That-There" did it with gaze/pointing and voice, and Talon users do it with eye tracking and voice or noise commands. In Humanity, OculOS should only point. ManOS and voice should do the committing. A single input arbiter should decide which modality controls the cursor at any moment. For architecture, use **one background "Humanity Core" agent** that owns the camera, the Vision models, event synthesis and arbitration. The three apps become front-ends that talk to it over XPC and share settings through an App Group container.

## Key findings

- **Gaze points, it never commits.** If looking alone triggers actions, everything you glance at gets clicked (the "Midas touch" problem). Gaze + Pinch splits the job: eyes pick the target and the hand confirms or manipulates it. The 2024 design-principles paper lists eye-hand coordination, late triggering, gaze jitter, feedback and fatigue as the main issues.
- **The eyes move on before the commit lands.** By the time a pinch or spoken word is recognized, the eyes are often already looking elsewhere. Keep a short gaze history buffer and resolve the target from the fixation just before the commit began, not the gaze sample at the moment it was recognized.
- **Gaze plus hand beats hands alone.** In Gaze-Hand Alignment (Lystbæk, Pfeuffer et al., 2022), gaze-assisted techniques were faster than hands-only input for menus. Gaze&Hand (gaze sets the cursor roughly, relative hand motion fine-tunes it) suits a webcam setup, where gaze accuracy is coarse.
- **visionOS keeps gaze private.** Hover feedback is drawn outside the app's process, so apps only learn what was targeted once a gesture fires. Humanity should follow the same rule: gaze stays inside Core and front-ends receive only resolved intents.
- **Voice needs a time window to pair with pointing.** Put-That-There required the speech and pointing events to land within roughly **1.5 s**. Talon's "control mouse" (eye tracker places the cursor, then voice, a hiss/pop or a key clicks) and "zoom mouse" (a pop zooms the screen, a second pop clicks) show that people accept a two-stage approach: look roughly, then refine or zoom.
- **Camera sharing on macOS is unreliable, and running the models twice is wasteful.** The built-in camera can often be opened by several apps at once, but USB webcams often cannot. Even when sharing works, two apps would each run Vision face and hand inference on the same frames. One capture session should feed both face landmarks (gaze) and hand pose (ManOS).
- **IPC options compared:**
  - **XPC (`NSXPCConnection` to a Mach service):** two-way, typed, and can check the caller's code signature. Best for the event stream and commands.
  - **`DistributedNotificationCenter`:** broadcast only, and **sandboxed senders must pass `userInfo = nil`**. Only good for coarse signals such as "paused".
  - **App Group container:** shared `UserDefaults(suiteName:)` and files. Right for calibration, settings and models, wrong for real-time events.

## Recommendations (ranked)

1. **Build `Humanity Core` as a login-item agent** (`SMAppService.agent`) that exposes a Mach-service XPC endpoint. Core owns:
   - one `AVCaptureSession`
   - a Vision pipeline that runs face-landmark and hand-pose requests on the same frame
   - the voice engine's command channel
   - the only `CGEvent` poster

   This also means camera, Accessibility and Input Monitoring permission is granted once, to one binary. OculOS, ManOS and Dictation become thin UIs that subscribe to Core. Each app should still run standalone when Core is not installed, for gradual adoption.
2. **Make the arbiter an explicit state machine** (`idle`, `pointing`, `dragging`, `dictating`, `paused`). Modalities emit *intents* such as `target(gazePoint, confidence)`, `commit(kind)`, `command(text)` and `cursorDelta`, never raw clicks. Rules:
   - gaze can never commit
   - while `dictating`, ManOS commands are suppressed except pause
   - hand motion overrides gaze for the cursor until it has been still for about 500 ms
   - a real mouse or trackpad event pauses all synthetic pointer output for about 2 s
3. **Add one global pause that works from every modality**: a hotkey, the voice command "Humanity sleep", a held open palm, and a menu-bar toggle. All of them route to Core's `paused` state, and Core broadcasts it through a userInfo-less distributed notification and XPC. A menu-bar HUD shows which modalities are live and how confident tracking is.
4. **Use XPC for real-time data, the App Group for state, and distributed notifications only for pause or mode changes.** Version the XPC protocol, verify that peers are signed with the same team ID, and keep the shared settings schema in the App Group.
5. **Snap targets with the Accessibility API.** Webcam gaze is accurate only to within a few centimetres of screen, so snap the gaze point to the nearest actionable `AXUIElement`, much as visionOS uses hover regions. Show a subtle highlight before the commit, which is the visionOS hover-feedback idea applied to the Mac.

### Top 5 combined features

1. **Look + Pinch click**: gaze targets (with AX snapping), ManOS pinch clicks, and pinch-and-hold drags. This is the visionOS model on a Mac.
2. **Look + Speak**: commands like "click", "open that" and "close this" act on the gazed element. "Type here" focuses the gazed text field and starts dictation there. A "move this... there" two-step uses a 1.5 s fusion window per deictic word ("this", "there").
3. **Gaze-warp + hand refine** (Gaze&Hand style): the cursor jumps to the gaze point, then relative hand motion makes pixel-accurate adjustments.
4. **Gaze-targeted scroll and zoom**: pinch-and-move (or the voice command "scroll down") scrolls whichever pane you are looking at, not whichever pane the cursor is over. Pinch-spread zooms the screen around the gaze point (Talon zoom-mouse style).
5. **Context-aware modality switching with global pause**: dictation automatically mutes gestures, and looking away from the screen or turning your head pauses gaze. A single pause gesture or phrase stops everything.

## Sources

- https://www.semanticscholar.org/paper/Gaze-+-pinch-interaction-in-virtual-reality-Pfeuffer-Mayer/2ef382e5ba0a7f000ec8e7972d305f6c49f4b1cf
- https://arxiv.org/pdf/2401.10948
- https://pure.au.dk/portal/en/publications/gaze-hand-alignment-combining-eye-gaze-and-mid-air-pointing-for-i/
- https://dl.acm.org/doi/10.1145/3544548.3581423
- https://arxiv.org/pdf/2503.05456
- https://dl.acm.org/doi/10.1145/800250.807503
- https://www.atlantis-press.com/article/25848709.pdf
- https://developer.apple.com/videos/play/wwdc2023/10073/
- https://developer.apple.com/videos/play/wwdc2025/303/
- https://talon.wiki/Resource%20Hub/Hardware/tobii_4c/
- https://github.com/dwiel/talon_community/wiki/Eye-Tracker
- https://handsfreecoding.org/2021/12/12/talon-in-depth-review/
- https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession
- https://maketecheasier.com/use-webcam-with-multiple-programs/
- https://developer.apple.com/forums/thread/129437
- https://christiantietze.de/posts/2015/01/xpc-helper-sandboxing-mac/
- https://developer.apple.com/forums/thread/704673
