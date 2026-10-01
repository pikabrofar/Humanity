# Humanity

The all-in-one app. It hosts every module in one window with one menu bar icon
and one Settings window, and every module shares one camera:

- **VisionGaze:** eye tracking, gaze cursor, heatmaps ([details](../VisionGaze/README.md))
- **ManOS:** hand-gesture mouse ([details](../ManOS/README.md))
- **Voice:** dictation and summaries (coming soon)

```sh
make run
```

On the **Home** page, a switch turns each module's tracking on or off, which
saves power when you only need one. Each module keeps its own Quick Setup in the
sidebar.

**Adding a module:** expose a `…Module` class from the module's UI library with
`sections`, `detail(for:)`, `settings()`, `menuItems()` and `isActive`, like
`VisionGazeModule` and `ManOSModule`. Then add it to `Suite` in
`HumanityApp.swift`.
