# Apple APIs to Use or Beware: Vision, Capture, CGEvent, AX, Foundation Models, Liquid Glass

**Summary:** Humanity targets macOS 14+ and is built on macOS 26, so every new API needs an `#available` gate. The biggest risks are system camera effects quietly changing the frames OculOS and ManOS receive, and blocking Accessibility IPC stalling the input pipeline. Gesture Reactions are the worst case, because ManOS's hand poses can trigger them. Next come CGEvent details (click state, scroll phases, secure input) and the Foundation Models 4096-token context window.

## Key findings

- **Swift Vision API** (WWDC24, macOS 15+): `DetectHumanHandPoseRequest`, `DetectFaceLandmarksRequest`, `CoreMLRequest` and others are async/await, `Sendable` value types that fit Swift 6 concurrency. On macOS 14 you still need the `VN*` classes, so a shared protocol plus two backends is the realistic path. iOS 18 also added combined body and hand pose detection in a single request.
- **Hand pose cost** grows with `maximumHandCount` (default 2), because a pose is computed for every detected hand.
- **Camera effects:** Center Stage has `centerStageControlMode` (`.user` / `.app` / `.cooperative`). In `.user` mode an app cannot set `centerStageEnabled`. Portrait and Studio Light are user-controlled through the Video Effects menu, and apps can only read their state. **Reactions** (balloons, confetti) are drawn into the frames your app receives and are triggered by hand gestures such as thumbs-up and peace signs. macOS 14.4+ honours the Info.plist key `NSCameraReactionEffectGesturesEnabledDefault = NO`, but a choice the user has already made overrides it.
- **CGEvent:** Continuous scrolling uses `kCGScrollWheelEventIsContinuous` (88), `kCGScrollWheelEventScrollPhase` (99) and `kCGScrollWheelEventMomentumPhase` (123). Setting a phase tells the system "this is a trackpad gesture", and a malformed sequence can leave apps stuck mid-gesture. While any app holds Secure Event Input, event taps stop seeing keyboard events.
- **AX:** Every AX call is synchronous cross-process IPC with a default timeout of about 6 s. `AXUIElementSetMessagingTimeout` on the system-wide element applies to the whole process, but on any other element it applies only to that ref.
- **Foundation Models:** The context window is 4096 tokens, counting input and output. A session handles one request at a time; a second concurrent call throws `rateLimited`. Other errors include `exceededContextWindowSize` and `guardrailViolation`. `SystemLanguageModel.contextSize` and `tokenCount(for:)` are back-deployed to 26.0 and available from the macOS 26.4 SDK onward.
- **Liquid Glass** (macOS 26): `.glassEffect()`, `GlassEffectContainer` and `glassEffectID(_:in:)` for morphing transitions. Grouping shapes in one container also improves rendering performance.

## Recommendations (ranked)

1. **[ManOS, OculOS] Disable gesture Reactions.** Add `NSCameraReactionEffectGesturesEnabledDefault = false` to Info.plist. At runtime, check `AVCaptureDevice.reactionEffectGesturesEnabled` and `reactionEffectsInProgress`. If gestures are still on, show a hint that opens `AVCaptureDevice.showSystemUserInterface(.videoEffects)`.
2. **[OculOS, ManOS] Take control of Center Stage and detect other effects.** Set `AVCaptureDevice.centerStageControlMode = .app`, then `centerStageEnabled = false`. Center Stage's moving crop invalidates gaze calibration. Watch `isPortraitEffectActive` / `isStudioLightActive` with KVO and warn the user, because both alter the face and skin pixels that landmark detection relies on.
3. **[ManOS] Select 60 fps formats explicitly.** Iterate `device.formats` for a 1280×720 format whose `videoSupportedFrameRateRanges` reaches `maxFrameRate >= 60`. Inside `lockForConfiguration()`, set `activeFormat`, then `activeVideoMin/MaxFrameDuration = CMTime(value: 1, timescale: 60)`. The session preset becomes `.inputPriority`. Many built-in Mac cameras top out at 30 fps, while Continuity Camera usually reaches 60, so fall back cleanly. Set `alwaysDiscardsLateVideoFrames = true`.
4. **[ManOS] Cut Vision cost per frame.** Set `maximumHandCount = 1`. Feed `regionOfInterest` from the previous frame's hand bounding box, padded by about 30%, and run a full-frame search every N frames or when tracking is lost. Reuse request objects across frames. Process only the newest frame (drop the rest), off the main actor.
5. **[OculOS] Run Core ML on the ANE.** Configure `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine`, set `imageCropAndScaleOption` deliberately, and crop the input to the face rectangle before the gaze model. Check in Instruments that the model is not falling back to the GPU.
6. **[ManOS] Make CGEvents well-formed.** Use `CGEventSource(stateID: .hidSystemState)`. For a double-click, set `kCGMouseEventClickState` to 1 on the first down/up pair and 2 on the second. Drags must use `.leftMouseDragged`, not `.mouseMoved`. For scrolling, use `scrollWheelEvent2Source` with `.pixel` units and `IsContinuous = 1`. Either post phaseless events, or a strict Began → Changed* → Ended sequence, always ending the gesture on cancel. Skip synthetic momentum at first.
7. **[ManOS] Gate input around secure input.** Poll `IsSecureEventInputEnabled()`. When it is on, pause keyboard and dictation injection and show the reason. Mouse injection keeps working.
8. **[ManOS] Make snap-to-target non-blocking.** Call `AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.1)` once, then run `AXUIElementCopyElementAtPosition` on a background queue at no more than 10–15 Hz. Read `kAXRoleAttribute` and `kAXFrameAttribute` (or `kAXPosition`/`kAXSize`), ignore results owned by your own pid (overlays), and cache by window.
9. **[Voice] Wrap Foundation Models defensively.** Use `if #available(macOS 26, *)`, and check `SystemLanguageModel.default.availability` for `.appleIntelligenceNotEnabled`, `.deviceNotEligible` and `.modelNotReady`. Use one session per task, queued, and call `prewarm()`. Use `@Generable` structs to map commands to actions. Measure prompts with `tokenCount(for:)`, and when `exceededContextWindowSize` is thrown, start a new session seeded with a summary.
10. **[All] Adopt Liquid Glass behind a gate.** Use `.glassEffect(.regular, in: .capsule)` for HUD pills inside a `GlassEffectContainer`, falling back to `.ultraThinMaterial` before macOS 26. Keep click-through overlays plain: `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`. Glass over a constantly moving cursor halo costs GPU time for little visual gain.

## Pitfalls

- Center Stage, Portrait, Studio Light and Reactions can change between frames without any session change; re-check them with KVO.
- Running Vision on every frame at 60 fps causes jitter. Smooth the output with a One Euro filter instead of lowering the detection rate.
- A single slow app's AX calls on the main thread can stall the event tap and disable it; handle `tapDisabledByTimeout`.
- `@Generable` output and guardrails can still throw on harmless voice transcripts, so always keep a deterministic command-parser fallback.

## Sources

- https://developer.apple.com/videos/play/wwdc2024/10163/
- https://developer.apple.com/videos/play/wwdc2026/237/
- https://developer.apple.com/videos/play/wwdc2020/10653/
- https://www.createwithswift.com/detecting-hand-pose-with-the-vision-framework/
- https://developer.apple.com/videos/play/wwdc2021/10047/
- https://developer.apple.com/videos/play/wwdc2023/10105/
- https://developer.apple.com/forums/thread/718696
- https://developer.apple.com/forums/thread/763369
- https://github.com/obsproject/obs-studio/pull/11652
- https://github.com/AprilNEA/OpenLogi/pull/1157
- https://developer.apple.com/documentation/appkit/nsevent/1525439-momentumphase
- https://developer.apple.com/library/archive/technotes/tn2150/_index.html
- https://github.com/karinushka/paneru/pull/368
- https://github.com/vorssaint/vorssaint-utils/issues/938
- https://www.natashatherobot.com/p/apple-foundation-models
- https://developer.apple.com/forums/thread/788847
- https://infoq.com/news/2026/03/apple-foundation-models-context
- https://developer.apple.com/videos/play/wwdc2025/323/
- https://github.com/conorluddy/LiquidGlassReference
