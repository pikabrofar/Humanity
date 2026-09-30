# 13 — Synthetic training data for commercially usable gaze and hand models

## TL;DR

- Most off-the-shelf synthetic datasets are **non-commercial**, just like the real ones: Microsoft FaceSynthetics, SynthMoCap (SynthFace/SynthHand), RHD, U2Eyes, and very likely SynthesEyes and the original UnityEyes.
- The best option we found is **UnityEyes 2** (2025, MIT-licensed repo, has macOS builds), but the MIT license may cover only the new code and not the eye/head assets it inherits from Wood's UnityEyes. *(unverified: check the asset provenance)*
- The only licence-clean route to data we can ship is **our own pipeline**: Blender plus CC0/CC-BY assets, rendered with Python scripts. Train a small CNN, fine-tune it on data from our own users that they consent to give, and export it with `coremltools`.
- Synthetic data makes the model robust. Accuracy still comes from **per-user calibration** (see 01 and 04). Don't expect sim2real to close the gap to 1.5°.

## Key findings

| Source | What | Licence | OK for MIT oculOS? |
|---|---|---|---|
| UnityEyes (Wood et al. 2016) | 1M+ eye-region renders, gaze/landmarks | Free for non-commercial research *(unverified)* | No |
| **UnityEyes 2** (Smith et al., ETRA 2025) | Unity generator, configurable cameras/lights, JSON batch mode, Win/Linux/macOS builds | Repo is **MIT** | Maybe. Code yes. Check the inherited assets |
| SynthesEyes (Wood et al. 2015) | 11k eye-region renders | Research only *(unverified)* | No |
| U2Eyes | UnityEyes-based, binocular | CC BY-NC-SA 4.0 | No |
| NVGaze (Kim et al. CHI 2019) | 2M near-eye IR synthetic + 2.5M real | Not found. Probably NC *(unverified)*. Near-eye IR, so the wrong domain anyway | No |
| Microsoft FaceSynthetics (Wood et al. ICCV 2021, "Fake it till you make it") | 100k faces 512², 70 landmarks (incl. pupils), 19-class seg | Non-commercial research only | No |
| Microsoft SynthMoCap: SynthFace / SynthHand (2024) | 512² faces with head + eye rotation matrices; left hands with 2D/3D joints, SMPL-H | Non-commercial | No (and SMPL-H/MANO are NC too) |
| RHD (Freiburg, Zimmermann & Brox 2017) | 41k rendered hands, 21 kp, masks, depth | Research only, commercial use prohibited | No |
| Own Blender pipeline + CC0 assets (e.g. MakeHuman/MPFB CC0 base meshes, Poly Haven HDRIs) | Anything we need | Our renders; assets CC0 | **Yes** |

Notes:
- FaceSynthetics landmarks are 3D points projected onto the image ("x-ray" style), so they don't always follow the visible face outline.
- SynthFace has eye rotation matrices, not an explicit gaze vector. Gaze can be derived from the eye rotation.
- Apple's own SimGAN work (Shrivastava et al. CVPR 2017) refined UnityEyes renders with unlabeled real eyes. It shows sim2real works for eyes, but the SimGAN weights aren't a shippable artifact.
- Blender is GPL, but images it renders are not covered by the GPL. What matters is the licence of each mesh, texture and HDRI we use.

## How to program it

```
1. Generate    blender -b -P render_eyes.py -- --n 200000 --seed S
               - CC0 head mesh with rigged eyeballs (sclera, iris texture set, cornea refraction)
               - randomize: gaze yaw/pitch, head pose ±30°, skin tone, iris colour,
                 eyelid/blink, glasses, HDRI lighting, webcam intrinsics (FOV 55-80°)
               - write PNG + JSON {gaze vec, head R|t, 2D eye-corner/iris landmarks}
               - hands: rigged CC0 hand (not MANO), random joint angles within
                 anatomical limits, 21 kp matching VNHumanHandPoseObservation order
2. Degrade     webcam realism: sensor noise, JPEG, motion blur, low light, gamma,
               rolling-shutter/defocus, 640x480-1280x720 downsample
3. Crop        use the SAME crop code as the app (Vision eye-region landmarks → 60x36 patch
               or face-normalized crop), so train and test inputs match
4. Train       PyTorch small CNN (MobileNetV3/ResNet-18) → gaze (pitch,yaw) + landmarks;
               mixed batches: synthetic + optional consented real frames
5. Adapt       strong augmentation + either feature-level DA (DANN) or
               unpaired image translation; then per-user linear head calibration (04)
6. Export      ct.convert(torch.jit.trace(model, x), inputs=[ct.ImageType(...)],
               minimum_deployment_target=ct.target.macOS14, compute_precision=FLOAT16)
               → .mlpackage, run via VNCoreMLRequest on the shared frame (02)
7. Validate    benchmark locally on MPIIGaze/ETH-XGaze (allowed for evaluation, never shipped)
```

## Recommendations for oculOS

1. **Don't ship a learned gaze model yet.** The geometric and calibrated pipeline (03, 04) is already in the webcam accuracy range. Treat synthetic training as an R&D track.
2. If we train one, **audit UnityEyes 2's asset licences first** (open an issue on the repo). If they're clean, it's the fastest way to get eye-region data.
3. Otherwise, build a small `tools/synth/` Blender pipeline using only CC0 assets. Keep an `ASSETS.md` that lists the licence of every file used.
4. For hands, **keep Apple Vision's hand pose** (06). A synthetic hand set is only worth building for a custom gesture classifier on top of the joints. For that, we can synthesize joint sequences directly without rendering.
5. Commit the generator, seeds and model card. Host rendered data and weights under CC-BY/MIT. Never mix in NC data, even "just for pretraining".

## Pitfalls

- **Licence contamination.** Pretraining on NC data (FaceSynthetics, RHD, MPIIGaze) arguably taints the weights. Keep NC data in eval scripts only.
- **MANO/SMPL-H/FLAME.** The body models themselves are NC. They cannot drive our hand or face rigs.
- **Domain gap.** Clean renders overfit to perfect specular highlights and pupils. Webcams see the iris at a few pixels (03), so render at low resolution and degrade the images aggressively.
- **Label mismatch.** Define gaze with the same origin and coordinate frame the app uses (eye centre versus face centre, camera frame). Match joint order to Vision's.
- **Diversity.** Too few head, skin and iris variants gives biased models. Report per-group error.
- Core ML: fixed input sizes convert best. Test ANE placement. Float16 can shift the output by a small fraction of a degree.

## Sources

- https://github.com/microsoft/FaceSynthetics
- https://github.com/microsoft/SynthMoCap and https://github.com/microsoft/SynthMoCap/blob/main/DATASETS.md
- https://github.com/alexanderdsmith/UnityEyes2
- https://motion.cs.illinois.edu/papers/ETRA2025_Smith_UnityEyes2.pdf (title only, not read)
- https://github.com/benoit-bossavit/U2Eyes
- https://www.collaborative-ai.org/publications/wood16_etra.pdf (UnityEyes paper, from search result)
- https://lmb.informatik.uni-freiburg.de/resources/datasets/RenderedHandposeDataset.en.html (from search summary)
- https://openreview.net/pdf?id=VCvUq-f60r (NVGaze paper; licence not found)
- From memory, not re-checked: Shrivastava et al., "Learning from Simulated and Unsupervised Images through Adversarial Training", CVPR 2017. coremltools documentation.
