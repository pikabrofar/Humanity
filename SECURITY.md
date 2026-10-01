# Security

Humanity apps hold powerful permissions (camera and Accessibility), so security
reports are taken seriously.

**Reporting:** please use GitHub's private vulnerability reporting
(Security → Report a vulnerability) rather than a public issue.

**What we do:**
- Builds come from GitHub Actions, using actions pinned to commit SHAs. Each DMG
  comes with a SHA-256 checksum.
- The apps have no network code and no auto-updater yet, so there is no update
  channel to attack.
- The optional gaze-model script loads PyTorch weights with
  `torch.load(..., weights_only=True)`, so a tampered weights file can't run code.
