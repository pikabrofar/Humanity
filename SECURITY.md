# Security

sentidoS apps hold powerful permissions (camera, microphone and Accessibility),
so security reports are taken seriously.

**Reporting:** please use GitHub's private vulnerability reporting
(Security → Report a vulnerability) rather than a public issue.

**What we do:**
- Apps are signed with the hardened runtime, which blocks injected libraries
  and debugger attach. They declare only the camera and microphone entitlements.
- Release builds come from GitHub Actions, using actions pinned to commit SHAs.
  Each DMG comes with a SHA-256 checksum. A release without a signing
  certificate gets a plain ad-hoc signature, so no other app can match its
  permission grants.
- Local development builds pin the signing requirement to the bundle ID so that
  permission grants survive rebuilds. Don't distribute them.
- Network use is limited to the paths listed in [PRIVACY.md](PRIVACY.md). AI
  requests use HTTPS (except a local Ollama). Keys are stored in the Keychain,
  sent only in request headers, and redacted from error messages.
- There is no auto-updater yet, so there is no update channel to attack.
- The optional gaze-model script loads PyTorch weights with
  `torch.load(..., weights_only=True)`, so a tampered weights file can't run code.
