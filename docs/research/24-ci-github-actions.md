# 24 — CI for macOS Swift packages on GitHub Actions

## TL;DR

- Standard GitHub-hosted macOS runners are **free and unmetered on public repos**. `macos-15` and `macos-26` are Apple silicon (M1) VMs with 3 vCPU, 7 GB RAM and 14 GB of disk. On private repos macOS costs about $0.062/min.
- **Don't target `macos-14`.** It has been deprecated since 2026-07-06 and stops working on 2026-11-02. `macos-latest` moved to `macos-26` between mid-June and mid-July 2026. Pin explicit labels: `macos-15` (Xcode 16.4 is the default, and 26.x is installed) and `macos-26`.
- CI can run `swift build`, `swift test`, the `.app` bundling script, ad-hoc codesigning and artifact upload. It cannot use a camera, get TCC grants (Camera, Accessibility, Post Event), or rely on GPU/ANE-accelerated inference.
- Test the logic in GazeKit (calibration, filters, geometry) using synthetic or replayed feature streams, as report 10 recommends. Vision-on-image tests should be optional and tolerance-based.

## Key findings

- **Runner images.** The `macos-15-arm64` image runs macOS 15.7 with Xcode 16.0–16.4 (16.4 is the default) and 26.0.1–26.3. It includes **SwiftFormat 0.63** (nicklockwood's, which is *not* Apple's `swift-format`) and xcbeautify. **SwiftLint is not preinstalled.** Apple's `swift-format` ships in the Swift 6 toolchain as `swift format` (Xcode 16+).
- **Selecting Xcode.** Run `sudo xcode-select -s /Applications/Xcode_16.4.app`, or use `maxim-lobanov/setup-xcode`. Full Xcode includes Swift Testing, so the Makefile's Command Line Tools `TEST_FLAGS` workaround is a no-op there. That is harmless.
- **Hardware limits.** GitHub's arm64 macOS runners are VMs on Apple's Virtualization framework. Nested virtualization and Metal Performance Shaders are documented as unsupported. *Uncertain:* the Neural Engine is not exposed to guest VMs as far as I know. Vision and Core ML should fall back to CPU (Core ML falls back automatically). Expect face and hand requests to *work* but run slowly, and possibly to give slightly different numbers than on a physical Mac. I found no authoritative statement either way, so verify with a canary test.
- **No camera.** `AVCaptureDevice.default(for: .video)` returns nil in CI. Any code path that opens a capture session at startup must be kept out of tests.
- **Caching.** VisionGaze has no SwiftPM dependencies, so caching `.build` saves little, and stale caches cause flaky incremental builds across Xcode versions. Cache it only after dependencies are added, keyed on the Xcode version plus `Package.resolved`.

## How to program it

This is a proposed `.github/workflows/ci.yml`. It is **not** created in the repo.

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-test:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: macos-15
            xcode: "16.4"
          - os: macos-26
            xcode: "26.3"   # adjust to what the image README lists
    runs-on: ${{ matrix.os }}
    timeout-minutes: 30
    defaults:
      run:
        working-directory: VisionGaze
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ matrix.xcode }}.app
      - run: swift --version
      - name: Cache .build
        uses: actions/cache@v4
        with:
          path: VisionGaze/.build
          key: spm-${{ matrix.os }}-${{ matrix.xcode }}-${{ hashFiles('VisionGaze/Package.swift', 'VisionGaze/Package.resolved') }}
      - name: Build
        run: swift build -c debug
      - name: Test
        env:
          OCULOS_CI: "1"          # tests can skip camera/TCC/perf-sensitive cases
        run: swift test --parallel
      - name: Build .app (release, ad-hoc signed)
        run: ./scripts/build-app.sh release
      - name: Verify bundle
        run: |
          codesign --verify --deep --strict build/VisionGaze.app
          plutil -lint build/VisionGaze.app/Contents/Info.plist
      - name: Zip app
        run: ditto -c -k --keepParent build/VisionGaze.app build/VisionGaze-${{ matrix.os }}.zip
      - uses: actions/upload-artifact@v4
        with:
          name: VisionGaze-${{ matrix.os }}
          path: VisionGaze/build/VisionGaze-${{ matrix.os }}.zip
          retention-days: 14

  lint:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -s /Applications/Xcode_16.4.app
      - name: swift-format (Apple, bundled with toolchain)
        run: swift format lint --recursive --strict VisionGaze/Sources VisionGaze/Tests
      - name: SwiftLint
        run: |
          brew install swiftlint
          cd VisionGaze && swiftlint lint --strict --reporter github-actions-logging
```

In Swift Testing, gate hardware-dependent tests with `.enabled(if: ProcessInfo.processInfo.environment["OCULOS_CI"] == nil)`. In XCTest, use `XCTSkipIf`.

## Recommendations for oculOS

1. Use one workflow per app package, filtered by `paths:`, or matrix over package directories as more apps land. Use `macos-15` plus `macos-26` and never `macos-latest`, so image flips can't break builds without warning.
2. Put the core logic in GazeKit and test it with recorded JSON feature streams (landmarks and pupil points). Add a single "Vision smoke test" that runs face landmarks on a bundled, licensed face image, and assert only that a face is detected. Don't assert exact coordinates.
3. Start linting with `swift format lint` (no install needed), then add SwiftLint if the team wants its rules. Commit a `.swift-format` config.
4. Make ad-hoc-signed `.app` zips the CI artifact. Notarization with a Developer ID belongs in a separate, tag-triggered release workflow that uses secrets.

## Pitfalls

- `macos-14` workflows will start **erroring after 2026-11-02**.
- 7 GB of RAM and 3 vCPUs make `--parallel` release builds slow. Set `timeout-minutes`.
- ANE/GPU timings on runners mean nothing, so don't write latency assertions (uncertain whether the ANE is present, but treat it as absent).
- TCC prompts can't be answered in CI. Never call `CGEvent.post`, `AVCaptureDevice.requestAccess`, or AX APIs from tests.
- `make-icon.swift` runs at build time. If it uses AppKit drawing it should work headless, but that is unverified.
- The two tools named SwiftFormat and swift-format are different, with different config files.

## Sources

- https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md
- https://github.blog/changelog/2024-01-30-github-actions-introducing-the-new-m1-macos-runner-available-to-open-source/
- https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/
- https://github.com/actions/runner-images/issues/13518 (macOS 14 deprecation)
- https://github.com/actions/runner-images/issues/14167 (macos-latest becomes macos-26)
- https://github.com/orgs/community/discussions/69211 (M1 runner limitations: no nested virtualization)
- https://sengi.run/blog/github-actions-pricing
