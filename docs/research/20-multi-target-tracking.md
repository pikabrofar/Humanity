# 20 — Multi-target tracking: which face and which hand is the user?

## TL;DR

- Choose the **primary user** once, using a score of size, centrality and frontal pose, then keep them by **track continuity** (IoU with the last box). Don't re-pick the largest face on every frame.
- Use `VNTrackObjectRequest` on a `VNSequenceRequestHandler` to follow the face between full detections. Re-detect every N frames, or when tracker confidence drops below about 0.3.
- Feed the tracked box to `VNDetectFaceLandmarksRequest.inputFaceObservations` so landmarks skip detection. Set `regionOfInterest` on the hand request to a crop around the user.
- Link hands to the user by **geometry**: the body-pose wrist-to-shoulder chain, or hand scale and position relative to the user's face. Then filter by `chirality` for the controller hand.
- When a hand covers the eye region, mark gaze **invalid and hold** it. Don't feed it to the filter or the calibration.

## Key findings

- Apple's "Tracking the User's Face in Real Time" sample detects faces with `VNDetectFaceRectanglesRequest`. It then turns each observation into `VNTrackObjectRequest(detectedObjectObservation:)` and runs it on a `VNSequenceRequestHandler`. Each result goes back into `inputObservation` only while `confidence > 0.3`. Otherwise it sets `isLastFrame = true` and detects again.
- `VNTrackObjectRequest.trackingLevel` can be `.fast` or `.accurate`. Vision limits how many trackers can run at once and throws a "too many trackers" error. *(Limit around 16, unverified.)* Always end dead trackers with `isLastFrame`.
- `VNFaceObservation` has `roll` and `yaw` (with `pitch` on newer revisions). `VNDetectFaceCaptureQualityRequest` gives `faceCaptureQuality` from 0 to 1. Both are useful for scoring "the person facing the screen".
- `VNGenerateImageFeaturePrintRequest` plus `computeDistance(_:to:)` gives a **general image embedding, not a face-recognition model**. Using it for identity on face crops is only a weak cue. *(Accuracy for faces is unverified.)* Use it to re-acquire the enrolled user after a loss, with a lenient threshold. Never use it for security.
- `VNDetectHumanHandPoseRequest` detects 2 hands by default (`maximumHandCount`). Observations carry `chirality` (macOS 12+). Chirality is per-frame and can flip, so it needs smoothing *(community reports)*.
- Every `VNImageBasedRequest` has a normalized `regionOfInterest`. A smaller ROI means fewer pixels to process and fewer bystanders to reject.

## How to program it

```swift
import Vision

final class PrimaryUserTracker {
    private let seq = VNSequenceRequestHandler()
    private var track: VNTrackObjectRequest?
    private var lastBox: CGRect?
    private var framesSinceDetect = 0
    var enrolledPrint: VNFeaturePrintObservation?   // optional re-ID cue

    func score(_ f: VNFaceObservation) -> Double {
        let b = f.boundingBox
        let area = Double(b.width * b.height)
        let dx = Double(b.midX - 0.5), dy = Double(b.midY - 0.5)
        let central = 1 - min(1, (dx*dx + dy*dy).squareRoot() / 0.7)
        let frontal = 1 - min(1, abs(f.yaw?.doubleValue ?? 0) / 0.8)
        var s = 3*area + 1*central + 0.5*frontal
        if let last = lastBox { s += 4 * iou(b, last) }       // hysteresis: stay with current user
        return s
    }

    func update(_ pb: CVPixelBuffer) throws -> VNFaceObservation? {
        framesSinceDetect += 1
        if let t = track, framesSinceDetect < 15 {
            try seq.perform([t], on: pb, orientation: .up)
            if let o = t.results?.first as? VNDetectedObjectObservation, o.confidence > 0.3 {
                t.inputObservation = o; lastBox = o.boundingBox
                return VNFaceObservation(boundingBox: o.boundingBox)   // feed to landmarks
            }
            t.isLastFrame = true; track = nil
        }
        // Full detection (periodic or after loss)
        let det = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up).perform([det])
        guard let best = det.results?.max(by: { score($0) < score($1) }) else {
            lastBox = nil; return nil                          // track lost
        }
        framesSinceDetect = 0; lastBox = best.boundingBox
        let t = VNTrackObjectRequest(detectedObjectObservation: best)
        t.trackingLevel = .fast; track = t
        return best
    }
}

// Landmarks without re-detecting:
// let lm = VNDetectFaceLandmarksRequest(); lm.inputFaceObservations = [face]

// Hand belongs to user if its size and position are plausible relative to the face.
func isUsersHand(_ h: VNHumanHandPoseObservation, face: CGRect) -> Bool {
    guard let w = try? h.recognizedPoint(.wrist), w.confidence > 0.3,
          let m = try? h.recognizedPoint(.middleMCP), m.confidence > 0.3 else { return false }
    let handLen = hypot(w.location.x - m.location.x, w.location.y - m.location.y)
    let ratio = handLen / face.height                     // bystander hands are much smaller
    let lateral = abs(w.location.x - face.midX) / face.width
    return (0.25...1.2).contains(ratio) && lateral < 3.0   // tune thresholds on real data
}
```

`iou` is a standard intersection-over-union helper (not shown).

## Recommendations for oculOS

1. **Share one `PrimaryUserTracker`** between VisionGaze and the hand app, so both agree on who the user is.
2. **Pick the primary user explicitly** at calibration (the face that completed calibration). Store its box and an optional feature print. After a loss longer than about 1 s, prefer candidates that match the stored print and sit near the last box.
3. **Build a hand-association ladder**:
   - If `VNDetectHumanBodyPoseRequest` finds a body whose nose or neck lies inside the user's face box, take that body's wrists and match them to hand observations by distance.
   - Otherwise fall back to the scale and position test above.
   - Choose the controller hand by a user setting (right or left), based on majority-voted `chirality` over about 10 frames.
4. **Crop to the user**: after the first detection, set the hand request's `regionOfInterest` to about 3× the face width and down to the bottom of the frame. This can cut work and bystander hits. *(Speed-up size unmeasured.)*
5. **Gate gaze on occlusion**: if any hand joint with confidence > 0.3 falls inside the expanded eye region, or eye-landmark confidence drops, set `gazeValid = false`. Hold the last fixation, pause the drift/auto-calibration update, and show a small indicator.
6. **Add a lost-track policy**: freeze the cursor and suspend clicks while the face is lost. Re-acquire only after 3 stable frames, so the app doesn't jump to a bystander.

## Pitfalls

- Choosing the largest face on every frame lets someone leaning in behind the user take over control. Always add a hysteresis bonus for the current track.
- The tracker can drift onto the background after fast motion while still reporting fairly high confidence. Periodic re-detection (every 10–20 frames) is required, not optional.
- Vision boxes use normalized coordinates with a bottom-left origin, and mirrored preview and camera orientation are handled differently. Use one convention across all requests.
- Chirality can be wrong on mirrored input *(uncertain)*. Check it with the mirrored FaceTime-style feed.
- Feature-print distances depend on lighting and pose. Don't hard-code a threshold. Calibrate it per user at enrollment.
- A hand raised to the face (chin rest, glasses adjustment) can pass the hand-association test and look like a gesture. Require the clutch gesture (report 07).

## Sources

- https://github.com/yamazaki8934/VisionFaceTrack (mirror of Apple's "Tracking the User's Face in Real Time" sample)
- https://medium.com/@ios_guru/tracking-objects-in-video-using-the-vntrackobjectrequest-46aa528acced
- https://nilotic.github.io/2018/08/20/Object-Tracking-in-Vision.html
- https://medium.com/@kamil.tustanowski/comparing-images-using-the-vision-framework-ff13291901ff
- https://medium.com/@sarimk80/vngenerateimagefeatureprintrequest-a-powerful-tool-for-image-comparison-5a406c0db78a
- https://developer.apple.com/videos/play/wwdc2020/10653/ (Detect Body and Hand Pose with Vision)
- https://www.kodeco.com/29023965-vision-tutorial-for-ios-what-s-new-with-face-detection/page/3
- https://github.com/xybp888/iOS-SDKs/blob/master/iPhoneOS13.0.sdk/System/Library/Frameworks/Vision.framework/Headers/VNDetectFaceCaptureQualityRequest.h
