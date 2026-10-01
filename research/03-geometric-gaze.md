# Geometric (Model-Based) Gaze from RGB Landmarks: Improving VisionGaze

## Summary

VisionGaze gets its head distance from face-box width (150 mm assumed, 72° FOV) and its gaze from where the pupil sits relative to the eye corners. Both are weak spots. Face-box width changes with yaw and from person to person, and nobody knows what the real FOV is. Pupil-relative-to-corners is a 2D proxy, not a 3D eye model. The published work points to three fixes: metric head pose from a 3D face model fitted with PnP, an eyeball center fixed in the head frame with per-user calibration (center offset plus kappa), and correct camera intrinsics. Expect about 4–7° from geometry alone with a webcam. Getting to about 3° needs calibration and a learned residual on top.

## Key findings

- **The iris is a better ruler than the face.** Horizontal iris diameter is 11.7 ± 0.5 mm (about 4%) across most people. MediaPipe Iris uses it to get metric depth with **4.3% mean relative error (SD 2.4%)** against the iPhone 11 depth sensor, tested on more than 200 participants (under 10% in general). It needs the focal length in pixels. A face-box width of "150 mm" carries much more variance: the box is not an anatomical width, and it shrinks roughly with cos(yaw).
- **The iris is small in pixels.** At 600 mm with a 1920 px frame and about 65° HFOV (f ≈ 1500 px), an iris is about 29 px across, so a 1 px error is about 3.4% depth error. That still beats the face-box method, but it needs subpixel iris boundaries. Vision's 76-point model gives only one pupil point per eye, not an iris contour.
- **FOV/intrinsics error turns straight into depth error.** With size-based depth, Z = f·W/w, while lateral position X = u·W/w does not depend on f. So a wrong FOV mostly scales depth. Assuming 72° when the true HFOV is 60° gives f off by tan36°/tan30° ≈ **1.26, i.e. 26% depth error**. Mixing up diagonal and horizontal FOV causes a similar error. Typical webcam HFOV is **50–70°**. Apple does not publish FOV for MacBook FaceTime cameras.
- **Angular error matters more than depth error.** 1° of gaze error is about 10.5 mm on screen at 600 mm, so 5° is about 52 mm. A 10% depth error (60 mm) moves the point of gaze by only about δz·tanθ ≈ 16 mm at θ = 15°.
- **Iris-center noise is the limiting factor.** The pupil moves on a sphere of radius ≈ 12 mm, so a 1 px (≈ 0.4 mm at 600 mm) iris-center error is about **2°**. Averaging both eyes cuts this by roughly √2.
- **Standard eyeball model:** eyeball radius ≈ 12 mm, center ≈ 12 mm behind the midpoint of the eye corners. The center stays fixed in the head frame and is refined by personal calibration. Gaze is the optical axis (center → iris center) plus a person-specific kappa offset to the visual axis.
- **Iris ellipse fitting is weak at webcam resolution.** EyeTab back-projected the limbus ellipse to a 3D circle and got **6.88°** at 12 fps on a tablet (8 participants). Use ellipse fitting to measure iris size (for depth), not as the main gaze cue.
- **3D face models:** MediaPipe's canonical face model and Procrustes geometry pipeline give a metric pose [R|t] directly, with landmarks weighted so expressions don't register as head motion.
- **Accuracy reference points:** EMC-Gaze (landmark-based, webcam, 9-point calibration) reaches **5.79 ± 1.81°** RMSE in interactive use and **2.92°** with a still head. WebEyeTrack (MediaPipe plus model-based head pose, 9-shot personalization) reaches **2.32 cm** on GazeCapture. Glint-based IR systems reach about 0.5–1.4°, which RGB geometry should not be expected to match.

## Recommendations (ranked)

1. **Replace face-box depth with PnP on a mean 3D face.** Map about 10 stable Vision landmarks (inner and outer eye corners, nose bridge and tip, mouth corners, chin) to matching vertices of the MediaPipe canonical face, then solve 6DoF pose with `solvePnP`-style Gauss-Newton or EPnP. You get yaw-robust metric translation and a head frame for the eye model. Keep the rev3 yaw/pitch only as a sanity check.
2. **Get the intrinsics right.** Read FOV from `AVCaptureDevice.Format.videoFieldOfView` where available (confirm it's supported on macOS; it may be iOS-only). Otherwise keep a per-model lookup table, or treat f as an unknown in the calibration solve. Write down whether "72°" means horizontal or diagonal FOV.
3. **Add an explicit eyeball-center model.** Initialize the center 12 mm behind the eye-corner midpoint in the head frame and back-project the 2D pupil onto a 12 mm sphere to get the 3D iris center. Gaze = normalize(iris − center), rotated by kappa (init 5° nasal, 1.5° up). During 9-point calibration, solve per-eye center offset (3 params), kappa (2 params) and optionally f with Levenberg-Marquardt.
4. **Use iris diameter for scale.** Fit a circle or ellipse to the limbus in the eye ROI using radial gradients (EyeTab-style), or run MediaPipe Iris through Core ML. Fuse its depth with the PnP depth in a Kalman filter. Distance from the iris is metric without assuming anything about face size.
5. **Reduce noise.** Average both eyes before intersecting with the screen (weight each by eye openness), refine the pupil to subpixel accuracy (intensity centroid in the ROI), and smooth with a One Euro filter.
6. **Hybrid residual.** After the geometric solve, fit a small ridge regression from (geometric point of gaze, head pose) to the screen-error residual using the calibration points. This is the step that takes landmark methods from about 5° to about 3°.

## Sources

- https://research.google/blog/mediapipe-iris-real-time-iris-tracking-depth-estimation/
- https://github.com/google/mediapipe/blob/master/docs/solutions/iris.md
- https://github.com/google-ai-edge/mediapipe/wiki/MediaPipe-Face-Mesh
- https://github.com/google/mediapipe/issues/1642
- https://www.cl.cam.ac.uk/research/rainbow/projects/eyetab/
- https://github.com/errollw/EyeTab
- https://arxiv.org/abs/2603.12388 (EMC-Gaze)
- https://arxiv.org/abs/2508.19544 (WebEyeTrack)
- https://arxiv.org/pdf/1708.01817 (consumer gaze review)
- https://openaccess.thecvf.com/content_ICCV_2017/papers/Wang_Real_Time_Eye_ICCV_2017_paper.pdf (3D deformable eye-face model)
- https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/KinectBasedEyeTracking.pdf
- https://learnopencv.com/approximate-focal-length-for-webcams-and-cell-phone-cameras/
- https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview
