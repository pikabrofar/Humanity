"""VFX pass for the teaser: punch-ins, flashes, RGB split and shake on hits, zoom blur through the
scene moves, then bloom, vignette and grain. Pipes 1080x1920 frames to ffmpeg."""
import json, math, subprocess, sys
import numpy as np, cv2

FR = sys.argv[1]; OUT = sys.argv[2] if len(sys.argv) > 2 else 'teaser_video.mp4'
EV = json.load(open('events.json')); TOTAL, FPS = EV['total'], EV['fps']
W, H = 1080, 1920
hits = [(e['f'], e['hit'], e.get('flash'), e.get('shake', 0)) for e in EV['events'] if 'hit' in e]
moves = [e['f'] + 3 for e in EV['events'] if e.get('zb')]   # start of each overlap

def warp(img, s, dx=0., dy=0., rot=0.):
    M = cv2.getRotationMatrix2D((W / 2, H / 2), rot, s); M[0, 2] += dx; M[1, 2] += dy
    return cv2.warpAffine(img, M, (W, H), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0))
def zoom_blur(img, a, n=6):
    acc = np.zeros(img.shape, np.float32)
    for i in range(n): acc += warp(img, 1 + a * i / (n - 1)).astype(np.float32)
    return acc / n
def hexbgr(h): h = h.lstrip('#'); return np.array([int(h[4:6], 16), int(h[2:4], 16), int(h[0:2], 16)], np.float32)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
vig = np.clip(1 - .34 * (((xx - W / 2) / (W * .75)) ** 2 + ((yy - H / 2) / (H * .7)) ** 2), 0, 1)[..., None]
rng = np.random.default_rng(5); grain = [rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32) for _ in range(8)]
eo = lambda t: 1 - (1 - t) ** 3

ff = subprocess.Popen(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                       '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', OUT], stdin=subprocess.PIPE)
for f in range(TOTAL):
    img = cv2.imread(f'{FR}/{f:04d}.jpg')
    s, dx, dy, rot, split, flash, fcol = 1., 0., 0., 0., 0., 0., None
    for hf, st, col, sh in hits:
        k = f - hf
        if 0 <= k < 14:
            s *= 1 + .07 * st * (1 - eo(min(1, k / 9)))
            split = max(split, 12 * st * (1 - eo(min(1, k / 7))))
            if sh and k < 10:
                a = sh * st * (1 - k / 10) ** 2
                dx += math.sin(f * 2.7 + hf) * 24 * a; dy += math.cos(f * 3.3 + hf) * 18 * a; rot += math.sin(f * 1.9) * .7 * a
            if col and k < 6:
                fl = (1 - k / 6) ** 2 * (.8 if st >= 1 else .45)
                if fl > flash: flash, fcol = fl, hexbgr(col)
    zb = 0.
    for m in moves:
        k = f - m
        if 0 <= k < 8: zb = max(zb, .06 * math.sin(math.pi * (k + .5) / 8))
    if s != 1 or dx or dy or rot: img = warp(img, s, dx, dy, rot)
    x = zoom_blur(img, zb) if zb > .002 else img.astype(np.float32)
    small = cv2.resize(x, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    x += cv2.resize(cv2.GaussianBlur(np.clip(small - 165, 0, None), (0, 0), 14), (W, H)) * .5
    x *= vig
    if flash: x = x * (1 - flash) + fcol * flash
    x += cv2.resize(grain[f % 8], (W, H), interpolation=cv2.INTER_NEAREST)[..., None] * 3
    o = np.clip(x, 0, 255).astype(np.uint8)
    if split >= .5:
        p = int(round(split)); o2 = o.copy(); o2[:, :, 2] = np.roll(o[:, :, 2], p, 1); o2[:, :, 0] = np.roll(o[:, :, 0], -p, 1); o = o2
    ff.stdin.write(o.tobytes())
ff.stdin.close(); ff.wait(); print('wrote', OUT)
