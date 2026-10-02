"""VFX pass: reads the captured shots, applies punch-ins, flashes, RGB split, shake, zoom blur,
beat pulses, bloom, grain and vignette, and pipes 1080x1920 frames to ffmpeg."""
import json, sys, subprocess, math, os
import numpy as np, cv2

W, H, FPS, BEAT = 1080, 1920, 30, 15
D = json.load(open('shots.json'))
SHOTS = D['SHOTS']
TOTAL = D['TOTAL_BEATS'] * BEAT
SH = {s['name']: s for s in SHOTS}
DROP = SH['hero']['start'] * BEAT
GROOVE = (DROP + 4 * BEAT, SH['end']['start'] * BEAT + 8 * BEAT)
BREAK = (SH['privacy']['start'] * BEAT, SH['free']['start'] * BEAT)

# hits: (global frame, strength 0..1, flash colour or None, shake)
hits = []
for s in SHOTS:
    f0 = s['start'] * BEAT
    if s['name'] == 'hook': continue
    if s['name'] in ('hero', 'end'): hits.append((f0, 1.0, (255, 255, 255), .6))
    elif s['kind'] == 'card': hits.append((f0, .9, None, 1.0))
    elif s['name'] == 'free': hits.append((f0, .8, (245, 136, 65), .3))
    elif s['name'] in ('ojosOp', 'manosOp', 'bocasOp'): hits.append((f0, .55, None, 0))
    else: hits.append((f0, .4, None, 0))
for f in (0, 15, 30, 35, 40): hits.append((f, .7 if f < 30 else .45, None, .9 if f < 30 else .5))
# step changes inside demos get a small nudge
for n in ('ojosDemo', 'manosDemo', 'bocasDemo'):
    for b in SH[n]['ticks']: hits.append((int(round((SH[n]['start'] + b + .1) * BEAT)), .22, None, 0))
cuts = sorted({s['start'] * BEAT for s in SHOTS if s['start'] > 0})

def src(gf):
    for s in SHOTS:
        a = s['start'] * BEAT
        if a <= gf < a + s['frames']:
            p = f"frames/{s['name']}/{gf - a:04d}.jpg"
            return s, gf - a, p
    s = SHOTS[-1]; return s, s['frames'] - 1, f"frames/{s['name']}/{s['frames'] - 1:04d}.jpg"

def warp(img, scale, dx=0., dy=0., rot=0.):
    M = cv2.getRotationMatrix2D((W / 2, H / 2), rot, scale)
    M[0, 2] += dx; M[1, 2] += dy
    return cv2.warpAffine(img, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0))

def zoom_blur(img, amt, n=5):
    acc = np.zeros(img.shape, np.float32)
    for i in range(n): acc += warp(img, 1 + amt * i / (n - 1)).astype(np.float32)
    return acc / n

def rgb_split(img, px):
    if px < .5: return img
    px = int(round(px)); out = img.copy()
    out[:, :, 2] = np.roll(img[:, :, 2], px, axis=1)   # R (BGR order)
    out[:, :, 0] = np.roll(img[:, :, 0], -px, axis=1)  # B
    return out

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
vig = 1 - .38 * (((xx - W / 2) / (W * .75)) ** 2 + ((yy - H / 2) / (H * .7)) ** 2)
vig = np.clip(vig, 0, 1)[..., None]
rng = np.random.default_rng(3)
grain_bank = [rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32) for _ in range(8)]
eo = lambda t: 1 - (1 - t) ** 3

out = sys.argv[1] if len(sys.argv) > 1 else 'video.mp4'
preview = '--preview' in sys.argv
ff = subprocess.Popen(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgr24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                       '-c:v', 'libx264', '-preset', 'veryfast' if preview else 'slow', '-crf', '24' if preview else '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], stdin=subprocess.PIPE)

prev = None
for gf in range(TOTAL):
    s, lf, path = src(gf)
    img = cv2.imread(path)
    if img.shape[1] != W: img = cv2.resize(img, (W, H), interpolation=cv2.INTER_CUBIC)
    scale, dx, dy, rot, split, flash, fcol, zb = 1.0, 0., 0., 0., 0., 0., (255, 255, 255), 0.
    for (hf, st, col, shake) in hits:
        k = gf - hf
        if 0 <= k < 14:
            e = 1 - eo(min(1, k / 9))
            scale *= 1 + .1 * st * e
            split = max(split, 14 * st * (1 - eo(min(1, k / 7))))
            if shake and k < 10:
                a = shake * st * (1 - k / 10) ** 2
                dx += math.sin(gf * 2.7 + hf) * 26 * a; dy += math.cos(gf * 3.3 + hf) * 20 * a; rot += math.sin(gf * 1.9) * .8 * a
            if col is not None and k < 6:
                fl = (1 - k / 6) ** 2 * (.85 if st >= 1 else .5)
                if fl > flash: flash, fcol = fl, col
    # outgoing zoom blur into each cut
    for c in cuts:
        k = c - gf
        if 0 < k <= 3: zb = max(zb, .05 * (4 - k) / 3)
    # beat pulse during the groove (downbeats stronger)
    if GROOVE[0] <= gf < GROOVE[1] and not (BREAK[0] <= gf < BREAK[1]):
        k = (gf - GROOVE[0]) % BEAT
        scale *= 1 + (.012 if ((gf - GROOVE[0]) // BEAT) % 2 == 0 else .006) * (1 - k / 6) * (k < 6)
    if s['name'] == 'end':
        scale *= 1 + .03 * lf / s['frames']  # slow push-in on the end card
    if s['name'] == 'hero' and lf < 70:
        scale *= 1.06 - .06 * eo(lf / 70)    # the logo settles into frame
    if scale != 1 or dx or dy or rot: img = warp(img, scale, dx, dy, rot)
    f = zoom_blur(img, zb) if zb > 0 else img.astype(np.float32)
    # bloom
    small = cv2.resize(f, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    bright = np.clip(small - 170, 0, None)
    bloom = cv2.GaussianBlur(bright, (0, 0), 14)
    f += cv2.resize(bloom, (W, H), interpolation=cv2.INTER_LINEAR) * .45
    f = f * vig
    if flash > 0: f = f * (1 - flash) + np.array(fcol[::-1], np.float32) * flash
    g = cv2.resize(grain_bank[gf % 8], (W, H), interpolation=cv2.INTER_NEAREST)
    f += g[..., None] * 3.2
    img = np.clip(f, 0, 255).astype(np.uint8)
    img = rgb_split(img, split)
    ff.stdin.write(img.tobytes())
    if gf % 150 == 0: print('frame', gf, '/', TOTAL, flush=True)
ff.stdin.close(); ff.wait()
print('wrote', out)
