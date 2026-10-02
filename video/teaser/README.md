# Teaser (9:16, ~23 s, SFX only)

Original motion design (not a screen recording), built as one HTML page whose `draw(frame)` is
deterministic: hook (eyes → hands → voice, "No mouse. No trackpad. Just you."), the icon assembling
in 3D, a Mac that rises in and parks with its menu bar panel switching on, then "Coming soon." and a follow prompt (no links: this is a teaser).
Text holds are budgeted at 200 wpm, and every frame is checked for text running outside the frame.
There is no music track, so a sound can be added in TikTok / Reels / Shorts.

```sh
cd video/teaser
NODE_PATH=$(npm root -g) node render.js frames   # needs playwright; writes frames/ and events.json
python3 sfx.py                                   # sfx.wav, every sound placed on a page event
python3 vfx.py frames v.mp4                      # punch-ins, flashes, shake, zoom blur, bloom, grain
ffmpeg -i v.mp4 -i sfx.wav -map 0:v -map 1:a -c:v copy -af loudnorm=I=-16:TP=-1.5 \
  -c:a aac -b:a 256k -shortest -movflags +faststart sentidoS_teaser.mp4
```

Scene timing lives in the `T` table at the top of the script in `teaser.html`.
