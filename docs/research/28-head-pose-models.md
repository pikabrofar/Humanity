# 28 — Learned and model-based 6-DoF head pose

Scope: CNN head pose regressors (6DRepNet, HopeNet, FSA-Net), joint detection-and-pose models (img2pose), 3D morphable model fitting (3DDFA_V2, FLAME), MediaPipe's facial transformation matrix, and how they compare with Apple Vision's `VNFaceObservation` yaw/pitch/roll for VisionGaze. This report adds to report 04, which recommended PnP.

## TL;DR

- On AFLW2000, the best learned regressors reach about **3.9–4° MAE**; with in-domain training on BIWI they reach **2.7°** (6DRepNet, MIT). That is still too coarse to use as a gaze input directly. Treat head pose as a slow, smooth prior and let calibration absorb the bias.
- The learned regressors (6DRepNet, HopeNet, FSA-Net) output **rotation only**. For metric translation you still need landmarks + PnP, or an iris/face-size prior. 6-DoF sources are MediaPipe's transformation matrix, 3DMM fitting, and img2pose.
- For oculOS, the simplest path to full 6-DoF: Vision 2D landmarks → PnP against a fixed canonical 3D face (report 04). If that jitters, add **6DRepNet on Core ML** as a rotation cross-check.
- Treat Apple Vision's yaw/pitch/roll as **coarse**. Apple publishes no accuracy figure. Older revisions were reportedly quantized *(unverified)*. Rev 3 (macOS 12+) adds pitch and appears continuous *(unverified: test it on a turntable)*.
- License traps: **img2pose (non-commercial, *likely CC BY-NC*)**, the **FLAME/DECA model licenses (non-commercial)**, and the **300W-LP / BIWI training data (research use)**. Weights trained on those datasets may carry restrictions even when the code is MIT.

## Key findings

| Model | AFLW2000 MAE (°) | BIWI MAE (°) | Output | Size (approx.) | Code license |
|---|---|---|---|---|---|
| 6DRepNet (RepVGG-B1g2) | 3.97 (Y3.63 P4.91 R3.37) | 2.66 (70/30 split); ~3.5 trained on 300W-LP *(?)* | R only | ~40M params *(?)* | MIT |
| img2pose (Faster R-CNN) | 3.91 (Y3.43 P5.03 R3.28) | ~3.8 *(?)* | R + t (6-DoF), plus a detector | large, 41 fps on GPU at 400² | Non-commercial *(?, check the repo)* |
| FSA-Net | 5.07 | ~4.0 *(?)* | R only | ~1–5 MB *(?)* | Apache-2.0 *(?)* |
| HopeNet (ResNet-50) | 6.16 | ~4.9 *(?)* | R only | ~95 MB fp32 | Apache-2.0 *(?)* |
| 3DDFA (v1) | 7.39 | — | 3DMM + pose | — | MIT |
| 3DDFA_V2 (MobileNet) | ~8.8 in one comparison *(protocol unclear)* | — | 3DMM + R + t (weak perspective) | ~3 MB, very fast on CPU | MIT |
| MediaPipe Face Landmarker | not officially benchmarked | — | 4×4 matrix [R\|t] from canonical face | ~3–4 MB | Apache-2.0 |
| FLAME fitting (DECA/EMOCA etc.) | varies | — | full 3D head + pose | — | non-commercial model license |
| Apple Vision rev 3 | not published | — | yaw/pitch/roll (no t) | built-in | system |

Notes:
- The numbers in the table use the standard protocol: train on 300W-LP, then test on AFLW2000 with |yaw| < 99°.
- BIWI is Kinect footage of 20 subjects, which is the closest match to a desk webcam.
- 3DDFA_V2 fits a 3DMM with weak perspective, so its translation is scale plus a 2D offset, not metric Z.

## How to program it (Core ML outline)

1. **Export.** Load 6DRepNet with `deploy=True`, run `convert.py` (RepVGG re-parameterization), trace with `torch.jit.trace` on a 1×3×224×224 input, then convert with `coremltools.convert(..., convert_to="mlprogram", compute_precision=FLOAT16)`. The output is a 3×3 rotation matrix built from the 6D representation by Gram–Schmidt. Keep that step inside the graph or re-implement it in Swift.
2. **Crop.** Take the `VNDetectFaceRectanglesRequest` box, expand it about 1.2× (match the crop used in training), make it square, resize to 224, and apply ImageNet normalization. The same crop policy as training is critical.
3. **Infer.** Use `VNCoreMLRequest` on the same `VNImageRequestHandler` as the face request (report 02). Budget about 2–5 ms on the ANE *(unverified)*.
4. **Convert the frame.** Datasets define the head frame differently. Convert to the oculOS camera frame once, and verify the signs with slow deliberate turns.
5. **Translation.** Solve PnP (report 04) from Vision's 76 landmarks against a canonical mesh, with intrinsics from the camera's FOV. Alternatively, Z ≈ f·11.7 mm / iris_px (report 03). Optionally fuse the rotation from PnP and the CNN with a small Kalman or One Euro filter (report 05).

## Recommendations for oculOS

- **Now:** keep the Vision yaw/pitch/roll as a fallback. Add landmark PnP as the primary 6-DoF source, since it needs no extra model or license.
- **Next:** ship 6DRepNet (MIT code) as an optional Core ML model to stabilize rotation at large yaw, where landmark PnP degrades. Record the training-data provenance of the weights in the model card, because 300W-LP is research-only. Retraining on a permissive or synthetic set is the clean option.
- Avoid img2pose and FLAME-based fitting in an MIT app because of their licenses. 3DDFA_V2 (MIT) is the best permissive 3DMM option if dense geometry is ever needed.
- MediaPipe's transformation matrix is Apache-2.0 and gives 6-DoF directly. It is worth it only if oculOS already adopts a MediaPipe Core ML port for hands or irises (report 06).

## Pitfalls

- An MAE of about 4° means head-pose error alone can shift gaze by tens of pixels at 60 cm. Calibrate the residual; don't trust the absolute value.
- Dataset angles are Euler angles in varying orders. Convert to rotation matrices, and avoid gimbal lock near 90° yaw.
- CNN regressors are trained on single frames and jitter between frames, so they need temporal filtering.
- Distance from face-box size breaks under yaw and under box-scale changes between Vision revisions. Prefer iris-based or PnP Z.
- Vision's `VNFaceObservation` angle precision and quantization are undocumented. Pin `revision` explicitly and log the values to check for step changes *(unverified whether rev 3 is continuous)*.

## Sources

- https://github.com/thohemp/6DRepNet (MIT, AFLW2000/BIWI MAE)
- https://arxiv.org/pdf/2202.12555 (6DRepNet paper)
- https://openaccess.thecvf.com/content/CVPR2021/papers/Albiero_img2pose_Face_Alignment_and_Detection_via_6DoF_Face_Pose_Estimation_CVPR_2021_paper.pdf (img2pose, comparison table with HopeNet/FSA-Net/3DDFA, 41 fps)
- https://github.com/jspsych/saccadejs/pull/7 (head pose from MediaPipe's transformation matrix)
- https://developers.google.com/mediapipe/solutions/vision/face_landmarker
- https://developer.apple.com/documentation/vision/vnfaceobservation/init(requestrevision:boundingbox:roll:yaw:pitch:)
- https://github.com/PINTO0309/DMHead (fused head pose models, ONNX)
- Licenses for HopeNet, FSA-Net, img2pose, 3DDFA_V2 and FLAME, and the 3DDFA_V2 MAE, come from memory or search summaries and are marked *(?)*.
