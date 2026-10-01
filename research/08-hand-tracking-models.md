# Hand-Tracking Model Options for ManOS on macOS

## Summary

Apple Vision's `VNDetectHumanHandPoseRequest` should stay as ManOS's default. It ships with the OS, runs on the Apple Neural Engine, adds no dependencies, and handles a webcam facing the user, which is ManOS's case. Its weak spots are well documented and line up with how a mouse replacement gets used: hands seen edge-on, hands at the frame edge, gloves, low light, and no depth. MediaPipe HandLandmarker is the best second engine. It adds relative z, metric "world" landmarks and a handedness score, and it builds in a detect-once-then-track loop. On macOS, though, it is awkward to integrate natively. Heavy 3D mesh models such as WiLoR and HaMeR are too slow for a background mouse driver at 30 fps. Most gains will come from pipeline tricks (ROI cropping, cutting `maximumHandCount`, temporal filtering, ManOS's own chirality logic) rather than from changing the model.

## Key findings

- **Vision failure modes (from Apple, WWDC20):** these are Apple's own caveats. Hands near the frame edges are "not guaranteed to work well". Hands parallel to the viewing direction (a "karate chop" side view) are hard. Gloves cause trouble. Feet are sometimes detected as hands. When part of the hand is hidden, Vision still guesses positions for the hidden joints, so occluded points are filled in rather than dropped. Third-party write-ups report that accuracy "is reduced a lot" in poor light.
- **Vision performance controls:** `maximumHandCount` defaults to 2. Hands beyond that limit get no pose computed, so setting it to 1 saves time directly. Apple's sample code drops joints with confidence ≤ 0.3. Apple also suggests pairing hand pose with a tracking request (`VNTrackObjectRequest`) to keep hand identity stable through occlusion.
- **Vision chirality:** `.chirality` (left/right/unknown) was added later and is predicted separately for each hand. Apple publishes no accuracy figure for it. Mirroring the front-camera image flips the meaning of the label, so ManOS must decide whether to mirror before running inference and stay consistent.
- **MediaPipe HandLandmarker:** two stages. A palm detector (BlazePalm) finds the hand, then a 21-landmark regressor runs on a 192–224 px crop. In video mode it skips palm detection while tracking holds, and re-runs it only when hand presence drops below 0.5 (the default). It outputs 2D landmarks, z relative to the wrist, world landmarks in meters, and a handedness label. Latency is 17.1 ms on CPU and 12.3 ms on GPU (Pixel 6). The original paper reports the Full model at 1.98M parameters and 5.3 ms on an iPhone 11. It was trained on about 30K real images plus synthetic renders. Default `num_hands` is 1.
- **MediaPipe on macOS:** Tasks for iOS ship only through CocoaPods. Swift Package Manager support is unofficial and recently broke App Store uploads (issue #6367). Mac Catalyst builds skip the native pods. The Python package runs on macOS. For a native Mac app, a realistic route is to convert the TFLite landmark model to Core ML (community ports exist, e.g. vidursatija/BlazePalm) and use Vision or a small detector to find the hand.
- **RTMPose (MMPose):** RTMPose-l reaches 67.0 AP on COCO-WholeBody at 130+ fps on GPU. RTMPose-s reaches 72.2 AP on COCO body at 70+ fps on a Snapdragon 865. Hand-only variants exist and export to ONNX, then to Core ML. The output is 2D only.
- **WiLoR (CVPR 2025):** its hand detector runs at 138–175 fps on an RTX 4090, is 7 MB, and is 45× faster than ContactHands. Its reconstruction stage is a ViT that produces a MANO mesh. That stage handles occlusion well but is heavy (Fast-HaMeR exists to distill this class of model). It is not practical as an always-on 30 fps mouse driver on a laptop, though the small detector alone could be useful.
- **Depth from one RGB camera:** monocular mesh methods recover depth and scale "only through learned priors", so metric accuracy is not guaranteed. The cheap, standard workaround is to estimate depth from the apparent length of a rigid bone segment, such as wrist to index MCP (the index-finger base knuckle), using Z ≈ f·L/ℓ, where f is the camera focal length, L the real bone length and ℓ its length in pixels.

## Recommendations (ranked)

1. **Keep Vision as the primary engine and tune it.** Set `maximumHandCount = 1` unless two-hand gestures are on. Drop joints with confidence < 0.3. Use `VNTrackObjectRequest` on the hand's bounding box between frames. Show an "edge / side-on / low light" warning when the average confidence falls.
2. **Crop to an ROI to raise fps and accuracy.** After the first detection, run hand pose on a crop around last frame's bounding box (expand it 1.5–2×) using `regionOfInterest`. Fall back to the full frame when confidence drops, the same detect-then-track approach MediaPipe uses. Consider dropping capture to 640×480 at 60 fps instead of 720p at 30 fps: cursor latency matters more than resolution.
3. **Make chirality ManOS's own job.** Lock each hand's identity by tracker ID plus a vote over about 10 frames of the model's chirality output, and apply mirroring before inference. Never flip a hand's identity mid-gesture.
4. **Add cheap pseudo-depth.** Track the pixel length of the wrist to index-MCP bone, calibrated once per user, to get push/pull and depth for clicks. Combine it with the pinch distance normalized by hand scale, so pinch thresholds don't change as the hand moves closer or farther.
5. **Add MediaPipe as an optional backend later, behind a `HandPoseProvider` protocol.** Use a Core ML conversion of the landmark model (seeded from Vision's bounding box) when a user wants z and world landmarks. Benchmark it against Vision on the same recorded clips (side views, low light) before making it a default.
6. **Skip WiLoR and HaMeR for live control.** Revisit WiLoR's 7 MB detector only if Vision's hand detection proves the bottleneck.

## Sources

- https://developer.apple.com/videos/play/wwdc2020/10653/
- https://developer.apple.com/videos/play/wwdc2021/10039/
- https://medium.com/@kamil.tustanowski/detecting-body-pose-hand-pose-and-face-landmarks-using-vision-framework-645dc62c4b93
- https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker
- https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/ios
- https://arxiv.org/pdf/2006.10214
- https://github.com/google-ai-edge/mediapipe/issues/6367
- https://github.com/google-ai-edge/mediapipe/issues/6167
- https://github.com/vidursatija/BlazePalm
- https://arxiv.org/abs/2303.07399
- https://arxiv.org/html/2409.12259
- https://arxiv.org/pdf/2603.16444
- https://arxiv.org/html/2609.24424
