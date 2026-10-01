# Appearance-Based Webcam Gaze Estimation: State of the Art 2022–2026

From 2022 to 2026, the field moved from single-dataset CNNs (L2CS-Net, the ETH-XGaze ResNet-50 baseline) to hybrid transformers (GazeTR) and then to models pre-trained at scale for generalization: 3DGazeNet (ECCV 2024), UniGaze (WACV 2026) and OmniGaze (NeurIPS 2025). Errors within a single dataset have plateaued at about 3–4° on MPIIFaceGaze. The real gap is cross-dataset error, and only large ViT pre-training has narrowed it a lot. None of the top generalist models is licensed for commercial use, and most are too large to run well on a laptop in real time. VisionGaze's reported ~5° is already close to the best cross-dataset numbers on MPIIFaceGaze-like (frontal, desk-distance) conditions. Per-user few-shot calibration, done cheaply on the device, is therefore the step with the best return, not a bigger backbone.

## Key findings

- **UniGaze** (ViT pre-trained with a masked autoencoder on 1.6M face images; 224×224 input; B/L/H variants):
  - Trained on ETH-XGaze, UniGaze-H reaches 5.57° on MPIIFaceGaze, 4.65° on EYEDIAP and 11.19° on Gaze360.
  - On the same test sets, a ResNet-50 gets 6.75°, 10.08° and 19.80°, and GazeTR gets 7.09°, 10.95° and 21.10°.
  - Leave-one-dataset-out: 4.51° on MPIIFaceGaze.
  - Within-dataset: 3.56° on ETH-XGaze and 3.01° on GazeCapture.
  - License: MG-NC-RAI-2.0 (**non-commercial**). Pre-training took about 120 hours on 4×H100 GPUs.
- **3DGazeNet** (ECCV 2024) regresses dense 3D eye meshes. It gets 4.00° on MPIIFaceGaze and 9.60° on Gaze360, and gives roughly 20% better cross-domain results on Gaze360 with in-the-wild pseudo-labels. Code is **CC BY-NC-ND 4.0**, which forbids both commercial use and derivatives.
- **OmniGaze** (NeurIPS 2025) pseudo-labels large amounts of unlabeled in-the-wild faces and filters the labels with a reward model. It reports state-of-the-art results on 5 datasets plus zero-shot results on 4 unseen datasets. This is a training recipe, not a model sized for a laptop.
- **L2CS-Net / MobileGaze** (MIT-licensed code) combine a classification loss over angle bins with a regression loss. Gaze360 errors for the MobileGaze models:

  | Model | Gaze360 error | Size |
  |---|---|---|
  | MobileOne-S0 | 12.58° | 4.8 MB |
  | MobileNetV2 | 13.07° | — |
  | ResNet-18 | 12.84° | — |
  | ResNet-34 | 11.33° | 81.6 MB |

  The bigger backbones gain little. All MobileGaze weights are trained **only on Gaze360**.
- **Dataset licenses are the binding constraint.**
  - ETH-XGaze and MPIIFaceGaze are CC BY-NC-SA 4.0. ETH-XGaze's terms extend the non-commercial restriction to models.
  - Gaze360 is non-commercial research only, and it forbids redistribution and restricts models trained on it.
  - GazeCapture requires a signed agreement.
  - So every public gaze checkpoint is effectively non-commercial, **including the MobileGaze weights VisionGaze ships today**.
- **Few-shot personalization is the big lever.**
  - WebEyeTrack/BlazeGaze (2025) is 0.16M parameters / 670 KB and runs in 2.4 ms on an iPhone 14. It uses MAML meta-learning with k≤9 calibration points and gets 2.32 cm error on GazeCapture.
  - Fine-tuning only the last fully-connected layer cuts error by 52.8% after 30 s of calibration.
  - A 2026 session-wise meta-calibration method reaches 8.82° on MPIIFaceGaze with 16 calibration shots, using landmarks only.
  - FAZE (2019) is still the reference baseline: about 3.2° with 9 calibration samples.
- **Core ML feasibility:**
  - MobileOne was designed for the Apple Neural Engine (ANE): S0 runs in under 1 ms on iPhone 12, per Apple's paper.
  - ViT-B at 224 px (UniGaze-B) should convert with coremltools and probably runs at about 10–30 ms on Apple Silicon. I estimated this and have not measured it. That is fine for 30 fps.
  - ViT-H is impractical for always-on use.

## Recommendations for OculOS (ranked)

1. **Ship on-device few-shot calibration on top of the frozen MobileOne-S0.**
   - Take features from the penultimate layer, concatenate the head-pose vector from the geometric model, and fit a closed-form ridge-regression head that maps them to screen point-of-regard (PoG).
   - Use a 9–16-point calibration, then keep recalibrating implicitly from cursor clicks and ManOS clicks, where gaze is about at the click target.
   - Based on the results above, expect roughly a 30–50% error reduction for under 1 ms of extra compute. Add a 1€ filter for smoothing.
2. **Fix the license exposure now.**
   - The bundled MobileGaze weights come from Gaze360 data, which is non-commercial and forbids redistribution.
   - Move the weights out of the repo into a separate download that requires accepting the license, and document this in the README.
   - Keep the geometric head-pose path as a fully open fallback with no learned weights.
3. **Retrain the student network on multiple datasets with ETH-XGaze normalization.**
   - Apply ETH-XGaze-style normalization (Zhang 2018: a virtual camera that removes head roll) using the Apple Vision landmarks and a 3D face model.
   - Train MobileOne-S0 or S1 jointly on ETH-XGaze, MPIIFaceGaze and Gaze360, using GazeHub preprocessing.
   - Single-dataset training is the main reason for the 12.6° Gaze360 error, and cross-dataset error is what users feel.
4. **Add an optional "high-accuracy" mode with UniGaze-B in Core ML.** Run it on the ANE only while calibrating or when the user opts in, as a stronger feature extractor. Benchmark its latency on M1–M4. It is non-commercial, so offer it only as an optional download.
5. **Build a reproducible evaluation harness.** Cover:
   - leave-one-dataset-out testing on MPIIFaceGaze and EYEDIAP, in degrees;
   - a small in-house screen-PoG set with consent, in cm and px, before and after calibration;
   - long-session drift, since WebEyeTrack showed WebGazer's error growing 49% over 20 minutes.

   Without this, the "~5°" claim can't be compared against the numbers above.
6. **Track commercially clean data sources.** Synthetic face pipelines (FaceSynthetics-style renders, multi-view relighting as in 3DGazeNet) could eventually support a permissively licensed gaze model. That is a longer-term project for the community.

## Sources

- https://arxiv.org/abs/2502.02307 (UniGaze)
- https://github.com/ut-vision/UniGaze
- https://github.com/yakhyo/gaze-estimation (MobileGaze)
- https://yakhyo.github.io/gaze-estimation/
- https://github.com/eververas/3DGazeNet
- https://www.ecva.net/papers/eccv_2024/papers_ECCV/papers/03191.pdf
- https://arxiv.org/abs/2510.13660 (OmniGaze)
- https://arxiv.org/html/2508.19544 (WebEyeTrack/BlazeGaze)
- https://arxiv.org/html/2603.12388 (Session-wise meta-calibration)
- https://doi.org/10.1145/3797246.3803047 (Lightweight on-device fine-tuning)
- https://research.google/pubs/on-device-few-shot-personalization-for-real-time-gaze-estimation/
- https://github.com/xucong-zhang/ETH-XGaze
- https://github.com/erkil1452/gaze360/blob/master/LICENSE.md
- https://www.collaborative-ai.org/research/datasets/MPIIFaceGaze/
- https://phi-ai.buaa.edu.cn/Gazehub/
