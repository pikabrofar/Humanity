# Launch film (9:16, 47.4 s)

The launch film for sentidoS, built as one HTML page whose `draw(t)` is deterministic. Each beat shows the input (an eye, a hand, a voice) above and its effect on a Mac screen below. The UI is rebuilt from the app's own constants, and the film ends on the website URL and "Link in bio".

- [`LAUNCH_PLAN.md`](LAUNCH_PLAN.md): the brief, concept and beat sheet with exact timings.
- [`PROCESS.md`](PROCESS.md): decisions, methods, QA gates and lessons, for reuse on later videos.

## Build

Needs Node with Playwright (`npm i -g playwright`), Python 3 with numpy, scipy and opencv-python, and ffmpeg. three.js is served from `vendor/three/package` (`npm pack three@0.170.0`, then unpack it there).

```sh
cd video/launch-v2
NODE_PATH=$(npm root -g) node render.js frames  # frames/ + events.json + audit.json; aborts if fonts don't load
python3 audio/build.py                          # stems and the two raw mixes, every sound placed on a film event
python3 audio/master.py                         # loudness: full −14 LUFS / −1 dBTP, no-music −16 LUFS / −1.5 dBTP
python3 vfx.py frames v.mp4                     # motion-blur averaging, glow, vignette, grain, the three impacts
for m in full nomusic; do
  ffmpeg -i v.mp4 -i audio/mix_$m.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest -movflags +faststart \
    sentidoS_launch_film$([ $m = full ] || echo _nomusic).mp4
done
```

`node render.js frames --at 0.5,23.9,45` renders single stills for review. The beat timings are in the `T` table at the top of `film/scenes.js`.

The render ends with an audit line (text outside the frame, platform safe zones, reading time at 200 wpm); all three must be 0.
