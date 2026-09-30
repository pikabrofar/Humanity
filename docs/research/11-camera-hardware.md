# 11 — Camera hardware on Macs for eye and hand tracking

## TL;DR

- Built-in Mac cameras are either the 1080p FaceTime HD camera (notch MacBooks from 2021 to 2023, M1–M3 iMac/Air) or the newer 12 MP Center Stage camera (M4 MacBook Pro/iMac from late 2024, and later Airs). Studio Display has a 12 MP f/2.4 ultra-wide camera with a 122° field of view. All of them are optimized for video calls, not for eye tracking.
- Continuity Camera (iPhone to Mac, macOS 13+) gives the Mac app a normal `AVCaptureDevice` for the iPhone's **rear** camera at up to 1920×1080 or 1920×1440, **at 60 fps**. Desk View is a separate device at 1920×1440 and 30 fps. **Depth and TrueDepth data do not reach a native macOS app** *(high confidence, but not confirmed from the docs page)*.
- Center Stage and Desk View both crop and warp an ultra-wide sensor. That changes the effective focal length and the pixels per eye over time, which breaks gaze calibration. Center Stage must be off for gaze.
- Use a dedicated 60 fps USB webcam placed below or on top of the display for eyes. For hands, the built-in camera is fine, and Desk View or an angled second camera works well.
- Exposure and focus locking works on some built-in cameras, but it usually **isn't supported on UVC (USB) webcams through AVFoundation**. Always check `is…Supported` first.

## Key findings

- **Continuity Camera formats** (WWDC22 session 10018): 640×480, 1280×720 and 1920×1080 at 30 or 60 fps, plus 1920×1440 (4:3) at 30 or 60 fps. Desk View is 1920×1440 at 30 fps (`420v`). Photos go up to 12 MP. It connects wired or wirelessly, and both devices need the same Apple ID. The outputs are video data, metadata (`.face`, `.humanBody`), photo and movie. No depth output is listed.
- **Depth**: `AVCaptureDepthDataOutput` is an iOS/Mac Catalyst API. `AVDepthData` exists on macOS as a data type, but no Mac capture device produces it live *(unverified: the docs availability list couldn't be fetched)*. Continuity Camera also uses the rear camera, not the front TrueDepth camera, so it can't do Face ID-style IR depth. To get depth from an iPhone, oculOS would need its own companion iOS app that streams ARKit or TrueDepth data over the network.
- **Device types**: in macOS 14 `.externalUnknown` became `.external`, and `.continuityCamera` was added. Sonoma logs a deprecation warning if Continuity cameras are found through `.external`, unless the Info.plist sets `NSCameraUseContinuityCameraDeviceType = YES` and you ask for `.continuityCamera`. `.deskViewCamera` or `device.companionDeskViewCamera` gives the Desk View feed. `AVCaptureDevice.systemPreferredCamera` (KVO-observable) and `userPreferredCamera` handle automatic switching.
- **Built-in frame rate**: FaceTime HD cameras usually offer 30 fps at most *(unverified; enumerate `activeFormat.videoSupportedFrameRateRanges` to check)*. Saccades and blinks show up much better at 60 fps. Many cheap USB webcams (for example Logitech C922/Brio at 720p) and all Continuity Cameras reach 60 fps.
- **IR cameras**: Windows Hello-style IR webcams generally expose only the RGB stream to macOS, because the IR stream needs vendor or Windows-specific drivers *(unverified)*. Don't plan for IR on the Mac.
- **Exposure/focus**: `lockForConfiguration()` then `exposureMode = .locked` works on some FaceTime cameras (see the lockFacetimeAutoExposure project). On UVC cameras, `isExposureModeSupported` returns false for every mode. Controlling those would need raw UVC control transfers through IOKit, or a helper like the open-source `uvc-util` tool.

## How to program it

```swift
// Info.plist: NSCameraUsageDescription, NSCameraUseContinuityCameraDeviceType = YES
let discovery = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera],
    mediaType: .video, position: .unspecified)

func bestGazeFormat(_ d: AVCaptureDevice) -> AVCaptureDevice.Format? {
    d.formats.filter { f in
        let dims = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
        return dims.height >= 720 && f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
    }.max { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <
            CMVideoFormatDescriptionGetDimensions($1.formatDescription).width }
}

func configure(_ d: AVCaptureDevice) throws {
    try d.lockForConfiguration(); defer { d.unlockForConfiguration() }
    if let f = bestGazeFormat(d) {
        d.activeFormat = f
        d.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
    }
    if d.isFocusModeSupported(.locked) { d.focusMode = .locked }            // after AF settles
    if d.isExposureModeSupported(.locked) { d.exposureMode = .locked }      // after calibration lighting
    if d.isWhiteBalanceModeSupported(.locked) { d.whiteBalanceMode = .locked }
}
// Center Stage is a system/user control on macOS; you can only request it:
AVCaptureDevice.centerStageControlMode = .cooperative
AVCaptureDevice.isCenterStageEnabled = false
```

## Recommendations for oculOS

1. **Camera picker with capability badges.** For each device, show the maximum fps, the resolution, and whether exposure lock is supported. Recommend 60 fps devices for VisionGaze.
2. **Kill the system effects before calibrating.** Turn off Center Stage (as above) and warn about Portrait, Studio Light and Reactions. They are user-controlled in Control Center, so read `AVCaptureDevice.isCenterStageActive` / `isPortraitEffectActive` and alert the user if they're on.
3. **Invalidate calibration when the camera changes.** Key the saved calibration on `uniqueID`, the format, and whether Center Stage is active.
4. **Placement guidance.** For eyes, put the camera centered on the display at eye level, 50–70 cm away. A camera below the display sees more of the iris under the upper eyelid *(unverified heuristic)*. For hands, use the built-in camera looking down, or Desk View, so hands resting on the desk don't need to be raised (less "gorilla arm" fatigue).
5. **Support Continuity Camera as a premium input** (60 fps, a good sensor). Handle disconnects through `AVCaptureDevice.wasDisconnectedNotification` and `systemPreferredCamera` KVO.
6. **Lock exposure and white balance after the calibration lighting settles.** Re-enable auto mode if the average face luminance drifts a lot.

## Pitfalls

- A 122° ultra-wide camera (Studio Display, and 12 MP Center Stage cameras when not cropped) gives far fewer pixels per iris at desk distance than a narrow 1080p lens. Wide field of view hurts gaze.
- Continuity Camera sets itself as the default automatically when an iPhone is mounted, which can silently swap the camera mid-session.
- Desk View's image is perspective-corrected and synthetic, so hand-pose depth estimates from it are distorted.
- USB hubs and low light can cut fps (auto exposure lengthens the frame duration). Check the real delivered fps, not just the configured value.
- The `.external` deprecation warning floods the logs if the Info.plist key is missing.

## Sources

- https://developer.apple.com/videos/play/wwdc2022/10018/ (Continuity Camera formats, Desk View, APIs)
- https://github.com/electron/electron/issues/41853 (`.external` deprecation, Info.plist key)
- https://www.apple.com/macbook-pro/specs/ and https://www.macrumors.com/2024/10/30/new-macbook-pro-and-imac-center-stage-support/ (12 MP Center Stage)
- https://www.macrumors.com/roundup/studio-display/ (12 MP, 122° ultra-wide)
- https://developer.apple.com/videos/play/wwdc2022/110429/ (depth is iOS-side)
- https://github.com/SableRaf/lockFacetimeAutoExposure (FaceTime exposure lock)
- https://developer.apple.com/forums/thread/740341 and https://copyprogramming.com/howto/avcapturedevice-exposuremode-not-supported (UVC exposure unsupported)
