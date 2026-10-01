# Distribution and trust for open-source macOS utilities

How successful open-source Mac utilities (Rectangle, Maccy, Stats, Ice,
MonitorControl, LinearMouse) get installed and trusted, applied to Humanity.

**Most important finding:** from September 1, 2026, the official Homebrew cask
repo disables casks that fail Gatekeeper, and Homebrew 5.0 deprecated
`--no-quarantine`. So an unsigned or ad-hoc-signed app can't be installed with
`brew install --cask` from the main repo. Only notarized apps can.
([Homebrew #6334](https://github.com/orgs/Homebrew/discussions/6334),
[HN](https://news.ycombinator.com/item?id=45907259))

## Checklist (in priority order)

1. **Sign every build with one stable self-signed certificate.** It's free.
   - **Why:** ad-hoc signing ties the app's identity (its "designated
     requirement") to a hash of the binary, which changes on every build. Each
     update then drops the Camera, Accessibility and Microphone grants.
     ([parley#75](https://github.com/pathorsAI/parley/issues/75),
     [YARG#1695](https://github.com/YARC-Official/YARG/issues/1695),
     [SuperDictate#19](https://github.com/shlgd/SuperDictate/issues/19))
   - **Create the certificate:**
     `openssl req -x509 -newkey rsa:2048 -keyout k.pem -out c.pem -days 3650 -nodes -subj "/CN=Humanity Self-Signed" -addext "extendedKeyUsage=codeSigning"`.
     Export it as a .p12 and store it base64-encoded as a CI secret.
   - **Verify:** `codesign -d --requirements - App.app` must not show `cdhash H"…"`.
2. **Budget $99/yr for a Developer ID and notarization.** It's the biggest trust
   step. It removes Gatekeeper friction, and it's the only way into
   homebrew-cask.
   - CI flow: `codesign --options runtime --timestamp`, then
     `xcrun notarytool submit X.dmg --key AuthKey.p8 --key-id … --issuer … --wait`,
     then `xcrun stapler staple X.dmg`.
   - ([defn.io](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/),
     [Terzi](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/))
3. **Document the unsigned install flow exactly.**
   - macOS 15 removed the Control-click → Open bypass. Users now have to open
     the app, then go to **System Settings → Privacy & Security → Open
     Anyway**, then enter their password. The button only shows for about an
     hour after the blocked launch.
   - A command-line fallback also works:
     `xattr -dr com.apple.quarantine /Applications/App.app`.
   - ([mjtsai](https://mjtsai.com/blog/2024/07/05/sequoia-removes-gatekeeper-contextual-menu-override/),
     [swissmacuser](https://swissmacuser.ch/fix-macos-tahoe-app-is-damaged-and-cant-be-opened-move-trash/))
4. **Run your own Homebrew tap** (`pikabrofar/homebrew-tap`) until the apps are
   notarized. Third-party taps aren't affected by the new rule.
5. **Release CI on tag:**
   - Build a universal binary (`swift build -c release --arch arm64 --arch x86_64`).
   - Create a DMG that includes an `/Applications` symlink (`hdiutil create -format UDZO`).
   - Publish a SHA-256 file next to it, then run `gh release create`.
   - ([SwiftToolkit](https://www.swifttoolkit.dev/posts/releasing-with-gh-actions))
6. **Per-app tag prefixes** in the monorepo: `oculos/v1.4.0`,
   `dextra/v0.9.0`. Use path filters per app.
   - **Pitfall:** `releases/latest` is shared by the whole repo, so don't use it
     as a Sparkle feed.
7. **Sparkle 2 auto-updates with an EdDSA key.**
   - Needs no Apple account. Put `SUPublicEDKey` in Info.plist.
   - Host one appcast per app (on gh-pages).
   - Keep the EdDSA key when you later add a Developer ID.
   - ([Sparkle](https://sparkle-project.org/documentation/))
8. **Expect permission resets anyway.**
   - On launch, check Camera, Accessibility and Microphone status, and show a
     re-grant screen with buttons that open the right pane in System Settings.
   - Document the fix: `tccutil reset Accessibility <bundle id>`.
9. **A plain privacy statement in each README.** Say there's no telemetry, list
   every network call, and state that frames and audio are processed on-device
   and never saved or sent. ([Stats](https://github.com/exelban/stats))
10. **README structure** (like Ice and Stats):
    - hero GIF
    - badges
    - install (brew one-liner and DMG link)
    - permissions and why each is needed
    - features
    - FAQ
    - build from source
    - license

    ([Ice](https://github.com/jordanbaird/Ice))
11. **GitHub issue forms.**
    - `bug.yml` with dropdowns for app, version, macOS version, chip and camera,
      plus a "permissions granted?" checkbox.
    - Set `blank_issues_enabled: false`.
12. **Checksums and a reproducible build path.** Publish SHA-256 for every DMG,
    document `swift build` from a tag, and add `SECURITY.md` and a changelog.

**The bar to meet:** Rectangle, Maccy, Stats, Ice, MonitorControl and LinearMouse
all ship notarized DMGs or ZIPs on GitHub Releases, have Homebrew casks, and
mostly use Sparkle.
