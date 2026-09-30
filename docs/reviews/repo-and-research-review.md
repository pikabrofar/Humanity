# Review: repository health and research reports 01-10

Scope: branch `claude/camera-eye-hand-tracking-0y2amh` at `3d7f14a`, checked against GitHub `pikabrofar/oculOS`. Reports 11-30 are still being written, so they are out of scope. Swift is not installed, so nothing was built or tested. Every verdict comes from reading the code.

## Summary

- The repo is small and tidy: one Swift package (`VisionGaze/`), MIT license, sensible `.gitignore` files and a real test target (`GazeKitTests.swift`, 327 lines). It has no CI, no contribution docs or templates, no open PRs or issues, and the research branch has not been proposed for merge.
- The codebase claims in reports 01, 04, 05 and 10 are mostly accurate. Head roll really is levelled out of the features and never used again. Head rotation really is an additive yaw/pitch term with a 0±3 prior. Click learning really refits the full model on up to 400 click samples. `GazeFeatures` really is `Codable`. The CNN really gets an unrotated 1.1x face crop at 448². The one inaccuracy is in report 05, which treats "4 confirmation samples" as fixed. That is only the default. The count is user-tunable from 2 to 6 frames.
- The biggest documentation problem is that the root README says there are "ten reports", while `docs/research/` already holds 21 and more are coming.

## Repository health findings

| Item | Status | Recommendation |
|---|---|---|
| Root `README.md` vs files | Mostly accurate. It links `VisionGaze/`, `docs/research/` and `LICENSE`, all of which exist. It says "ten reports", but 21 files exist (01-21) and 11-30 are in progress. | Update the count, or say "a series of reports" and link the index `docs/research/README.md`. |
| `VisionGaze/README.md` vs build | Accurate. `make run` / `make test` match `VisionGaze/Makefile` (targets `app run test clean cnn-model`). `Package.swift` defines `GazeKit`, `VisionGaze` and `GazeKitTests` on macOS 14 with tools 5.10, which matches "macOS 14 / Xcode 15+". There is no root Makefile or Package, and the README does not claim one. | None needed. You could document `make cnn-model` next to `scripts/convert_l2cs.py`. |
| README "Head movement is compensated" | Partially true. Yaw/pitch are compensated additively. Roll is not rotated back (see report 04 below). Line 204 of the VisionGaze README already lists "3D face pose" as future work. | Soften the wording, e.g. "partially compensated (yaw/pitch); roll and large head motion are not". |
| LICENSE | Present (MIT). `VisionGaze/LICENSE` duplicates it with a different holder ("VisionGaze contributors" vs "oculOS contributors"). | Use one holder name, or drop the nested copy. |
| `.gitignore` | Root: `.DS_Store .build/ build/ .swiftpm/ xcuserdata/`. Nested adds `*.xcodeproj/` and `Info.plist`. It is adequate, but ignoring `Info.plist` means it has to be generated (by `scripts/build-app.sh`). | Add `*.mlpackage`, `*.mlmodelc` and `__pycache__/`, since `convert_l2cs.py` produces model artifacts that should not be committed. |
| CI (`.github/workflows`) | Missing | Add a macOS runner job that runs `make test`. It becomes much more useful once the replay regression suite from report 10 exists. |
| CONTRIBUTING / CODE_OF_CONDUCT / SECURITY | Missing | Add a short CONTRIBUTING: build steps, test command, and privacy rules (no committed frames or recordings). |
| Issue / PR templates | Missing | Add a bug template that asks for macOS version, camera, glasses/lighting and calibration report numbers. |
| GitHub branches | `main` and `claude/camera-eye-hand-tracking-0y2amh` | Open a PR for the research branch once reports 11-30 are done. |
| GitHub PRs / issues | 0 PRs, 0 issues | Turn the roadmap in `docs/research/README.md` into tracked issues. |
| Commit history | 8 commits. Two are by the owner (initial, app). Six are research commits with vague messages ("Add more research reports" twice, "in progress" twice). | Squash the research commits into one descriptive commit when merging. |
| Tests | `VisionGaze/Tests/GazeKitTests/GazeKitTests.swift` exists. Only GazeKit is covered, not the app layer (`GazeEngine`). | Fine for now. The click-learning logic in `GazeEngine` is untested. |

## Research claim verification

| Report | Claim | Verdict | Evidence |
|---|---|---|---|
| 04 | Roll is levelled out of the features but never rotated back into screen space | **Confirmed** | The eye-line angle is used to level the eye features and patches: `FaceFeatureExtractor.swift:72-76`, `:95`. `roll` is stored at `:91` / `GazeFeatures.swift:27`, but nothing in `GazeCalibration.swift` reads `roll`. `thetaRow`/`phiRow` (`GazeCalibration.swift:160-169`) use only `yaw`/`pitch`. |
| 04 | Head rotation enters as additive, linearly weighted yaw/pitch terms with a 0±3 prior | **Confirmed** | `f.yaw` is a linear column in `thetaRow` (`GazeCalibration.swift:162`) and `f.pitch` in `phiRow` (`:168`). The weights are at `:80`, `:131`. The prior `(.yaw, 0, 3), (.pitch, 0, 3)` is at `:352`. |
| 04 | Click learning refits the full model with up to 400 click samples | **Confirmed** | `GazeEngine.swift:216-227` appends click samples, keeps the last `maxClickSamples`, and calls `GazeCalibration.fit(samples: stored.samples + stored.clickSamples, ...)`. `Persistence.swift:12` sets `maxClickSamples = 400`. Nuance: it caps click *samples*, not clicks. Each click adds every non-blink frame from the last 0.25 s (`GazeEngine.swift:212`), about 7 frames at 30 fps, so 400 samples is roughly 55 clicks. Report 04 recommendation #2 ("400-click cap") gets this wrong. |
| 04 | The model is fit with Huber-weighted LM | **Confirmed** (IRLS with Huber weights) | `GazeCalibration.swift:226` |
| 04 / 02 | Vision face-rectangles revision 3 is used for pose, and revisions are pinned | **Confirmed** | `FaceFeatureExtractor.swift:37`, `:40` |
| 05 | Confirmation costs 4 samples at 30 fps (133 ms) | **Partially true** | 4 is the library default (`FixationStabilizer.swift:22`) and the app default (`responsiveness` defaults to 0.5, so 6 - round(2) = 4; `GazeEngine.swift:47`, `:203`). But the app already lets the user choose 2-6 frames, and the camera frame rate is never set (`CameraCapture.swift:48-49` only picks a preset), so the 30 fps figure is assumed. |
| 05 | `FixationStabilizer` is a hold-and-jump filter that ignores single outliers | **Confirmed** | `FixationStabilizer.swift:34-58`: a running mean within the radius, and a jump only when `confirmSamples` consecutive candidates are all within the radius of their mean. One thing the report does not mention: a sample that falls back inside the radius clears the candidates (`:35`), and the window slides with `removeFirst` (`:56`). |
| 05 | Express `maxWindow` / confirmation in ms, not samples | Valid gap | Both are sample counts (`FixationStabilizer.swift:13-16`). |
| 01 | `GazeNetwork.predict` feeds an unrotated 1.1x square face crop at 448² | **Confirmed** | `GazeNetwork.swift:30-36`: an axis-aligned square ROI of 1.1x the face box, with no rotation, and `scaleFill` (`:20`). The 448x448 input comes from `scripts/convert_l2cs.py:38,44`. The output is used raw with no de-rotation (`:43`). |
| 02 | GazeKit already shares one `VNImageRequestHandler` with the CNN | **Confirmed** | `FaceFeatureExtractor.swift:96` passes `handler` to `network?.predict`, and `GazeNetwork.swift:38` calls `handler.perform`. |
| 10 | `GazeFeatures` is already `Codable` | **Confirmed**, with a caveat | `GazeFeatures.swift:20` (and `EyeFeatures` at `:6`, `GazeSample` at `:83`). Caveat: it includes `appearance: [Float]` (raw eye-patch pixels, `:35`). JSONL replay files will be large, and they contain biometric image data, which conflicts with the README's promise that frames are never saved. |
| 10 | VisionGaze already does implicit recalibration from clicks | **Confirmed** | `GazeEngine.swift:206-231` |
| 10 | VisionGaze estimates viewing distance from the face box | **Confirmed** | Pinhole head position from `faceCenter`/`faceSize`, `GazeCalibration.swift:~145-154` |

## Contradictions and dubious claims

1. **Report 04 mixes up clicks and samples.** Its summary correctly says "400 click samples", but recommendation #2 says "400-click cap". They differ by about 7x.
2. **Report 05's latency figure versus the code.** "4 confirmation samples at 30 fps = 133 ms" is presented as fixed. Its own recommendation (2 samples for far jumps) is something the user can already get globally with the Responsiveness setting. It should be framed as making the count *adaptive*, not as a new capability. The 30 fps figure is also unverified.
3. **Report 10's replay suite versus the privacy stance.** Recording `GazeFeatures` JSONL includes eye-patch pixels. That contradicts "Video frames are processed in memory and never saved" in `VisionGaze/README.md`, and likely conflicts with report 21 (privacy). The schema should drop `appearance` or put it behind an opt-in.
4. **Root README versus the research index.** The root README says ten reports, but the index and directory have more. The README also calls head movement "compensated", while reports 01 and 04 document large gaps in that compensation.
5. **External claims worth re-checking before anyone relies on them:**
   - Report 01: the exact UniGaze-H cross-dataset figures (4.87° / 6.53° / 11.19°). The report itself marks items "(?)", and a 2025 model's numbers should get a citation.
   - Report 01: "about 1–2° gain" from normalization. It is flagged (?) and is a guess.
   - Report 04: "removing the scaling factor improved results by 9.5–32.7%". Check that this range is from Zhang et al. ETRA 2018 and applies to eye patches the way the report uses it.
   - Report 10: Eyeware Beam's "1.5°" is a vendor claim, not an independent measurement.
   - Report 08: that Post Event and Accessibility grants "show up in the same list" varies by macOS version and should be tested on 14/15.
   - Report 07: the "WWDC20 sample, 40 pt, 3 frames" constants are plausible, but should be checked against the sample code.

## Top 5 recommended actions

1. **Fix roll handling (report 04, P0).** Rotate the (θ, φ) eye-in-head vector by head roll before adding head yaw/pitch (`GazeCalibration.swift:160-173`), and add a unit test using synthetic features with a 10-20° roll.
2. **Add CI.** A GitHub Actions macOS job that runs `cd VisionGaze && make test`, then add the report-10 replay suite. Leave `appearance` out of the recorded schema, or make it opt-in, to keep the privacy promise.
3. **Correct the docs.** In the root README, change the report count to "series" and link the index. In the VisionGaze README, qualify "head movement is compensated". In report 04 recommendation #2, change "400-click" to "400-sample (≈55 clicks)". In report 05, describe the confirmation count as already tunable from 2 to 6.
4. **Replace the full refit on clicks with a drift layer** (report 04 #2): a time-decayed offset or affine map, with base calibration geometry kept fixed. Add a test for `GazeEngine.learnFromClick`, which currently has no coverage.
5. **Repo hygiene.** Settle the LICENSE holder name. Add CONTRIBUTING and issue/PR templates. Ignore `*.mlpackage`/`*.mlmodelc`. Open a PR for the research branch with a squashed, descriptive commit, and file the roadmap items as issues.
