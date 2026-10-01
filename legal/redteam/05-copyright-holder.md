# Red team 05: copyright holder persona

Not legal advice. This is a research-engineering review, and nothing here says any item is "safe" or "compliant". Attorney items are flagged **[ATTORNEY]**.

Scope: repo at commit `1f611aa`. Persona: FluidInference, pyannote, NVIDIA NeMo, the Rust crate authors, Apple (SF Symbols) and the Gaze360 authors.

Method:
- Read `THIRD_PARTY_NOTICES.md`.
- Read FluidAudio 0.17.4 in `Humanity/.build/checkouts/FluidAudio`, including `ThirdPartyLicenses/*`.
- Ran `strings` on `Humanity/build/Humanity.app/Contents/MacOS/Humanity`.
- Fetched the text-processing-rs v0.3.1 `Cargo.lock` and `THIRD-PARTY-LICENSES.md`.
- Mounted the four `dist/*-1.0.0.dmg` files read-only and diffed their notices.
- Read all four `*/scripts/make-icon.swift` and rendered icons, `OculOS/scripts/make-cnn-model.sh` and `convert_gaze_model.py`.
- Grepped for copied or adapted code.
- No apps were launched and no files edited except this one.

## Verified as OK (current source tree)
- **Notice content.** The current `THIRD_PARTY_NOTICES.md` carries these items:
  - the Apache-2.0 text;
  - the fastcluster BSD-2 text with both copyright lines;
  - VBx;
  - the text-processing-rs NOTICE block (Apache §4(d)), v0.3.1 and matching `Package.resolved`;
  - the MIT-only crates (nom, generic-array, ordered-float, simd-adler32, memchr);
  - Rust std;
  - the cutlet, Convert-Numbers-to-Japanese and misaki lines;
  - the CC BY 4.0 diarization-model attribution, with pyannote, WeSpeaker, BUT Speech@FIT, Fluid Inference, "modified Core ML conversions" and the three citations.
- **Notices in the bundle.** All four `*/scripts/build-app.sh` (lines 41-43) copy `LICENSE` and `THIRD_PARTY_NOTICES.md` into `Contents/Resources` and render `Credits.rtf`. `Humanity/build/Humanity.app` has the current file, byte-identical to the repo's.
- **Crate coverage.** The linked crates visible in the binary (rustfst-1.3.1, flate2-1.1.9, miniz_oxide-0.8.9, nom-7.1.3, anyhow-1.0.103, lazy_static-1.5.0) are all named. The remaining crates in the v0.3.1 `Cargo.lock` that matter are named too, or are build-time or test-only (proptest, tempfile, wasm-bindgen and similar).
- **No copied third-party code.** Internal copies are marked `// ponytail: copied from OculOS...` and are first-party. `ManOS/Sources/HandKit/OneEuroFilter.swift` implements a published algorithm. I found no license headers, "adapted from" or Stack Overflow or gist references anywhere. No ScanCode run was done; see finding 9.
- **Diarization models.** `FluidDiarizer` (`MeetingKit/Sources/MeetingKit/Diarizer.swift:17-30`) calls only `OfflineDiarizerManager`. That uses the Community-1 files (`Segmentation`, `FBank`, `Embedding`, `PldaRho`, `plda-parameters.json`), which the HF NOTICE.md scopes under CC BY 4.0. The legacy `wespeaker.mlmodelc` and `pyannote_segmentation.mlmodelc` files, which that NOTICE.md says are out of scope, are not used. The models are fetched by the user's Mac from HF and are not redistributed by us.
- **Dead FluidAudio code.** The binary contains Kokoro, Parakeet and LuxTts strings because the whole library is linked. Nothing calls those code paths. Their model repos are never downloaded.
- **Icons.** All four `make-icon.swift` scripts draw with `NSBezierPath` and `NSGradient`. None calls `NSImage(systemSymbolName:)`. The earlier "icons are SF Symbols" audit item has been fixed in method, but see finding 3.

## Findings, ranked

### 1. Local `dist/*.dmg` files carry stale notices (the files that would go to Gumroad)
- **Scenario.** All four 1.0.0 DMGs were built at 00:07. They contain the old `THIRD_PARTY_NOTICES.md`. In the Murmur DMG, lines 17-59 of the current file are missing: the text-processing-rs NOTICE block, the MIT crate list, the Japanese G2P attributions and the "which apps contain FluidAudio" line.
  - `dist/` is gitignored, so these files were built by hand.
  - The app in `Humanity/build/` is newer (00:41, current notices).
  - If someone uploads `dist/*` to Gumroad, NVIDIA/FluidInference NOTICE reproduction (Apache §4(d)) and the MIT notices for nom and others are missing from the binary distribution.
  - A holder or notice-scanner who unpacks the DMG sees this immediately.
- **Likelihood: H.** Impact: M.
- **Mitigation.** `release.yml` rebuilds from source via `scripts/package.sh`, so a tag build would be fine (`scripts/package.sh:14-26`). `RELEASE-CHECKLIST.md` does not mention re-diffing the notices.
- **Remaining risk.** Manual uploads of old DMGs.
- **Fix.**
  - Run `scripts/package.sh <App> 1.0.0` for all four apps before any upload.
  - Add to `scripts/package.sh`, after the build and before `hdiutil create`, `cmp -s ../THIRD_PARTY_NOTICES.md "$APP_DIR/build/$APP_NAME.app/Contents/Resources/THIRD_PARTY_NOTICES.md" || exit 1`.
  - Add the same cmp as a step in `release.yml`.

### 2. Optional Gaze360-trained CNN path is still advertised and wired into a paid app
- **Scenario.** The Gaze360 licensor (Kellnhofer et al.; MIT/Toyota) sees these:
  - an MIT-licensed repo whose paid product's README lists "Optional gaze CNN (MobileGaze via Core ML, 1.6 ms/frame)" as a feature (`OculOS/README.md:8`);
  - `make cnn-model` plus `Settings → Gaze CNN → Load Model…` (`OculOS/Makefile:21-22`, `OculOS/Sources/OculOSUI/Views/SettingsView.swift:42-47`);
  - `research/01-gaze-models.md:29,47` stating that every public gaze checkpoint is "effectively non-commercial, including the MobileGaze weights" that the script downloads.
  - Gaze360's terms (fetched 2026-10-01) say the material "will not be used nor included in commercial applications in any form", and cover models trained on it.
  - They could argue the commercial product induces or enables use. They could also argue the repo documents knowledge of the restriction.
- **Likelihood: L-M.** Impact: M (takedown demand, reputational harm; the damages theory is weak).
- **Mitigation.**
  - No weights are bundled or hosted.
  - `make-cnn-model.sh:8-19` shows the terms, requires typing "yes" and refuses redistribution.
  - `convert_gaze_model.py:54-56` now labels the model non-commercial.
  - `TERMS.md:65` and `OculOS/README.md:134-140` warn users.
  - `SettingsView.swift:47` warns in the UI.
- **Remaining risk.**
  - The paid product markets the feature, and the user's own use is commercial if they use the paid app.
  - The prompt only gates the script, not the app's "Load Model…".
  - The "yes" prompt asks for "non-commercial research" use, but running it inside a paid product is arguably not that.
  - An "induce" or secondary-liability theory is **[ATTORNEY]**.
- **Fix.**
  - Reword `OculOS/README.md:8` and any Gumroad copy: "Load your own Core ML gaze model (none included)".
  - Remove the MobileGaze name and "1.6 ms/frame" from the feature bullet.
  - Optionally move `make-cnn-model.sh` and `convert_gaze_model.py` out of the product repo into `research/`.
  - Add to `SettingsView.swift:47`: "Models trained on Gaze360 may not be used in commercial software."

### 3. Humanity and ManOS app icons are close to Apple SF Symbols (`figure.arms.open`, `hand.raised.fill`)
- **Scenario.** Apple's SF Symbols terms bar SF Symbols "or glyphs that are substantially or confusingly similar" in app icons and logos. I rendered the two icons:
  - Humanity (`Humanity/build/AppIcon.iconset/icon_256x256.png`) is a round head with arms spread and legs apart, white on a gradient squircle. It is visually very close to `figure.arms.open` and Apple's Accessibility figure.
  - ManOS is a white raised open hand with an angled thumb, and reads as `hand.raised.fill`.
  - The code is hand-drawn paths, so the earlier "uses SF Symbols" finding is moot. Resemblance is a judgment call, and Apple rarely enforces outside the App Store.
- **Likelihood: M.** Impact: L-M.
- **Mitigation.**
  - Original geometry in `Humanity/scripts/make-icon.swift:21-37` and `ManOS/scripts/make-icon.swift:21-37`.
  - OculOS (eye with heatmap glow) and Murmur (bars) are generic.
- **Remaining risk.**
  - Gumroad and website imagery that looks like Apple's symbols.
  - `build-app.sh:36-40` reuses a cached `build/AppIcon.icns`, so a redesign needs `rm -rf */build/AppIcon.*`.
- **Fix.**
  - Change the silhouettes in `Humanity/scripts/make-icon.swift` and `ManOS/scripts/make-icon.swift` enough to be clearly distinct:
    - a different pose, stylized or asymmetric;
    - a non-white color, or a distinctive motif such as a pointer or finger-trace.
  - Then rebuild the `.icns` and the DMGs.
  - Do not describe icons as "SF Symbols-style".
  - A trademark and design-similarity opinion is **[ATTORNEY]**.

### 4. Rust "choice of license" reliance and std third-party code are only partly documented
- **Scenario.** FluidAudio's own `ThirdPartyLicenses/NemoTextProcessing-LICENSE.md` says v0.3.0 and points to a `THIRD-PARTY-LICENSES.md` we do not ship. Our notice names crates and licenses but gives per-crate copyright lines only for the MIT-only ones.
  - A crate author could object to missing copyright lines for dual-licensed crates. The licenses mostly require the license text, not the lines, but MIT crates used under MIT need their lines.
  - The Rust std `COPYRIGHT` file lists bundled third parties that are not named (for example hashbrown, gimli, libm, compiler-builtins).
- **Likelihood: L.** Impact: L.
- **Mitigation.** `THIRD_PARTY_NOTICES.md` ("Where a choice of license is offered, Humanity uses them under the Apache License 2.0"; "memchr (under MIT)") lists crate names, so a reader can trace them.
- **Remaining risk.**
  - The crate list was built from `Cargo.lock` and `strings`. It is not generated from the actual linked set.
  - `zerocopy` and `rand` are listed under Apache.
  - Std's MIT bundled code gets no line.
- **Fix.**
  - Add one sentence to `THIRD_PARTY_NOTICES.md`: "The Rust standard library bundles further MIT/Apache components; see https://github.com/rust-lang/rust/blob/master/COPYRIGHT."
  - Add: "Full per-crate list: text-processing-rs v0.3.1 `Cargo.lock`."
  - Optionally run `cargo-about` against that `Cargo.lock` and paste the output.

### 5. Hugging Face model files are downloaded at runtime; the CC BY terms depend on upstream NOTICE staying the same
- **Scenario.**
  - FluidInference could retag the repo or change its NOTICE.md scope. Our attribution is a snapshot, not tied to a commit.
  - The legacy WeSpeaker files in the same repo "require separate evaluation" per FluidInference. FluidAudio's `ModelNames.swift:54` uses the repo name `FluidInference/speaker-diarization-coreml`, which holds both legacy and Community-1 files.
  - If a FluidAudio update starts fetching legacy files, our CC BY scope claim becomes wrong.
  - The HF NOTICE.md also says to retain citations and link to the license. We do (`THIRD_PARTY_NOTICES.md`, "Speaker diarization models").
- **Likelihood: L.** Impact: L-M.
- **Mitigation.**
  - `Package.resolved` pins FluidAudio 0.17.4 at `21493f8`.
  - `Diarizer.swift:17-30` uses only the offline Community-1 path.
- **Remaining risk.**
  - A silent dependency bump.
  - A weights snapshot that is not pinned (no `artifact_snapshot` in the notice).
  - Whether WeSpeaker weights trained on VoxCeleb carry any extra terms **[ATTORNEY]**.
- **Fix.**
  - Add a comment next to `Package.resolved`'s FluidAudio pin, or to `README`: "Re-audit THIRD_PARTY_NOTICES.md on any FluidAudio bump."
  - In `THIRD_PARTY_NOTICES.md`, add the HF `artifact_snapshot` hash (the earlier audit lists `1ed7a662...` from `provenance.json`), so the claim is reproducible.

### 6. LuxTts resource bundle (espeak-derived lexicon) is not shipped today but is one build-script edit from shipping
- **Scenario.** `FluidAudio_FluidAudio.bundle` exists under `Humanity/.build/arm64-apple-macosx/release/` (it contains `luxtts_en_us_lexicon.tsv.zz`).
  - The lexicon was derived from espeak-ng (GPL-3.0) per FluidAudio's own docs and the earlier audit.
  - A common fix for a `Bundle.module` crash is to copy `*.bundle` into the `.app`.
  - If someone does that, the apps would ship data with unclear GPL provenance. The espeak-ng authors would be the claimants.
  - `find Humanity/build -name '*.bundle'` returns nothing today.
- **Likelihood: L.** Impact: M.
- **Mitigation.** `build-app.sh` copies only the executable, plist, icns, LICENSE and notices (lines 29-43).
- **Remaining risk.** No guard. The spelling of this risk in docs is in `legal/OPEN-SOURCE-AUDIT.md` only.
- **Fix.** Add to `scripts/package.sh` before `hdiutil create`: `! find "$APP_DIR/build/$APP_NAME.app" -name 'FluidAudio_FluidAudio.bundle' | grep -q . || { echo "LuxTts bundle must not ship"; exit 1; }`.

### 7. Copyright holder line is "Humanity contributors", not a legal person
- **Scenario.**
  - A buyer or a third party asks "who owns this?". The MIT grant, the Gumroad sale and the Terms of Sale all rest on that.
  - All git commits are by one account, and 17 of 18 carried a `Co-Authored-By: Claude` trailer (per the earlier audit).
  - The copyrightability of AI-generated code is unsettled, which can weaken enforcement of the MIT or key-gate terms against copyists.
  - The grant itself is not affected, because MIT only needs the notice retained.
- **Likelihood: M.** Impact: L.
- **Mitigation.** `LICENSE` and `OculOS/LICENSE` both say "Copyright (c) 2026 Humanity contributors" (consistent).
- **Remaining risk.**
  - An informal holder name.
  - Who owns the human-authored parts.
  - Whether the AI-assisted portions are protectable **[ATTORNEY]**.
- **Fix.** Replace "Humanity contributors" in `LICENSE` and `OculOS/LICENSE` with the seller's legal name or registered DBA, plus "and contributors".

### 8. Local app and notice state for each of the four apps is inconsistent about FluidAudio content
- **Scenario.**
  - `THIRD_PARTY_NOTICES.md` is shipped identically in all four apps, including OculOS and ManOS, which do not link FluidAudio.
  - The file says "FluidAudio sections apply to Humanity and Murmur only". That is accurate.
  - A scanner could still flag an apparent mismatch; this is over-inclusion, not a violation.
  - The reverse case (an app that links more than the notice lists) is the real risk: Humanity links AIKit and others.
  - I did not find any other third-party Swift packages. Only FluidAudio is a remote dependency (`Humanity/Package.resolved`).
- **Likelihood: L.** Impact: L.
- **Mitigation.** The "applies to Humanity and Murmur only" line in `THIRD_PARTY_NOTICES.md`.
- **Remaining risk.** None material.
- **Fix.** None required. Optionally add a one-line `Package.resolved` check to CI that fails if a new remote dependency appears without a notices change.

### 9. No snippet-level scan has been run
- **Scenario.** A holder finds verbatim code (for example in `LicenseKit`, `HotKey.swift` or the CGEvent tap code) that matches a GPL or unlicensed source. My grep found no markers, but grep cannot find silent copying, and AI-generated code can reproduce training snippets.
- **Likelihood: L.** Impact: M.
- **Mitigation.** The earlier audit and my grep both found nothing. The `ponytail:` markers show all internal copies are first-party.
- **Remaining risk.** Unscanned snippets.
- **Fix.** Run `scancode -clpieu --json-pp out.json .` (ScanCode Toolkit) on the repo and on the FluidAudio checkout before the first sale. Keep the output in `legal/`.

## Items for an attorney
- Gaze360 secondary-liability exposure from advertising and shipping a "Load Model…" feature (finding 2).
- Icon similarity to Apple's symbols and trademarks (finding 3).
- Copyright ownership and AI-assisted authorship, and the effect on MIT enforcement (finding 7).
- WeSpeaker and VoxCeleb upstream terms for the downloaded weights (finding 5).
- Whether selling an MIT-licensed product behind a key gate raises any attribution-clause complaint from Apache or MIT holders. I think it does not, because those licenses allow charging for copies, but have it confirmed.

## 5-line summary
1. Current source tree and the built `Humanity.app` have complete, matching notices (Apache NOTICE block, MIT crates, CC BY diarization attribution), shipped in all four `build-app.sh` scripts.
2. Top risk: `dist/*-1.0.0.dmg` (00:07) contain OLD notices missing about 40 lines (the NVIDIA and FluidInference NOTICE block, MIT crates). Rebuild before uploading to Gumroad, and add a notices `cmp` check to `scripts/package.sh` and CI.
3. The Gaze360-trained optional CNN is still advertised in `OculOS/README.md:8` as a feature of a paid app. The script prompt and warnings are good, but reword the feature and keep the model out of the product.
4. The Humanity (open-arms figure) and ManOS (raised hand) icons are visibly close to the SF Symbols `figure.arms.open` and `hand.raised.fill`. Redraw them, then clear `build/AppIcon.icns`.
5. No copied third-party code found, but ScanCode has not been run. The LuxTts bundle is not shipped and needs a guard. The copyright holder is "Humanity contributors". Several items are flagged for an attorney.
