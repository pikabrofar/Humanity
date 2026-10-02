# Open-source and licensing audit: sentidoS 1.0.0

Research-engineering audit, not legal advice. Date: 2026-10-01. Repo state: commit `e098368` (plus the untracked `.github/`). Shipped artifacts checked: `dist/{sentidoS,manoS,bocaS,ojoS}-1.0.0.dmg`, which were mounted read-only and their contents listed.

## 0. Method

- Read every `Package.swift` and `Package.resolved`. The only remote dependency is **FluidAudio 0.17.4** at `21493f8`, used by MeetingKit and so by bocaS and sentidoS. Every other package is a local path package in this repo.
- Read the FluidAudio checkout at `sentidoS/.build/checkouts/FluidAudio`, including `LICENSE`, `ThirdPartyLicenses/*`, both manifests and its sources. The local toolchain is Swift 6.3.3, so SwiftPM uses `Package@swift-6.2.swift`. In that manifest the `NemoTextProcessing` trait is on by default and MeetingKit does not turn it off, so the Rust xcframework is linked.
- Inspected the release binary `sentidoS.app/Contents/MacOS/sentidoS` (24.9 MB):
  - `otool -L` shows only Apple system libraries and the OS Swift runtime. Nothing third-party is linked dynamically.
  - `strings` shows the statically linked Rust code: `rustfst-1.3.1`, `flate2-1.1.9`, `miniz_oxide-0.8.9`, `nom-7.1.3`, `anyhow-1.0.103` and `lazy_static-1.5.0`, plus Rust `std` (`/rustc/48a229ce…`). It also shows FluidAudio's TTS and Japanese-G2P types (`JapaneseCutlet`, `KokoroAne*`, `LuxTts*`). Dead-stripping does not remove them.
- Took the full Rust dependency list from `text-processing-rs` v0.3.1 `Cargo.lock` and looked up each crate's license on the crates.io API. Pulled copyright lines from the upstream LICENSE files.
- Checked the Hugging Face cache at `~/Library/Application Support/FluidAudio/Models/speaker-diarization/`, its `provenance.json`, and the repo's `NOTICE.md`.
- Grepped all 186 tracked files for license headers, SPDX tags, URLs, and phrases such as "adapted / ported / copied / based on / et al." I also listed every SF Symbol name and every non-code asset.
- **Not done:** I ran no snippet-fingerprint scan. Before 1.0 GA, run [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit) (`scancode -clpieu --json-pp out.json .`) over the repo and the FluidAudio checkout.

## 1. Findings, ranked

| # | Severity | Finding | Fix |
|---|---|---|---|
| 1 | **Must fix before selling** | The sentidoS, manoS and bocaS app icons are SF Symbols (`figure.arms.open`, `hand.point.up.left.fill`, `waveform`) drawn by `*/scripts/make-icon.swift`. Apple's SF Symbols terms say you "may not use SF Symbols — or glyphs that are substantially or confusingly similar — in your app icons, logos, or any other trademark-related use". SF Symbols count as "system-provided images" under the Xcode and Apple SDKs Agreement. Sources: [HIG: SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), [Xcode and Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf). | Redraw these three glyphs as original `NSBezierPath` art, as ojoS's icon already does, and rebuild `build/AppIcon.icns`. Remember that `build-app.sh` reuses a cached `.icns`. SF Symbols *inside* the UI are fine. |
| 2 | **Must fix (notice gap)** | `THIRD_PARTY_NOTICES.md` is missing notices for code that is statically linked into bocaS and sentidoS: the text-processing-rs `NOTICE` file (Apache-2.0 §4(d)), the MIT-only Rust crates (nom, generic-array, ordered-float, simd-adler32), Rust `std`, and the Japanese G2P ports (cutlet, Convert-Numbers-to-Japanese, misaki). | Paste in the block in §3.3. |
| 3 | Should fix | ojoS `convert_gaze_model.py` writes `model.license = "MIT (…). Trained on Gaze360."`. That label understates the restriction: Gaze360's terms forbid commercial use of "models trained on dataset". The paid app also offers **Settings → Gaze CNN → Load Model…**. | See §2, row L. Change the metadata, add an explicit acknowledgement gate to the script, and never host or bundle a converted model. |
| 4 | Should fix | FluidAudio's resource bundle `FluidAudio_FluidAudio.bundle` (the LuxTTS lexicon, 982 KB) is **not** copied into the apps today, because `build-app.sh` copies only the executable. That lexicon was built by probing espeak-ng, which is GPL-3.0. Its copyright status is unclear. | Keep it out. If a future build script starts copying `*.bundle` (a common fix for `Bundle.module` crashes), audit it first. Better: ask FluidAudio upstream to make TTS a separate product, or add a CI check that the shipped `.app` has no `FluidAudio_FluidAudio.bundle`. |
| 5 | Should fix | The copyright holder is "sentidoS contributors" (root) and "ojoS contributors" (`ojoS/LICENSE`). "Contributors" is not a legal person. That weakens a sale contract and makes any later relicensing harder to document. | Use `Copyright (c) 2026 [OWNER LEGAL NAME OR REGISTERED PSEUDONYM/DBA] and contributors` in both files and keep them identical. |
| 6 | Should fix (FTC) | The README says "Download sentidoS … for free" but the app does not run without a paid key. Under the FTC's [Guide Concerning Use of the Word "Free" (16 CFR Part 251)](https://www.ecfr.gov/current/title-16/chapter-I/subchapter-B/part-251) and [FTC Act §5 (15 U.S.C. §45)](https://www.law.cornell.edu/uscode/text/15/45), the conditions of a "free" offer must be clear and conspicuous. | Say "Free download; a license key ($5+, pay what you want) unlocks the app. Or build it yourself from MIT source." Use the same wording on the Gumroad page and in GitHub release notes. |
| 7 | Low | `ThirdPartyLicenses/NemoTextProcessing-LICENSE.md` in FluidAudio says text-processing-rs **v0.3.0**, but the linked binary is **v0.3.1**. | Name v0.3.1 in our notices. |
| 8 | Info | manoS and ojoS ship the full notices file, including FluidAudio, which they don't contain. | Over-inclusion is harmless. Optionally add one line: "FluidAudio sections apply to sentidoS and bocaS only." |

## 2. Component inventory

Key: **Ship** describes how a component reaches users. "Linked" means it is compiled into the Mach-O. "DL" means the user's machine downloads it at runtime from a third party. "Not shipped" means it never leaves the repo or build directory. "Attrib" lists what must be credited. "Src" asks whether the license requires source disclosure. "Mod" lists the conditions on modified versions. "Notice" says where the notice must appear. "MIT-compat" asks whether the component can ship inside an MIT-licensed product.

| ID | Component (version) | Ship | License | Attrib / Notice | Redistribution | Src | Commercial | Mod | MIT-compat |
|---|---|---|---|---|---|---|---|---|---|
| A | sentidoS first-party code (all 7 packages, scripts) | Linked; source on GitHub | [MIT](https://opensource.org/license/mit) | Keep the copyright and permission notice in "all copies or substantial portions". Done via `Resources/LICENSE` and `Credits.rtf` | Free, including sale | No | Yes | Free | n/a |
| B | FluidAudio 0.17.4 (FluidInference) | Linked (static) | [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) | §4(a): give recipients a copy of the license. §4(c) applies to source. FluidAudio has no NOTICE file | Yes | No | Yes, with an express patent grant (§3) | §4(b): mark changed files (not modified today) | Yes (Apache-2.0 inside an MIT product is fine. The Apache terms still govern that component) |
| C | VBx clustering logic (BUT Speech@FIT) inside FluidAudio | Linked | Apache-2.0 | "Copyright 2021-2024 BUT Speech@FIT" | Yes | No | Yes | §4(b) | Yes |
| D | fastcluster (`fastcluster_internal.hpp`), Müllner and Google | Linked | [BSD-2-Clause](https://opensource.org/license/bsd-2-clause) | Binary form must reproduce the copyright notice, conditions and disclaimer in the docs. **Present** | Yes | No | Yes | Free | Yes |
| E | MachTaskSelfWrapper (FluidAudio's own C) | Linked | Apache-2.0 (FluidAudio) | Covered by B | Yes | No | Yes | §4(b) | Yes |
| F | Japanese G2P Swift ports in FluidAudio: cutlet (P. O'Leary McCann), Convert-Numbers-to-Japanese (D. Wilson), misaki (hexgrad). Plus a "MeCab-compatible" tokenizer | Linked (`JapaneseCutlet` is in the binary) | MIT, MIT, Apache-2.0. The tokenizer is described as a reimplementation; MeCab itself is GPL/LGPL/**BSD** at the user's option | MIT notices for cutlet and Convert-Numbers. Apache for misaki. **Missing from our notices** | Yes | No | Yes | Free / §4(b) | Yes. Low risk on the tokenizer, because MeCab's BSD option is available |
| G | NemoTextProcessing.xcframework = text-processing-rs **v0.3.1** (FluidInference), `fst-engine` | Linked (Rust staticlib, ~8 MB/slice) | Apache-2.0 **with a NOTICE file** | §4(d): reproduce the NOTICE text in a NOTICE file, the docs, or the app's credits display. **Missing** | Yes | No | Yes | §4(b) | Yes |
| G1 | NVIDIA NeMo Text Processing grammars (compiled FSTs, pinned `1f12635`) embedded in G | Linked | Apache-2.0, © NVIDIA CORPORATION & AFFILIATES | Present (name only). Upstream has no NOTICE file | Yes | No | Yes | §4(b) | Yes |
| G2 | Rust crates in G, dual or multi-licensed: rustfst, flate2, anyhow, bimap, bitflags, typenum, itertools, either, minimal-lexical, num-traits, rand, rand_core, rand_chacha, ppv-lite86, getrandom, libc, cfg-if, serde/serde_core, crc32fast, lazy_static (MIT OR Apache-2.0); miniz_oxide (MIT OR Zlib OR Apache-2.0); adler2 (0BSD OR MIT OR Apache-2.0); zerocopy (BSD-2 OR Apache-2.0 OR MIT); memchr (Unlicense OR MIT); superslice (Apache-2.0 only) | Linked | Choose **Apache-2.0** wherever it is offered. The Apache text is already in our notices | Copyright lines are good practice. Apache needs only the license copy | Yes | No | Yes | — | Yes |
| G3 | **MIT-only** crates in G: nom 7.1.3, generic-array 1.4.3, ordered-float 5.3.0, simd-adler32 0.3.9 | Linked (nom confirmed in the binary; the others are in the dependency graph) | MIT | Copyright line plus MIT text. **Missing** | Yes | No | Yes | Free | Yes |
| G4 | Rust standard library (rustc `48a229ce`) | Linked | MIT OR Apache-2.0, "Copyright (c) The Rust Project Contributors" ([COPYRIGHT](https://github.com/rust-lang/rust/blob/master/COPYRIGHT)) | One line. **Missing** | Yes | No | Yes | — | Yes |
| H | FluidAudio `TTS/LuxTts/G2p/Resources` (espeak-probed lexicon) | **Not shipped** (built into `.build/…/FluidAudio_FluidAudio.bundle`, never copied) | Upstream ships it under Apache-2.0, but the data is derived from espeak-ng ([GPL-3.0](https://github.com/espeak-ng/espeak-ng/blob/master/COPYING)) | — | — | — | — | — | Unclear. Keep it out (finding 4) |
| I | FluidAudio CLI, tests, fixtures (real recordings), `banner.png`, `Documentation/` | Not shipped | Apache-2.0 / various | — | — | — | — | — | n/a |
| J | Speaker diarization models: [FluidInference/speaker-diarization-coreml](https://huggingface.co/FluidInference/speaker-diarization-coreml). Files used: `Segmentation`, `FBank`, `Embedding`, `PldaRho` `.mlmodelc`, `plda-parameters.json`, `xvector-transform.json`, `provenance.json` | **DL** on first meeting, straight from Hugging Face to `~/Library/Application Support/FluidAudio/Models/` | "scoped" [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode.en). Covers exactly the Community-1 files above; the legacy `pyannote_segmentation`/`wespeaker` files are out of scope and **not used** | [NOTICE.md](https://huggingface.co/FluidInference/speaker-diarization-coreml/blob/main/NOTICE.md) asks you to identify pyannote, WeSpeaker, BUT Speech@FIT and Fluid Inference, keep the three citations, link CC BY 4.0, and say the files are modified Core ML conversions. **Present and correct** | We do not redistribute the models: the user's Mac fetches them from HF. CC BY §3 attribution is triggered by "Sharing", so our notice is good practice rather than strictly required | No | Yes. Upstream [pyannote community-1](https://huggingface.co/pyannote/speaker-diarization-community-1) is CC BY 4.0; its HF gate only asks for contact details. BUT licensed the PLDA files under CC BY 4.0 "including commercial use" | Converted by FluidInference. We don't modify them | Yes, but see the CC BY §2(a)(5)(B) note in §4 |
| K | Other FluidAudio model repos referenced in the binary (Parakeet, Sortformer, Nemotron, Kokoro, PocketTTS, and others) | Not downloaded: MeetingKit calls only `OfflineDiarizerManager` | Various, some under NVIDIA model licenses | — | — | — | Check before use | — | Re-audit before calling any other FluidAudio API |
| L | ojoS CNN script: `make-cnn-model.sh` + `convert_gaze_model.py` (ours, MIT). Downloads [MobileGaze](https://github.com/yakhyo/gaze-estimation) code (MIT), its `.pt` weights, PyTorch/torchvision/coremltools (BSD-3) | **Not shipped**. Runs only when the user invokes it. No model in repo or DMG | Code: MIT. **Weights: trained only on [Gaze360](https://github.com/erkil1452/gaze360/blob/master/LICENSE.md)**, which is "research purposes" only, may "not be used nor included in commercial applications in any form", reaches "models trained on dataset", forbids redistribution, and requires an ICCV 2019 citation | Gaze360 citation if anything is "publicly shared" | Weights: no, under the dataset terms (MobileGaze redistributes them anyway; that risk sits upstream) | No | **No** under the dataset terms. sentidoS is a commercial application | — | The script is compatible. Using the weights in the paid app is the problem |
| M | App icons from `*/scripts/make-icon.swift` | Shipped (`AppIcon.icns`) | ojoS: original vector art (ours, MIT). **sentidoS/manoS/bocaS: SF Symbols**, under the Xcode and Apple SDKs Agreement | — | SF Symbols terms bar use in app icons | — | — | — | **No** for those three (finding 1) |
| N | SF Symbols in the UI (about 45 names, e.g. `record.circle`, `waveform`, `lock.shield`). No Apple-product glyphs | System-rendered | Xcode and Apple SDKs Agreement | None | Apple platforms only | — | Yes | Don't alter Apple-product symbols | Yes |
| O | Apple frameworks (Speech, FoundationModels [weak], AVFoundation, Vision, ScreenCaptureKit, CoreML, and others) and the Swift runtime (`/usr/lib/swift`) | OS-provided, dynamic | Apple SDK agreement. Swift runtime is Apache-2.0 with the Runtime Library Exception, so a binary needs no attribution | None | n/a | — | Yes. FoundationModels use is subject to Apple's [acceptable-use requirements](https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/) | — | Yes |
| P | Fonts, images, sample data | None in the repo. Only system fonts. Tests use synthetic vectors and names ("Alice") | — | — | — | — | — | — | n/a |
| Q | Copied snippets | None found from third parties. Internal copies are marked `// ponytail: copied from ojoS…` and are first-party. `OneEuroFilter.swift` is a short independent implementation of a published algorithm (Casiez et al., CHI 2012). Algorithms are not copyrightable ([17 U.S.C. §102(b)](https://www.law.cornell.edu/uscode/text/17/102)), and nothing in the file matches reference-implementation comments | — | — | — | — | — | — | Yes. Confirm with ScanCode |
| R | `research/*.md` | Repo only | Ours. Quotes and links to third parties | Make sure any verbatim quotations are short | — | — | — | — | Yes |
| S | CI: `actions/checkout` (MIT), GitHub runners | Not shipped | MIT | — | — | — | — | — | n/a |
| T | Services, not components: Gumroad license API, AI provider APIs (Groq, Gemini, OpenAI, Anthropic, and others; BYO key), Hugging Face hosting | Network | Each service's terms | — | — | — | — | — | n/a. Covered in the EULA |

**Git authorship:** every commit is by one GitHub account (`pikabrofar`). 17 of the 18 commits carry a `Co-Authored-By: Claude` trailer. There are no outside contributors, which matters for §6.

## 3. `THIRD_PARTY_NOTICES.md`: verification

### 3.1 Correct as written
- The FluidAudio Apache-2.0 attribution and full license text.
- The VBx line.
- The fastcluster BSD-2 full text, with both copyright lines.
- The NVIDIA NeMo, rustfst and flate2 lines.
- The speaker-diarization models section. It meets every item in Fluid Inference's NOTICE.md: it names pyannote, WeSpeaker, BUT Speech@FIT and Fluid Inference, keeps the three citations, links CC BY 4.0, and says the files are modified Core ML conversions.
- Shipping: `build-app.sh` copies `LICENSE` and `THIRD_PARTY_NOTICES.md` into `Contents/Resources` and also renders them as `Credits.rtf`, which shows in the About panel. That satisfies BSD-2's "documentation and/or other materials" and Apache §4(a)/(d)'s "display generated by the Derivative Works". All four 1.0.0 DMGs contain both files.

### 3.2 Incorrect or incomplete
1. "NemoTextProcessing / text-processing-rs (Apache License 2.0)" has no version and **leaves out the NOTICE contents**. Apache §4(d) requires them because the upstream repo has a `NOTICE` file.
2. "(MIT OR Apache-2.0)" for rustfst/flate2 is fine. The notices don't say which license we chose, and they leave out MIT-only crates and Rust `std`.
3. There is no entry for the Japanese G2P ports (F), which are compiled in.
4. The heading text "Compiled sentidoS apps include or download" is accurate, but the file should say which apps contain which components.
5. Optional: add the CC BY 4.0 §5 disclaimer pointer and the model snapshot (`artifact_snapshot 1ed7a662…` from `provenance.json`) so the attribution is reproducible.

### 3.3 Exact text to add (paste after the FluidAudio section)

```markdown
FluidAudio sections apply to sentidoS and bocaS only; ojoS and manoS do not contain FluidAudio.

### FluidAudio Japanese text frontend (compiled in)
- cutlet (Swift port), Copyright (c) 2020 Paul O'Leary McCann. MIT License.
- Convert-Numbers-to-Japanese (Swift port), Copyright (c) 2018 David Wilson. MIT License.
- misaki (hexgrad/misaki), Apache License 2.0.

### NemoTextProcessing (text-processing-rs v0.3.1), statically linked
NOTICE (reproduced as required by Apache License 2.0, section 4(d)):

    text-processing-rs
    Copyright 2026 FluidInference

    This product is a Rust port of NVIDIA NeMo Text Processing
    (https://github.com/NVIDIA/NeMo-text-processing), which is licensed
    under the Apache License, Version 2.0.

       Copyright (c) NVIDIA CORPORATION & AFFILIATES.
       Licensed under the Apache License, Version 2.0.

    In addition, when built with the optional `fst-engine` feature, this
    product includes and redistributes artifacts derived from NVIDIA NeMo
    Text Processing (Apache-2.0, pinned commit
    1f1263579fe57ba7ed783cad3dddee710fcc5064):

       * the compiled weighted-FST grammars under `grammars/` (exported from
         NeMo's Pynini source), and
       * the text-normalization test fixtures under `tests/fixtures/`
         (copied from, or regenerated as the deterministic output of, NeMo's
         `data_text_normalization` test cases).

    This product's binary distributions (e.g. the published xcframework) also
    statically link third-party libraries. See THIRD-PARTY-LICENSES.md for the
    full list and their licenses.

Rust components linked into NemoTextProcessing. Where a choice of license is
offered, sentidoS uses them under the Apache License 2.0 (text below):
rustfst, flate2, miniz_oxide, adler2, crc32fast, anyhow, bimap, bitflags,
typenum, itertools, either, minimal-lexical, num-traits, rand, rand_core,
rand_chacha, ppv-lite86, getrandom, libc, cfg-if, serde, zerocopy, lazy_static,
superslice; memchr (under MIT); and the Rust standard library, Copyright (c)
The Rust Project Contributors.

The following are MIT-licensed (MIT text below):
- nom, Copyright (c) 2014-2019 Geoffroy Couprie
- generic-array, Copyright (c) 2015 Bartłomiej Kamiński
- ordered-float, Copyright (c) 2015 Jonathan Reem
- simd-adler32, Copyright (c) 2021 Marvin Countryman
- memchr, Copyright (c) 2015 Andrew Gallant
- cutlet and Convert-Numbers-to-Japanese (above)

## MIT License (for the third-party components marked MIT above)
Permission is hereby granted, free of charge, to any person obtaining a copy
… [full standard MIT text, identical to LICENSE, without the sentidoS copyright line] …
```

- All copyright lines above were checked against the upstream LICENSE files on 2026-10-01.
- Better: generate this block mechanically with [`cargo-about`](https://github.com/EmbarkStudios/cargo-about) from `text-processing-rs` at tag `v0.3.1` (`--features fst-engine,ffi --target aarch64-apple-darwin`). Regenerate it on every FluidAudio bump.
- Add a CI check that diffs `Package.resolved` against a pinned notices version.

## 4. Is selling binaries while publishing MIT source compatible?

**Yes.**
- **MIT:** it grants the right to "sell copies of the Software". The [Open Source Definition #1](https://opensource.org/osd) forbids licenses that restrict sale, and the FSF says the same ([Selling Free Software](https://www.gnu.org/philosophy/selling.html)).
- **Apache-2.0:** §2 grants the right to "distribute the Work … in Source or Object form", and §4 conditions that only on notices. Apache-2.0 has no source-disclosure duty.
- **BSD-2:** binary redistribution is allowed if the notice ships.
- **CC BY 4.0:** commercial use is allowed.

Nothing in the shipped graph is copyleft. The only GPL-adjacent item (H) is not shipped.

What you must do, and already mostly do:
- ship the notices with each binary (§3);
- don't use upstream trademarks to imply endorsement (Apache §6);
- under CC BY 4.0 §2(a)(5)(B), don't impose "additional or different terms" on the models. The EULA must exclude the models and every third-party component from its restrictions. The license-key gate restricts *our* app, not the models, which anyone can download from HF directly, so it is not an "Effective Technological Measure" on the licensed material.

## 5. Is MIT plus a paid license key coherent?

**Yes, if it is framed honestly.** MIT gives everyone the right to build, modify, remove the key check (`License.required = false` is one line), redistribute, and even **sell** their own builds. Any of these is lawful, and the key cannot and should not try to stop them. So:

- **What the key sells.** The key buys the convenience build: a CI-built, signed and checksummed universal DMG, a one-key unlock for every app, future updates and builds, and support. It also funds development. Say exactly this on Gumroad, in the README and in the activation window. A suggested line:
  > "sentidoS is MIT open source. Build it yourself for free, or buy a key ($5+) for the ready-made app, updates and support."
- **The EULA's scope.** The EULA can govern the purchase, the key (no sharing or publishing of keys) and the official binary as delivered. It must say it **does not limit any MIT or third-party license right**. MIT has no "no further restrictions" clause (GPL §10 does), so contract terms on your own binary sit alongside it. They bind buyers only, contractually, and they do not bind the source.
- **Don't threaten DMCA §1201.** Do not invoke [17 U.S.C. §1201](https://www.law.cornell.edu/uscode/text/17/1201) against people who bypass the check. Upstream MIT expressly permits modifying the code, so a claim would be weak and would damage trust.
- **Trademark is the real moat.** MIT grants no trademark rights; Apache §6 is the analogue for Apache components.
  - Add a `TRADEMARKS.md`: forks and rebuilds must not be distributed or sold as "sentidoS", "ojoS", "manoS" or "bocaS", or with those icons, and must not imply that they are official. Unofficial builds must be named and marked as unofficial.
  - "sentidoS" is a common word, so it is weak as a mark. Consider a USPTO knockout search and filing for the suite name or a distinctive logo ([USPTO trademark basics](https://www.uspto.gov/trademarks/basics)). This is also why finding 1 (original icons) matters.
- **Consumer law.**
  - Disclose the conditions of the "free" download (finding 6).
  - Disclose that the app contacts Gumroad weekly and stops working 60 days after its last successful check, and that refunded or disputed keys are revoked (`LicenseKit/License.swift`). Commit to a key-free build if Gumroad's verify API goes away. Without that disclosure and commitment, a paid key that silently stops working invites a [M.G.L. c. 93A](https://malegislature.gov/Laws/GeneralLaws/PartI/TitleXV/Chapter93A/Section2) unfairness claim.

## 6. Keep MIT or change it?

**Recommendation: keep MIT** for the code, and add a TRADEMARKS.md, the clearer paid-binary framing, and a DCO for future contributions.

| Option | Upside | Downside | Fit |
|---|---|---|---|
| **MIT (keep)** | Most trust; "open source" claims stay true; the EULA can sit alongside it; contributors and companies are comfortable; matches the privacy positioning ("don't take our word for it") | Anyone may sell a rebuilt copy. Revenue depends on convenience and goodwill (the VoiceInk-style model) | **Best** at $5 PWYW |
| GPL-3.0 | Stops closed-source proprietary forks. Compatible with Apache-2.0/BSD/MIT deps ([ASF](https://www.apache.org/licenses/GPL-compatibility.html)). VoiceInk sells binaries under GPL | Still allows free rebuilds and resale. GPL §10 forbids further restrictions, so the EULA shrinks to sale terms and disclaimers. Some contributors avoid copyleft | Neutral |
| Source-available ([PolyForm Shield/Noncommercial](https://polyformproject.org/licenses/), [FSL](https://fsl.software/), [BSL 1.1](https://mariadb.com/bsl11/), [Elastic 2.0](https://www.elastic.co/licensing/elastic-license)) | Can forbid competing resale or commercial use. FSL and BSL convert to open source after 2–4 years | You can no longer call it "open source" (OSD fails), and claiming otherwise is a §5/93A deception risk. Contributors are less willing. It loses the trust story. Enforcement relies on copyright, which may be **thin**: much of the code is AI-assisted (every commit is co-authored by Claude), and the [USCO Copyrightability Report (Jan 2025)](https://www.copyright.gov/ai/Copyright-and-Artificial-Intelligence-Part-2-Copyrightability-Report.pdf) and [*Thaler v. Perlmutter*, D.C. Cir. 2025](https://media.cadc.uscourts.gov/opinions/docs/2025/03/23-5233.pdf) protect only human-authored expression | Poor |
| Dual (e.g. GPL or AGPL + commercial) | Classic for SDKs: companies pay to avoid copyleft | sentidoS is an end-user app, not a library, so there are few buyers for a commercial license. It needs a CLA | Poor |

**What changing would mean:**
- **Past releases stay MIT.** Commits up to `e098368` and the 1.0.0 DMGs remain MIT for everyone who has them. MIT has no termination clause, so treat the grant as irrevocable in practice. Anyone can fork the last MIT commit and keep developing it under MIT. A change only affects code written afterwards.
- **Contributors.** Today there is one human author, so the owner can relicense future versions unilaterally. Once outside PRs land, [GitHub ToS §D.6](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#6-contributions-under-repository-license) makes them "inbound = outbound" under MIT. MIT lets you sublicense those contributions under a stricter license, but contributors may object, and re-licensing *their* code under a different open-source license is cleaner with consent. Before accepting outside PRs:
  - add a [DCO](https://developercertificate.org/) if you will stay MIT; or
  - add a CLA granting relicensing rights if you might ever dual-license or go source-available.
- **Mechanics.** Change `LICENSE` at a tagged commit, update `Credits.rtf` and the README "License" sections (root and each module), update the Gumroad page, and add a CHANGELOG entry that names the last MIT commit.

## 7. Release checklist (licensing)
- [ ] Redraw the sentidoS, manoS and bocaS icons without SF Symbols.
- [ ] Add the §3.3 block, regenerated with cargo-about.
- [ ] Fix the copyright holder line in both LICENSE files.
- [ ] Fix the "free" wording in the README, Gumroad page and release notes.
- [ ] ojoS CNN: set `model.license` to `"Code MIT; weights trained on Gaze360 — non-commercial research only; do not redistribute"`. Make `make-cnn-model.sh` require `ACCEPT_GAZE360_TERMS=1` and print the Gaze360 terms URL. Add the Gaze360 citation to the README. Never host or bundle a converted model.
- [ ] Add a CI check that the shipped `.app` contains no `FluidAudio_FluidAudio.bundle`.
- [ ] Run ScanCode. Re-audit whenever FluidAudio changes or another FluidAudio model or API is used.
- [ ] Add `TRADEMARKS.md` and a DCO.
