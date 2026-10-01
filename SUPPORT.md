# Getting help

sentidoS is a free project maintained in spare time, so there's no support desk,
but these routes work.

## Ask on GitHub

[GitHub issues](https://github.com/pikabrofar/sentidoS/issues) are the main way
to get help.

- **Something broken?** Open a [bug report](https://github.com/pikabrofar/sentidoS/issues/new?template=bug_report.yml).
  Include the module, macOS version, Mac model and app version.
- **Have an idea?** Open a [feature request](https://github.com/pikabrofar/sentidoS/issues/new?template=feature_request.yml).
- **Search first.** Your question may already have an answer in an open or
  closed issue.

Issues are public. Don't attach camera images, audio, transcripts or recordings
of other people, and remove personal details from logs.

## Security problems

Don't open a public issue. Follow [SECURITY.md](SECURITY.md) to report it
privately.

## Before you ask

- **The app won't open:** sentidoS isn't notarized yet. Open it once, then go to
  System Settings > Privacy & Security and click **Open Anyway**.
- **A module does nothing:** check that sentidoS has the permission it needs
  (Camera, Microphone, Speech Recognition or Accessibility) in System Settings >
  Privacy & Security. Each one is granted once, to sentidoS. After a rebuild from
  source, see "Keeping permissions across rebuilds" in the [README](README.md).
- **Eye tracking drifts:** redo calibration in ojoS > Calibrate, in even
  lighting, with your face centered in the camera.
- **Hands stop working:** press Ctrl-Option-Command-H to turn hand control off
  and on again. Your real mouse always takes over.
- **Privacy questions:** [PRIVACY.md](PRIVACY.md) lists everything stored and
  every network request.

sentidoS requires a Mac with Apple silicon and macOS 14 or later.

## Supporting the project

sentidoS is free and nothing is locked. If it's useful to you, an
[optional donation](https://gumroad.com/l/hamkad) helps, and so do clear bug
reports and pull requests (see [CONTRIBUTING.md](CONTRIBUTING.md)).
