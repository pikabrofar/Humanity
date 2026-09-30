# Reviews

Two review agents, 5 minutes each. Both reviewed by reading only; Swift isn't available in the review container, so nothing was compiled or run.

| Review | Scope | Headline |
|---|---|---|
| [Code review](code-review.md) | VisionGaze / GazeKit source | 1 High, 4 Medium, 6 Low. The calibration math and the pupil refiner check out. High: a background click refit can overwrite a newer calibration (`GazeEngine.swift:224-230`). Medium: races between the camera queue and the main thread, the whole calibration saved on the main thread on every click, and blink detection that can stick on. |
| [Repository and research review](repo-and-research-review.md) | Repo health, and codebase claims in reports 01–10 | No CI, CONTRIBUTING or templates, and the two LICENSE files name different holders. The code claims in reports 01, 04 and 10 check out; report 05's "4 samples" is only a user-tunable default (2–6). |
