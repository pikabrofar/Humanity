# 23 — Real-time camera pipelines under Swift 6 strict concurrency

## TL;DR

- Keep the AVFoundation serial delegate queue. Make the processing actor run *on that queue* with a custom executor (SE-0392, `DispatchSerialQueue` as `SerialExecutor`, macOS 14+). The delegate can then enter actor isolation with `assumeIsolated`, with no hop and no `Sendable` boundary for the `CVPixelBuffer`.
- If you need a separate consumer, bridge with `AsyncStream(bufferingPolicy: .bufferingNewest(1))`. That way at most one frame waits while one is being processed. Never start a `Task {}` per frame.
- `CVPixelBuffer` is not `Sendable`. Wrap it in a small `@unchecked Sendable` struct only at the single hand-off point, and pass only `Sendable` results (such as joint positions) downstream.
- Don't hop to `@MainActor` for every frame. Publish the latest result into a lock-protected slot and let an `NSView.displayLink(target:selector:)` (macOS 14) pull it at display rate.

## Key findings

- **The consensus pattern** (Swift Forums, MVP Factory, Fatbobman): do Vision/Core ML inference on the capture queue or in its isolation domain, and send only `Sendable` values to other actors. AVFoundation runs on GCD, so the delegate must be `nonisolated` and imported with `@preconcurrency`.
- **Custom executors**: an actor can return `queue.asUnownedSerialExecutor()` from `unownedExecutor`. Code running on that queue (the delegate callback) can then call `actor.assumeIsolated { ... }`, which checks at runtime that it's on the right executor. This is the lowest-latency Swift 6-clean design.
- **Backpressure**: `alwaysDiscardsLateVideoFrames = true` (already set in `CameraCapture`) drops frames only while the delegate is blocked. If you hold buffers past the callback, you drain the output's fixed `CVPixelBufferPool`, and capture stalls or drops. `.bufferingNewest(1)` limits you to one queued buffer plus one being processed. *(Pool size is about 4–6 buffers; unverified.)*
- **`sending` (SE-0430)**: in Swift 6, `AsyncStream.Continuation.yield` takes a `sending` value, so a freshly produced non-`Sendable` value can be transferred if the compiler can prove it's disconnected. *(Unverified. A `CVPixelBuffer` taken from a `CMSampleBuffer` usually can't be proven disconnected, so expect to need a wrapper anyway.)*
- **Display rate**: macOS 14 deprecates `CVDisplayLink` in favor of `NSView`/`NSWindow`/`NSScreen.displayLink(target:selector:)`. It returns a `CADisplayLink` that follows the view's screen and pauses when the view is off-screen.
- **Priority**: Swift actors escalate priority when higher-priority work is queued behind them. `DispatchSemaphore.wait()` or `DispatchQueue.main.sync` inside async code hides the dependency from the runtime and can cause priority inversion or deadlock on the cooperative pool.

## How to program it

```swift
@preconcurrency import AVFoundation
import Vision
import os

struct Frame: @unchecked Sendable { let buffer: CVPixelBuffer; let time: TimeInterval } // hand-off only
struct HandResult: Sendable { let tip: CGPoint?; let time: TimeInterval }

actor HandProcessor {
    let queue = DispatchSerialQueue(label: "oculOS.hand", qos: .userInteractive)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private let request = VNDetectHumanHandPoseRequest()        // non-Sendable, actor-owned
    let latest = OSAllocatedUnfairLock<HandResult?>(initialState: nil)

    func process(_ f: Frame) {
        let h = VNImageRequestHandler(cvPixelBuffer: f.buffer, orientation: .up)
        try? h.perform([request])
        let tip = try? request.results?.first?.recognizedPoint(.indexTip).location
        latest.withLock { $0 = HandResult(tip: tip, time: f.time) }
    }
}

// Option A (preferred): the capture delegate queue IS the actor queue.
//   output.setSampleBufferDelegate(self, queue: processor.queue)
//   nonisolated func captureOutput(...) { processor.assumeIsolated { $0.process(frame) } }

// Option B: a separate consumer via AsyncStream.
let (frames, cont) = AsyncStream.makeStream(of: Frame.self, bufferingPolicy: .bufferingNewest(1))
camera.onFrame = { buf, t in cont.yield(Frame(buffer: buf, time: t)) }   // capture queue
let pump = Task(priority: .userInitiated) { for await f in frames { await processor.process(f) } }

@MainActor final class OverlayView: NSView {
    var processor: HandProcessor!
    private var link: CADisplayLink?
    override func viewDidMoveToWindow() {
        link?.invalidate()
        link = displayLink(target: self, selector: #selector(tick)); link?.add(to: .main, forMode: .common)
    }
    @objc private func tick(_ l: CADisplayLink) {
        guard let r = processor.latest.withLock({ $0 }) else { return }
        // draw r.tip; no per-frame Task hop
    }
}
```

*(Snippet not compiled. The `recognizedPoint` optional chaining and the `latest` lock living inside an actor are sketches.)*

## Recommendations for oculOS

1. Move the packages to `swift-tools-version: 6.0` with Swift 6 language mode, one package at a time. Start GazeKit's frame path with `StrictConcurrency=complete` warnings.
2. Change `CameraCapture.onFrame` to `(@Sendable (Frame) -> Void)`, set only before `start()`, or let callers supply their own delegate queue so Option A works. The current `@unchecked Sendable` class with a mutable `var onFrame` can race if it's set while the camera is running.
3. Share one capture queue and processor actor between gaze and hand requests: one `VNImageRequestHandler` per frame (see report 02).
4. Use a Mutex slot plus the display link for overlay and cursor. Post `CGEvent`s from the processing queue, not from the MainActor.

## Pitfalls

- `Task { await ... }` per frame: tasks run out of order, pile up without limit, and hold on to pool buffers.
- Swift 6.2's `defaultIsolation(MainActor.self)` (the approachable-concurrency setting) silently puts delegate classes on the MainActor. Mark capture and processing types `nonisolated`, or keep them in a non-UI module.
- `session.startRunning()` blocks. Call it on the capture queue, not the MainActor.
- `assumeIsolated` crashes if called off the executor. Wire the delegate queue and actor queue from a single source.
- Cleaning up the display link in `deinit` under Swift 6 trips isolation errors. Invalidate it in `viewDidMoveToWindow` or `removeFromSuperview` instead.
- `OSAllocatedUnfairLock` works on macOS 13+. `Synchronization.Mutex` needs macOS 15. *(availability from memory)*

## Sources

- https://forums.swift.org/t/safely-use-avcapturesession-swift-6-2-concurrency/83622 (search summary only; fetch blocked)
- https://forums.swift.org/t/avfoundation-swift-6/74229 (search summary only)
- https://fatbobman.com/en/posts/swift6-refactoring-in-a-camera-app/ (search summary only; fetch blocked)
- https://mvpfactory.io/blog/wiring-apple-s-vision-framework-to-core-ml-for-real-time-on-device-object
- https://philz.blog/in-process-animations-and-transitions-with-cadisplaylink-done-right/
- https://github.com/initor/ghostty-screensaver/pull/28
- https://www.donnywals.com/understanding-swift-concurrencys-asyncstream/
- https://blog.jacobstechtavern.com/p/async-stream
- SE-0392 (custom actor executors), SE-0430 (`sending`): from memory, not fetched
