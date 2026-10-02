"""Sound design for the teaser, no music: every sound sits on an event the page emits (events.json).
Hits are kept light in the low end so the track sits under whatever music is added in the app."""
import json, math
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
EV = json.load(open('events.json'))
FPS = EV['fps']
N = int((EV['total'] / FPS + .8) * SR)
rng = np.random.default_rng(11)
out = np.zeros((N, 2))

def tt(d): return np.arange(int(d * SR)) / SR
def env(d, tau, att=.002): t = tt(d); return np.exp(-t / tau) * np.minimum(1, t / att)
def noise(d): return rng.standard_normal(int(d * SR))
def filt(x, kind, f, order=2): return signal.sosfilt(signal.butter(order, f, kind, fs=SR, output='sos'), x)
def sine(f, d):
    t = tt(d)
    return np.sin(2 * np.pi * (f * t if np.isscalar(f) else np.cumsum(f) / SR))
def sweep_bp(x, f0, f1, q=1.5, block=256):
    y = np.zeros_like(x); zi = None
    for s in range(0, len(x), block):
        f = f0 * (f1 / f0) ** (s / max(1, len(x)))
        sos = signal.butter(1, [f / (1 + 1 / q), min(f * (1 + 1 / q), SR * .45)], 'band', fs=SR, output='sos')
        if zi is None: zi = np.zeros((sos.shape[0], 2))
        y[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return y
def put(x, t, g=1., pan=0.):
    i = int(t * SR); l, r = math.cos((pan + 1) * math.pi / 4) * 1.414, math.sin((pan + 1) * math.pi / 4) * 1.414
    n = min(len(x), N - i)
    if n > 0: out[i:i + n, 0] += x[:n] * g * l; out[i:i + n, 1] += x[:n] * g * r

# ---------- sounds
def tick(p=2400): d = .06; return sine(p, d) * env(d, .01) * .5 + filt(noise(d), 'high', 4000) * env(d, .002) * .25
def pop(p0=1000, p1=420): d = .14; t = tt(d); return sine(p1 + (p0 - p1) * np.exp(-t / .02), d) * env(d, .04) * .7
def whoosh(d=.45, f0=500, f1=7000):
    t = tt(d); return sweep_bp(noise(d), f0, f1) * np.sin(np.pi * t / d) ** 2 * 1.3
def slam(h=.5):
    d = .7; t = tt(d)
    body = filt(noise(d), 'band', [200, 2400]) * env(d, .06) * .7
    snap = filt(noise(d), 'high', 3000) * env(d, .015) * .6
    low = sine(90 + 60 * np.exp(-t / .03), d) * env(d, .09) * .45   # short, tuned high: a hit, not a thump
    return (body + snap + low) * (.6 + .5 * h)
def impact():
    d = 2.6; t = tt(d)
    crack = filt(noise(d), 'high', 1800) * env(d, .05) * .9
    body = filt(noise(d), 'band', [150, 1800]) * env(d, .35) * .6
    low = sine(70 + 50 * np.exp(-t / .05), d) * env(d, .22) * .5
    metal = sum(np.sin(2 * np.pi * f * t) * np.exp(-t / tau) for f, tau in [(523, .9), (1567, .5), (2637, .3), (3951, .2)]) * .07
    return crack + body + low + metal
def shimmer():
    d = 2.4; t = tt(d)
    return sum(np.sin(2 * np.pi * f * t) * np.exp(-t / (1.2 - i * .2)) * np.minimum(1, t / (.01 + i * .06)) for i, f in enumerate([1760, 2217, 2637, 3520])) * .06
def riser(d):
    t = tt(d); u = t / d
    return sweep_bp(noise(d), 300, 10000, q=2.2) * u ** 2.2 * .9 + sine(330 * 2 ** (u * 2), d) * u ** 3 * .05
def glitch(h=.8):
    d = .22; x = np.zeros(int(d * SR)); s = int(.012 * SR)
    for k in range(0, len(x), s):
        if rng.random() < .65: x[k:k + s] = (np.sign(np.sin(np.arange(min(s, len(x) - k)) * 2 * np.pi * rng.uniform(200, 1800) / SR)) * rng.uniform(.2, .6))
    y = slam(.3) * .5; y[:len(x)] += filt(x, 'band', [300, 8000]) * env(d, .09) * h; return y
def strike():
    d = .2; t = tt(d); f = 600 + 6000 * (t / d) ** 2
    return (filt(noise(d), 'band', [2500, 9000]) * .5 + sine(f, d) * .08) * np.sin(np.pi * t / d)
def mic(): return tick(1300) * .8 + tick(1900)[::1] * .4
def word(n):
    d = .05 * n + .05; x = np.zeros(int(d * SR))
    for k in range(n):
        c = filt(noise(.03), 'band', [1800, 6000]) * env(.03, .004) * rng.uniform(.4, .7); i = int(k * .045 * SR); x[i:i + len(c)] += c
    return x
def chime():
    d = 1.6; t = tt(d)
    return sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / tau) for a, f, tau in [(1, 1318.5, .6), (.6, 1975.5, .45), (.35, 2637, .3)]) * .22

# ---------- place everything
for e in EV['events']:
    t, ty, pan = e['f'] / FPS, e['type'], e.get('pan', 0)
    if ty == 'tick': put(tick(e.get('p', 2400)), t, .8, pan)
    elif ty == 'swell': put(whoosh(.9, 200, 2500), t, .35)
    elif ty == 'slam': put(slam(e.get('hit', .5)), t, .75)
    elif ty == 'whoosh': put(whoosh(.42), t - .2, .55)
    elif ty == 'whooshUp': put(whoosh(.5, 900, 9000), t - .15, .5)
    elif ty == 'pinch': put(pop(1500, 600), t, .8); put(tick(3200), t, .5)
    elif ty == 'mic': put(mic(), t, .6)
    elif ty == 'word': put(word(e['n']), t, .6, rng.uniform(-.25, .25))
    elif ty == 'glitch': put(glitch(e.get('hit', .8)), t, .8, pan)
    elif ty == 'strike': put(strike(), t, .55)
    elif ty == 'riser': put(riser(e['len'] / FPS), t, .55)
    elif ty == 'fly': put(whoosh(.55, 400, 5000), t, .5, pan)
    elif ty == 'impact': put(impact(), t, .9); put(shimmer(), t + .05, .9)
    elif ty == 'shine': put(whoosh(.6, 3000, 12000), t, .25)
    elif ty == 'letter': put(tick(1800 + 140 * e['i']), t, .35, -.4 + .1 * e['i'])
    elif ty == 'click': put(tick(2000), t, .7); put(pop(800, 400), t, .5)
    elif ty == 'toggle': put(pop(900 + 200 * e['i'], 420 + 90 * e['i']), t, .8, -.35 + .35 * e['i']); put(tick(2600 + 300 * e['i']), t, .5)
    elif ty == 'pop': put(pop(e.get('p', 1000), e.get('p', 1000) * .45), t, .55)
    elif ty == 'chime': put(chime(), t, .8)

# small room so the hits don't sound dry
ir_n = int(1.1 * SR); tir = np.arange(ir_n) / SR
for ch in range(2):
    ir = rng.standard_normal(ir_n) * np.exp(-tir / .2); ir[:int(.01 * SR)] = 0; ir /= np.sqrt((ir ** 2).sum())
    out[:, ch] += signal.fftconvolve(filt(out[:, ch], 'high', 400), ir)[:N] * .16
out = filt(out.T, 'high', 60).T
out = np.tanh(out * 1.1) / np.tanh(1.1)
out *= .89 / np.abs(out).max()
fo = int(.5 * SR); out[-fo:] *= np.linspace(1, 0, fo)[:, None]
wavfile.write('sfx.wav', SR, (out * 32767).astype(np.int16))
print('wrote sfx.wav', round(N / SR, 2), 's,', len(EV['events']), 'events')
