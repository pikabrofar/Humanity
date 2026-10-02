# Launch video (9:16)

Renders the 42.5 s vertical launch cut from the live website: the page is captured frame by frame
on a virtual clock (so every scroll animation, WebGL frame and GSAP tween is smooth), then a
Python pass adds the VFX, and the score and sound design are synthesized to the same 120 BPM grid.

```sh
cd video/launch
mkdir -p vendor && cd vendor && for p in lenis@1.3.26 gsap@3.13.0 three@0.170.0; do
  npm pack $p --silent && mkdir -p ${p/@/-} && tar xzf ${p/@/-}.tgz -C ${p/@/-}; done && cd ..
export NODE_PATH=$(npm root -g)          # needs playwright
node cards.js && node capture.js         # frames/<shot>/*.jpg
node -e "const {SHOTS,TOTAL_BEATS}=require('./shots');require('fs').writeFileSync('shots.json',JSON.stringify({SHOTS,TOTAL_BEATS}))"
python3 audio.py                         # score.wav  (numpy, scipy)
python3 composite.py video_raw.mp4       # VFX pass   (opencv)
ffmpeg -i video_raw.mp4 -i score.wav -map 0:v -map 1:a -c:v copy -af loudnorm=I=-14:TP=-1 \
  -c:a aac -b:a 256k -shortest -movflags +faststart sentidoS_launch_9x16.mp4
```

`shots.js` is the edit: every shot's length and scroll keyframes, in beats.
