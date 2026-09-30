# 22 — Energy, thermal and CPU cost of always-on camera tracking

## TL;DR

- **Cost comes mostly from how many frames you analyse and how large they are, not from the model.** Frame rate × pixels × requests per frame sets the energy bill. A tracker that is sitting idle should analyse 2–5 fps, not 30.
- **Govern at two levels.** Lower the camera's own frame rate (`activeVideoMinFrameDuration`) when idle or hot, and separately skip Vision work on frames you don't need.
- **Respond to `ProcessInfo.thermalState` and `isLowPowerModeEnabled`.** Step down at `.fair`, halve the rate at `.serious`, and pause tracking at `.critical`.
- **Measure before tuning.** Put `OSSignposter` intervals around capture→Vision→output. Then use Instruments (Time Profiler, Power Profiler / Energy Log, os_signpost) and `sudo powermetrics --samplers cpu_power,gpu_power,ane_power --show-process-energy`.
- **A useful benchmark from a similar app:** Headway, a Vision head-tracking menu-bar app, reports about 17–19% of one core on an M4 Air. It analyses every 2nd frame, every 3rd when the user is still, and turns the camera off after 5 minutes without input.

## Key findings

1. **Reference points from similar apps.** Headway (MIT, macOS, Vision-based) reports about 17–19% of one core on an M4 MacBook Air with frame decimation and idle shutdown [headway]. Posture apps such as Straighty offer "battery saver" interval checks from 30 s to 10 min instead of continuous capture [alternativeto]. No published battery numbers (Wh/h) for Vision-based webcam trackers were found *(gap: oculOS should publish its own)*.
2. **Which chip runs Vision (ANE, GPU or CPU) is not documented per request.** Vision chooses the compute unit internally. Third-party write-ups say it prefers the ANE on Apple Silicon *(unverified; blog summary)*. On macOS 26.1 / M3, a developer reports that `VNDetectFaceRectanglesRequest` logs "MLE5Engine is disabled through the configuration", which suggests that on macOS some face requests may **not** use the ANE [forum 807600] *(unanswered thread)*. Check with `powermetrics` ANE power instead of assuming. Your own Core ML models (for example a gaze CNN) can be pinned with `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine`.
3. **Thermal state is a public signal.** `ProcessInfo.thermalState` has four levels (`.nominal`, `.fair`, `.serious`, `.critical`) and fires `thermalStateDidChangeNotification` when it changes. Apple's macOS energy guide tells apps to cut work as the level rises [Apple power guide]. MacBook Airs have no fan, so sustained 1080p face and hand tracking can realistically reach `.fair`/`.serious` *(plausible, not measured)*.
4. **Frame drops are a feature.** If `alwaysDiscardsLateVideoFrames = true` and the delegate returns quickly, late frames are dropped instead of queuing up. TN2445 describes the drop reasons (`OutOfBuffers`, `FrameWasLate`) and recommends lowering `activeVideoMinFrameDuration` rather than dropping frames silently [TN2445].
5. **Tooling:**
   - **Instruments:** Time Profiler shows CPU hot spots such as `CVPixelBuffer` conversions and Vision. The Power Profiler / Energy template shows per-process energy impact. The os_signpost track shows your own intervals.
   - **powermetrics:** reports CPU, GPU and ANE milliwatts plus per-process energy. It must run as root [ss64].
   - **Activity Monitor:** its "Energy Impact" column is a quick sanity check but does not break energy down by component.

## How to program it

```swift
import AVFoundation
import os

final class FrameGovernor {
    enum Mode { case active, idle, hot, paused }
    private let signposter = OSSignposter(subsystem: "org.oculos.vision", category: .pointsOfInterest)
    private let device: AVCaptureDevice
    private var lastFaceSeen = Date()
    private var frameIndex = 0
    private(set) var mode: Mode = .active

    init(device: AVCaptureDevice) {
        self.device = device
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.reevaluate() }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                                               object: nil, queue: .main) { [weak self] _ in self?.reevaluate() }
    }

    /// Call on every frame; returns false to skip Vision for this frame.
    func shouldProcess() -> Bool {
        frameIndex &+= 1
        switch mode {
        case .active: return true
        case .hot:    return frameIndex % 2 == 0
        case .idle:   return frameIndex % 6 == 0   // ~5 fps at 30
        case .paused: return false
        }
    }

    func process(_ work: () -> Bool /* returns faceFound */) {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval("VisionFrame", id: id)
        let found = work()
        signposter.endInterval("VisionFrame", state, "face=\(found)")
        if found { lastFaceSeen = Date() }
        reevaluate()
    }

    private func reevaluate() {
        let pi = ProcessInfo.processInfo
        let newMode: Mode
        switch pi.thermalState {
        case .critical: newMode = .paused
        case .serious:  newMode = .hot
        default:
            if Date().timeIntervalSince(lastFaceSeen) > 3 { newMode = .idle }
            else if pi.isLowPowerModeEnabled || pi.thermalState == .fair { newMode = .hot }
            else { newMode = .active }
        }
        guard newMode != mode else { return }
        mode = newMode
        signposter.emitEvent("GovernorMode", "\(String(describing: newMode))")
        setCameraFPS(newMode == .active ? 30 : newMode == .paused ? 5 : 15)
    }

    private func setCameraFPS(_ fps: Int32) {
        // Only use rates inside device.activeFormat.videoSupportedFrameRateRanges.
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: fps)
        device.unlockForConfiguration()
    }
}
```

To measure a run, record the Time Profiler plus os_signpost templates in Instruments, or run `sudo powermetrics -i 1000 --samplers cpu_power,gpu_power,ane_power --show-process-energy` during a 10-minute scripted session.

## Recommendations for oculOS

- **Face-gated pipeline.** When no face is present, run only `VNDetectFaceRectanglesRequest` at about 5 fps. Once a face appears, add landmarks or the gaze CNN and hand pose. Run the iris refinement crop only when landmarks look confident.
- **Capture at 720p when gaze doesn't need 1080p.** Pass a region of interest (`regionOfInterest`) to Vision for the eye crops instead of running over the whole frame again. Keep 1080p as a "precision" toggle.
- **Share one `VNImageRequestHandler` per frame** across the face and hand requests (see report 02). Hand pose is the expensive request, so run it at half rate unless a gesture is in progress.
- **Stop the camera** (`session.stopRunning()`) after N minutes without HID input or when the screen locks or sleeps, as Headway does. This also turns off the green camera LED, which users read as "it's off".
- **App Nap.** An accessory/menu-bar app doing real-time work should hold `ProcessInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason:)` **only** while tracking is active, so the Mac can still sleep. Run capture and Vision on a `.userInitiated` queue, not `.userInteractive`.
- **Publish an energy budget in CI docs.** For example: "≤20% of one core, ≤1 W package delta on M1 Air at 30 fps active, ≤5% idle". Check it with a scripted powermetrics run.

## Pitfalls

- Setting a frame rate outside `videoSupportedFrameRateRanges` throws an Objective-C exception, which crashes the app.
- Changing the frame rate mid-session can briefly change exposure or the frame cadence. Filters and One-Euro timing must use presentation timestamps, not a fixed dt (see report 05).
- A Vision call that blocks the capture delegate turns into a backlog of frames instead of dropped frames if `alwaysDiscardsLateVideoFrames` is false.
- `thermalState` is coarse and lags. Don't flip modes on every frame; apply hysteresis (a dwell of at least 5 s or so).
- Activity Monitor's Energy Impact is relative and model-dependent. Use powermetrics or Instruments for numbers you publish.
- A `beginActivity` token that is never ended leaks: the system never naps the app and the Mac may not sleep.

## Sources

- [headway: IrakliDNL/headway (CPU %, frame decimation, idle camera-off)](https://github.com/IrakliDNL/headway)
- [Apple TN2445: Handling Frame Drops with AVCaptureVideoDataOutput](https://developer.apple.com/library/archive/technotes/tn2445/_index.html)
- [Apple Energy Efficiency Guide for Mac Apps: Respond to Thermal State Changes](https://developer.apple.com/library/mac/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/RespondToThermalStateChanges.html)
- [Apple Forums 807600: VNDetectFaceRectanglesRequest does not use the Neural Engine?](https://developer.apple.com/forums/thread/807600)
- [ss64: powermetrics](https://ss64.com/mac/powermetrics.html)
- [asitop (powermetrics-based ANE/GPU monitor)](https://github.com/TienTim/asitop)
- [Straighty battery saver (alternativeto)](https://alternativeto.net/software/straighty/about)
- [Blake Crosley: Apple Vision Framework (ANE preference claim, unverified)](https://blakecrosley.com/blog/vision-framework-built-in)
