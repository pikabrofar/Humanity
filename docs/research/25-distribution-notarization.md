# 25 — Distribution: signing, notarization, Gatekeeper, updates

## TL;DR

- **Ad-hoc signing (`codesign -s -`) is fine for local builds, but it's a poor way to ship.** On macOS 15+, a quarantined ad-hoc app can't be opened with right-click → Open. Users must try to launch it, then click Privacy & Security → "Open Anyway" and enter an admin password. Each ad-hoc rebuild also changes the code identity, so TCC grants for Camera and Post-Event reset.
- **Ship a Developer ID build** ($99/yr): hardened runtime, `com.apple.security.device.camera` entitlement, `notarytool submit --wait`, then `stapler staple` on the DMG.
- **Homebrew:** since 1 Sep 2026 the official homebrew-cask repo disables casks that fail Gatekeeper, and `--no-quarantine` is deprecated (Homebrew 5.0). Unsigned builds can only go in a third-party tap.
- **Sparkle 2** with EdDSA plus an appcast hosted on GitHub Releases is the standard way to add auto-update.
- **Mac App Store isn't realistic.** Accessibility (AX) APIs don't work in the sandbox. Posting events may be allowed, but review has rejected `CGEvent.post` apps under Guideline 2.4.5.

## Key findings

1. **Gatekeeper on macOS 15.** Sequoia removed the Control-click → Open bypass. Blocked apps now need System Settings → Privacy & Security → Open Anyway, followed by admin authentication. Reports say the button disappears after about an hour, and some 15.1 users saw no button at all *(anecdotal, unverified)*. Removing quarantine with `xattr -dr com.apple.quarantine X.app` still works, but it's a bad thing to ask users to do.
2. **Notarization needs:** a Developer ID Application certificate, hardened runtime (`--options runtime`), a secure timestamp (`--timestamp`), and every nested binary signed. Under the hardened runtime, camera access requires the `com.apple.security.device.camera` entitlement. Without it, capture fails silently or the app crashes *(behavior varies by OS)*. You still need `NSCameraUsageDescription` in Info.plist.
3. **Post-Event and Accessibility need no entitlement** outside the sandbox. They're TCC grants tied to the designated requirement (Team ID + bundle ID). Developer ID signing therefore keeps grants across updates, which ad-hoc signing does not (see 08).
4. **Stapling** attaches the ticket so Gatekeeper can verify the app offline. You can staple a `.app`, `.dmg` or `.pkg`, but not a `.zip`. Notarize and staple the DMG itself, not only the app inside it.
5. **Sparkle 2** ships `generate_keys`, `sign_update` and `generate_appcast` in the SwiftPM artifacts directory. It checks each update's EdDSA signature and its Apple code signature. A common pattern is to host the feed at `https://github.com/ORG/REPO/releases/latest/download/appcast.xml`.
6. **Homebrew 5.0** (Nov 2025) deprecated `--no-quarantine`. About 387 casks (~5%) were marked for disabling on 2026-09-01.
7. **Mac App Store.** AX-gated APIs are incompatible with the App Sandbox. DTS says event posting has been allowed in the sandbox since 10.15, via `CGRequestPostEventAccess`. Even so, App Review has rejected `CGEvent.post` apps as "non-accessibility use" *(sources conflict; treat MAS as infeasible for oculOS)*.

## How to program it

```sh
# one-time: store notary credentials (App Store Connect API key preferred for CI)
xcrun notarytool store-credentials oculos-notary \
  --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-uuid>

ID="Developer ID Application: Your Name (TEAMID)"
APP=build/VisionGaze.app

# entitlements.plist: <key>com.apple.security.device.camera</key><true/>
codesign --force --timestamp --options runtime \
  --entitlements Resources/VisionGaze.entitlements --sign "$ID" "$APP"
# (sign nested frameworks, e.g. Sparkle.framework, first, inside-out; avoid --deep)
codesign --verify --strict --verbose=2 "$APP"

# DMG (hdiutil, or create-dmg for a styled window)
hdiutil create -volname VisionGaze -srcfolder "$APP" -ov -format UDZO build/VisionGaze.dmg
codesign --timestamp --sign "$ID" build/VisionGaze.dmg

xcrun notarytool submit build/VisionGaze.dmg --keychain-profile oculos-notary --wait
# on failure: xcrun notarytool log <submission-id> --keychain-profile oculos-notary
xcrun stapler staple build/VisionGaze.dmg
spctl -a -t open --context context:primary-signature -vv build/VisionGaze.dmg
spctl -a -vv "$APP"   # after copying out of the mounted DMG

# Sparkle: sign the update archive and regenerate the feed
./bin/generate_appcast --ed-key-file - releases/ < "$SPARKLE_PRIVATE_KEY"
```

In GitHub Actions on `macos-latest`: import the `.p12` into a temporary keychain (`security create-keychain`, `security import`, `security set-key-partition-list`). Keep the p12, the API key and the Sparkle key in repository secrets. Upload with `gh release create "$TAG" build/*.dmg appcast.xml`.

## Recommendations for oculOS

1. Add a `SIGN_IDENTITY` variable to `build-app.sh`. It defaults to `-` (ad-hoc) for contributors. Release CI passes the Developer ID and adds `--options runtime --timestamp --entitlements`.
2. Add `Resources/*.entitlements` containing only `com.apple.security.device.camera`. Don't add sandbox or JIT entitlements.
3. Ship a notarized, stapled DMG on GitHub Releases for each tag. Add Sparkle 2 once there's more than one app, with the feed on Releases.
4. Publish in a cask in homebrew-cask only after notarization works. Until then, use a `oculOS/homebrew-tap`.
5. If there's no paid account, document the macOS 15 "Open Anyway" flow and `xattr` in the README. Warn users that TCC grants reset on every update.
6. Rule out the Mac App Store. Note it in the README so no one spends time on it.

## Pitfalls

- `codesign --deep` hides nested-signing mistakes. Sign inside-out.
- Forgetting the camera entitlement under hardened runtime breaks capture only in release builds.
- Changing the bundle ID or Team ID orphans users' TCC grants.
- Don't try to staple a ZIP. Sparkle's ZIP updates rely on the app inside being stapled.
- The Sparkle EdDSA private key can ship code to every user. If it leaks, you can't revoke it without shipping a new public key.
- Notarization can take minutes to hours. Give CI a timeout, and fetch `notarytool log` when a submission fails.

## Sources

- https://www.idownloadblog.com/2024/08/07/apple-macos-sequoia-gatekeeper-change-install-unsigned-apps-mac/
- https://www.osnews.com/story/141055/bug-or-intentional-macos-15-1-completely-removes-ability-to-launch-unsigned-applications/
- https://wiki.hacks.guide/wiki/Open_unsigned_applications_on_macOS_Sequoia_and_newer
- https://keith.github.io/xcode-man-pages/notarytool.1.html
- https://erseltrhn.medium.com/shipping-a-notarized-sparkle-updated-macos-app-in-2026-the-indie-playbook-5df44d4cdda9
- https://www.dolthub.com/blog/2024-10-22-how-to-publish-a-mac-desktop-app-outside-the-app-store/
- https://sparkle-project.org/documentation/publishing/
- https://github.com/sparkle-project/Sparkle
- https://brew.sh/2025/11/12/homebrew-5.0.0/
- https://github.com/Homebrew/brew/issues/20755
- https://github.com/orgs/Homebrew/discussions/6334
- https://developer.apple.com/forums/thread/820594
- https://developer.apple.com/forums/thread/708652
- https://developer.apple.com/forums/thread/749494
