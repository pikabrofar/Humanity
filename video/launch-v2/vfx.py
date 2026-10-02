"""Finishing pass for the launch film: averages each frame's motion-blur sub-frames, adds a soft glow on
emissive highlights, a light vignette and film grain, and restrained hits (a short flash and a 2% push on the
three impacts only). Pipes 1080x1920 frames to ffmpeg.   usage: python3 vfx.py <framesDir> <out.mp4>"""
import glob, json, math, os, subprocess, sys
import numpy as np, cv2

FR, OUT = sys.argv[1], sys.argv[2]
EV = json.load(open(os.path.join(os.path.dirname(__file__), 'events.json')))
FPS, N = EV['fps'], int(round(EV['dur'] * EV['fps']))
W, H = 1080, 1920
HITS = [(e['t'], e.get('hit', 1), e.get('flash')) for e in EV['events'] if e['type'] == 'impact']

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
vig = np.clip(1 - .2 * (((xx - W / 2) / (W * .8)) ** 2 + ((yy - H / 2) / (H * .75)) ** 2), 0, 1)[..., None]
rng = np.random.default_rng(9)
grain = [rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32) for _ in range(8)]
hexbgr = lambda h: np.array([int(h[5:7], 16), int(h[3:5], 16), int(h[1:3], 16)], np.float32)

ff = subprocess.Popen(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                       '-c:v', 'libx264', '-preset', 'slow', '-crf', '15', '-pix_fmt', 'yuv420p', '-tune', 'film', '-movflags', '+faststart', OUT], stdin=subprocess.PIPE)
for f in range(N):
    subs = sorted(glob.glob(f'{FR}/{f:04d}_*.jpg'))
    if not subs:
        raise SystemExit(f'missing frame {f}')
    x = np.mean([cv2.imread(p).astype(np.float32) for p in subs], axis=0)
    t = f / FPS
    # restrained hits: a 2% push and a short flash, only on the three impacts
    push, flash, fcol = 1.0, 0.0, None
    for th, st, col in HITS:
        k = t - th
        if 0 <= k < .3:
            push = max(push, 1 + .02 * st * (1 - k / .3) ** 2)
            if col and k < .2:
                fl = .35 * st * (1 - k / .2) ** 2
                if fl > flash: flash, fcol = fl, hexbgr(col)
    if push > 1.0001:
        M = cv2.getRotationMatrix2D((W / 2, H / 2), 0, push)
        x = cv2.warpAffine(x, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    # glow on emissive highlights (gaze ring, LED, logo speculars)
    small = cv2.resize(x, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    x += cv2.resize(cv2.GaussianBlur(np.clip(small - 200, 0, None), (0, 0), 10), (W, H)) * .4
    x *= vig
    if flash > 0:
        x = x * (1 - flash) + fcol * flash
    x += cv2.resize(grain[f % 8], (W, H), interpolation=cv2.INTER_NEAREST)[..., None] * 2.2
    ff.stdin.write(np.clip(x, 0, 255).astype(np.uint8).tobytes())
    if f % 300 == 0:
        print('vfx frame', f, '/', N, flush=True)
ff.stdin.close(); ff.wait()
print('wrote', OUT)
