# 01 — State of the art in webcam / appearance-based gaze estimation

*Research note for oculOS / VisionGaze. Compiled 2026-09-30. Items marked (?) are unverified or from memory.*

## TL;DR

- **Accuracy floor is ~4–7° cross-dataset without calibration**, even for 2025 foundation models (UniGaze-H trained on ETH-XGaze: 4.87° MPIIFaceGaze, 6.53° EYEDIAP, 11.19° Gaze360). A few calibration samples bring this to ~2.5–3.5°. VisionGaze's 2–4° calibrated geometric model is already in that range.
- **Personalization matters more than backbone choice.** Person-specific bias (kappa angle, eye shape) is 2–4° and is mostly removed by a per-user affine/linear correction on 9–30 samples (FAZE: 3.18° on GazeCapture with ≤9 samples).
- **Normalization (Zhang, Sugano, Bulling, ETRA 2018) is mandatory** for good CNN results: warp the face to a virtual camera at fixed distance with zero roll, and rotate (do not scale) the gaze label.
- **Licensing is the blocker.** Nearly all real datasets (MPIIGaze/MPIIFaceGaze, ETH-XGaze, Gaze360, GazeCapture) are non-commercial or research-only, and so are the weights trained on them. UniGaze weights use MG-NC-RAI-2.0 (non-commercial). L2CS-Net and MobileGaze *code* is MIT, but their weights are trained on Gaze360 or MPIIGaze.
- **Best Core ML candidates:** MobileOne-S0 or ResNet-18 L2CS-style (4.8–43 MB, <5 ms on ANE (?)) as a *feature/prior* fused with the geometric model. For a commercially clean path, train on synthetic data or opt-in user data.

## Key findings

**Model vs appearance.** Model/geometry-based methods (pupil/glint, 3D eyeball fit, or VisionGaze's pinhole+screen-plane model) generalize across head poses because they rest on physics. On webcams they are limited by landmark and pupil jitter. Appearance-based CNNs regress gaze directly from pixels, cope with low resolution and eyelids, and give a calibration-free prior, but they carry dataset bias and person bias. The practical SOTA combines the two: normalized appearance model, then per-user calibration, then a temporal filter.

**Key models and numbers (within-dataset unless noted):**

| Model | Year | Backbone / input | Reported error | Code / weights license |
|---|---|---|---|---|
| MPIIGaze GazeNet | 2015/17 | VGG, 60×36 eye | ~5.5° MPIIGaze (?) | research |
| FAZE | ICCV'19 | DT-ED + MAML, ≤9 calib samples | 3.18° GazeCapture; 7.17°→5.38° (k=0→32) for a MAML baseline | NVIDIA, NC (?) |
| ETH-XGaze baseline | ECCV'20 | ResNet-50, 224² normalized face | ~4.5° on XGaze test (?) | CC BY-NC-SA 4.0 data |
| L2CS-Net | 2022 | ResNet-50, 448², binned cls+reg per angle | 3.92° MPIIGaze, 10.41° Gaze360 | MIT code; weights trained on NC data |
| GazeTR-Hybrid | ICPR'22 | ResNet-18 + transformer encoder | ~4.0° MPIIFaceGaze (?) | research |
| MobileGaze (yakhyo) | 2024 | ResNet-18/34/50, MobileNetV2, MobileOne-S0 | 12.84 / 11.33 / 11.34 / 13.07 / 12.58° on Gaze360 (MAE) | MIT code; Gaze360-trained weights |
| UniGaze-B/L/H | WACV'26 | MAE-pretrained ViT on normalized faces | Cross-dataset (train XGaze): 4.87° M, 6.56° GC, 6.53° E, 11.19° G360 | MG-NC-RAI-2.0 |
| OmniGaze | 2025 | semi-supervised, reward-guided pseudo-labels | improved in-the-wild generalization (numbers not checked) | ? |

Gaze360 numbers (~10–13°) are much higher because the dataset covers 360° gaze and back-of-head views. They do not transfer to screen viewing. For a desktop user the relevant benchmarks are MPIIFaceGaze and EYEDIAP (screen target).

**Trend 2023–2026.** Large-scale self-supervised pretraining on normalized faces (UniGaze, ~120 h on 4×H100 for ViT-H) gives the best cross-domain generalization. Generic semantic SSL (DINO/CLIP-style) was reported to *hurt* gaze. Synthetic data with 3D eyeball labels (GazeGene, CVPR'25) and novel-view synthesis for head-pose augmentation are the other main lines. ViT-H is too heavy for real-time Mac use. ViT-B (~86M parameters) is feasible with fp16 at ~224² (?).

**Datasets and licenses:**
- MPIIGaze / MPIIFaceGaze: 15 subjects, laptop webcam, CC BY-NC-SA 4.0.
- ETH-XGaze: 110 subjects, 1M+ images, extreme head poses, CC BY-NC-SA 4.0 plus extra terms.
- Gaze360: 238 subjects, in the wild, research-only license agreement.
- GazeCapture: 1,450 subjects on iPhone/iPad, research only.
- EYEDIAP: RGB-D, research license (?).
- UnityEyes (synthetic) and GazeGene: the license varies by host. Check before use.

**Normalization (Zhang et al. 2018).** Build a rotation R so that the virtual camera looks at the face center (the eye midpoint or face center from 6 landmarks) with the head's x-axis horizontal. Then apply a scale S = diag(1, 1, d_n/d) so the face appears at a fixed distance d_n. Warp the image with W = C_n · S · R · C⁻¹. The key finding: rotate the gaze label by R only and do not apply S, which fixes the distortion in earlier scaled normalizations. ETH-XGaze code uses f_n = 960, d_n = 600 mm, and a 224×224 face. Eye patches use 60×36 (?).

**Personalization.** In order of complexity:
1. Per-user affine bias on yaw/pitch (2–6 parameters, least squares on calibration points). This captures most of the gain.
2. Fine-tuning only the last FC layer, or ridge regression on the embedding.
3. Meta-learning (FAZE/MAML) or learned person-specific embeddings (Linden et al., "Learning to personalize").
4. Differential/pairwise prediction (predict the gaze difference to a calibration frame).

## How to program it

**1. Normalization in Swift (per frame):**
```swift
// Inputs: 3D face center c (camera coords, mm) from head pose; head rotation Rh; camera K.
let dn = 600.0, fn = 960.0, size = 224
let z = normalize(c)                                // forward axis
let x = normalize(cross(Rh.columns.1, z))           // head "down" axis x forward, gives zero roll
let y = cross(z, x)
let R = simd_double3x3(rows: [x, y, z])
let S = simd_double3x3(diagonal: [1, 1, dn / length(c)])
let Kn = simd_double3x3(rows: [[fn,0,Double(size)/2],[0,fn,Double(size)/2],[0,0,1]])
let W = Kn * S * R * K.inverse                      // homography, apply with vImage / CIPerspectiveTransform
// Model output g_n (normalized pitch/yaw -> unit vector); de-normalize: g_cam = R.transpose * g_n
```
Head pose can come from Vision yaw/pitch/roll plus the existing pinhole distance estimate. The better option is a PnP fit of 6 landmarks (eye corners, mouth corners, nose) against a generic 3D face model.

**2. Core ML conversion.** Extend `scripts/convert_l2cs.py`:
```python
mlmodel = ct.convert(traced, inputs=[ct.ImageType(shape=(1,3,224,224), scale=1/(0.226*255),
                     bias=[-0.485/0.226,-0.456/0.226,-0.406/0.226])],
                     compute_precision=ct.precision.FLOAT16, minimum_deployment_target=ct.target.macOS14)
# optional: ct.optimize.coreml.linear_quantize_weights(mlmodel) -> int8, ~4x smaller
```
Also export the penultimate embedding (for example 512-d for ResNet-18) as a second output so it can be used for personalization.

**3. Per-user correction (closed form, run at calibration):**
```
X = [yaw_i, pitch_i, 1]  (N×3) from CNN on calibration frames
Y = [yaw*_i, pitch*_i]   true angles from target pos + head position (existing geometric model)
A = (XᵀX + λI)⁻¹ XᵀY     # λ≈1e-3; Huber-reweight 3 iterations
corrected = [yaw, pitch, 1] · A
```
Or fit ridge regression on the embedding (`LinearAlgebra.swift` already has what this needs) with a stronger λ, and keep the result only if held-out validation error drops.

## Recommendations for oculOS / VisionGaze

1. **Normalize before `GazeNetwork.predict`.** It currently feeds an unrotated 1.1× square face crop at 448². Warp to the normalized space (zero roll, fixed distance) and de-rotate the output. Expected gain: about 1–2° in head-pose robustness (?).
2. **Treat the CNN as a feature, not the answer.** Feed CNN yaw/pitch (after de-normalization) as extra inputs to the `GazeCalibration` LM fit, next to the eye polynomial, and let calibration weight them. The per-user affine step above is the minimal version.
3. **Switch the default to a smaller model** (L2CS-style ResNet-18 or MobileOne-S0 at 224²). ResNet-50 at 448² costs latency for little gain after calibration.
4. **Licensing.** Document that the bundled or downloadable L2CS/Gaze360 weights are research-only. Keep the CNN an optional user-supplied download (as `make-cnn-model.sh` does now) and do not ship the weights. Long term, consider an opt-in pipeline that fine-tunes a head on each user's own calibration data (on-device, never uploaded), or train on commercially licensed synthetic data.
5. **Keep EyePatch ridge regression**, but compute patches in the normalized eye space (60×36) so they are invariant to pose.
6. **Evaluation.** Report accuracy with the existing held-out validation, both with and without the CNN, so any backbone change is justified by measured degrees.

## Pitfalls

- **Coordinate conventions.** Pitch/yaw signs, radians vs degrees, and the flipped y-axis in Vision (bottom-left origin) vs the normalized image. Most "the model doesn't work" bugs are here.
- **Scaling the label.** Applying S to the gaze vector (the pre-2018 practice) adds error.
- **Train/test preprocessing mismatch.** The crop margin, color order and ImageNet normalization must match training exactly. Core ML's single `scale` approximates the per-channel std.
- **Gaze360 metrics mislead** for desktop use. Test on screen-viewing conditions.
- **Cross-dataset error is 1.5–3× within-dataset error.** Paper tables mostly report within-dataset numbers.
- **Glasses, low light, and webcam auto-exposure** break appearance models more than the benchmarks suggest.
- **Weights inherit the dataset license** regardless of the code license (legal interpretation uncertain; get legal advice before commercial use).

## Sources

- https://github.com/ut-vision/UniGaze (license MG-NC-RAI-2.0, B/L/H variants)
- https://arxiv.org/abs/2502.02307 (UniGaze paper; numbers via search snippets, since arxiv fetch was blocked)
- https://github.com/Ahmednull/L2CS-Net and https://arxiv.org/abs/2203.03339
- https://github.com/yakhyo/gaze-estimation (MobileGaze, MIT, Gaze360 MAE table)
- https://ait.ethz.ch/xgaze and https://github.com/xucong-zhang/ETH-XGaze
- https://github.com/erkil1452/gaze360/blob/master/LICENSE.md, https://gaze360.csail.mit.edu
- https://github.com/CSAILVision/GazeCapture
- https://huggingface.co/hysts/ptgaze-mpiifacegaze-resnet-simple (MPIIFaceGaze CC BY-NC-SA 4.0)
- https://arxiv.org/abs/1905.01941 (FAZE), https://arxiv.org/pdf/1807.00664 (personalization)
- https://arxiv.org/pdf/2105.14424 (GazeTR), https://arxiv.org/pdf/2104.12668 (review/benchmark, GazeHub)
- https://www.semanticscholar.org/paper/ed0cf5f577f5030ac68ab62fee1cf065349484cc (Revisiting data normalization)
- https://arxiv.org/pdf/2510.13660 (OmniGaze), https://openaccess.thecvf.com/content/CVPR2025/papers/Bao_GazeGene_Large-scale_Synthetic_Gaze_Dataset_with_3D_Eyeball_Annotations_CVPR_2025_paper.pdf
