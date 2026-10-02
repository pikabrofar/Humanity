"""Synthesizes the score and sound design for the launch cut, locked to the 120 BPM edit grid."""
import json, math
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 48000
BPM = 120
BEAT = 60 / BPM
D = json.load(open('shots.json'))
SH = {s['name']: s for s in D['SHOTS']}
TOTAL = D['TOTAL_BEATS'] * BEAT + 0.6
N = int(TOTAL * SR)
rng = np.random.default_rng(7)

bus = {k: np.zeros((N, 2)) for k in ['drums', 'bass', 'music', 'fx', 'ui']}

def b2s(b): return b * BEAT
def put(name, x, t, gain=1.0, pan=0.0):
    i = int(round(t * SR))
    if x.ndim == 1:
        l, r = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
        x = np.stack([x * l * 1.414, x * r * 1.414], 1)
    if i < 0: x = x[-i:]; i = 0
    n = min(len(x), N - i)
    if n > 0: bus[name][i:i + n] += x[:n] * gain

def tt(d): return np.arange(int(d * SR)) / SR
def env_exp(d, tau, att=0.002):
    t = tt(d); e = np.exp(-t / tau)
    a = np.minimum(1, t / att) if att > 0 else 1
    return e * a
def noise(d): return rng.standard_normal(int(d * SR))
def bp(x, lo, hi, order=2): return signal.sosfilt(signal.butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)
def hp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, 'high', fs=SR, output='sos'), x)
def lp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, 'low', fs=SR, output='sos'), x)
def sweep_lp(x, f0, f1, block=256):
    out = np.zeros_like(x); zi = None; n = len(x)
    for s in range(0, n, block):
        f = f0 * (f1 / f0) ** (s / max(1, n))
        sos = signal.butter(2, min(f, SR * .45), 'low', fs=SR, output='sos')
        if zi is None: zi = signal.sosfilt_zi(sos) * 0
        out[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return out
def sweep_bp(x, f0, f1, q=1.2, block=256):
    out = np.zeros_like(x); zi = None; n = len(x)
    for s in range(0, n, block):
        f = f0 * (f1 / f0) ** (s / max(1, n))
        lo, hi = f / (1 + 1 / q), min(f * (1 + 1 / q), SR * .45)
        sos = signal.butter(1, [lo, hi], 'band', fs=SR, output='sos')
        if zi is None: zi = signal.sosfilt_zi(sos) * 0
        out[s:s + block], zi = signal.sosfilt(sos, x[s:s + block], zi=zi)
    return out
def saw(f, d, phase=0.0):
    t = tt(d)
    if np.isscalar(f): ph = f * t + phase
    else: ph = np.cumsum(f) / SR + phase
    return 2 * (ph % 1) - 1
def sine(f, d):
    t = tt(d)
    if np.isscalar(f): return np.sin(2 * np.pi * f * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def mtof(m): return 440 * 2 ** ((m - 69) / 12)
def norm(x): return x / (np.max(np.abs(x)) + 1e-9)

# ---------- instruments ----------
def kick(big=False):
    d = .5 if not big else .9
    t = tt(d)
    f = 45 + 140 * np.exp(-t / .035) + (60 * np.exp(-t / .006))
    x = sine(f, d) * env_exp(d, .16 if not big else .3)
    x += lp(noise(d), 4000) * env_exp(d, .004) * .35
    return np.tanh(x * 1.6) * .9
def clap():
    d = .4; x = np.zeros(int(d * SR))
    for k, o in enumerate([0, .009, .018, .028]):
        n = bp(noise(d), 900, 3200) * env_exp(d, .012 if k < 3 else .12)
        i = int(o * SR); x[i:] += n[:len(x) - i]
    return x * .55
def hat(open_=False):
    d = .25 if open_ else .06
    return hp(noise(d), 7500, 4) * env_exp(d, .07 if open_ else .012) * (.28 if open_ else .22)
def snare():
    d = .25
    return (bp(noise(d), 1500, 7000) * env_exp(d, .05) * .5 + sine(190 * np.exp(-tt(d) / .05) + 160, d) * env_exp(d, .04) * .5)
def impact(d=2.5, sub=48):
    t = tt(d)
    x = sine(sub * (1 + .8 * np.exp(-t / .08)), d) * env_exp(d, .55) * 1.0
    x += lp(noise(d), 1800) * env_exp(d, .25) * .55
    x += hp(noise(d), 3000) * env_exp(d, .06) * .25
    return np.tanh(x * 1.3)
def snap():
    d = .3
    return hp(noise(d), 1500) * env_exp(d, .025) * .6 + sine(1800 * np.exp(-tt(d) / .01) + 300, d) * env_exp(d, .01) * .3
def whoosh(d=.6, f0=300, f1=6000, rev=False):
    t = tt(d); e = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    x = sweep_bp(noise(d), f0, f1, q=1.5) * e
    return (x[::-1] if rev else x) * 1.4
def riser(d):
    t = tt(d); u = t / d
    x = sweep_bp(noise(d), 400, 9000, q=2) * u ** 2 * 1.1
    f = 220 * 2 ** (u * 2)
    x += lp(saw(f, d) + saw(f * 1.01, d), 3000) * u ** 2.5 * .18
    return x
def reverse_cym(d=1.0):
    x = hp(noise(d), 5000, 2) * env_exp(d, .5)
    return x[::-1] * .5
def tick(f=2600, g=.5):
    d = .05
    return (sine(f, d) * env_exp(d, .008) + hp(noise(d), 4000) * env_exp(d, .002) * .5) * g
def pop(f0=900, f1=380):
    d = .12; t = tt(d)
    return sine(f1 + (f0 - f1) * np.exp(-t / .02), d) * env_exp(d, .035) * .7
def bell(m, d=2.0):
    f = mtof(m); t = tt(d)
    x = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau)) for a, r, tau in [(1, 1, .9), (.5, 2.76, .35), (.3, 5.4, .15), (.25, 2, .6)])
    return x * np.minimum(1, t / .003) * .25
def zip_(d=.18):
    t = tt(d); f = 500 + 5000 * (t / d) ** 2
    return (saw(f, d) * .2 + bp(noise(d), 2000, 9000) * .4) * np.sin(np.pi * t / d) * .6
def stab(ms, d=.45):
    x = sum(saw(mtof(m) * k, d) for m in ms for k in (1, 1.006, .994))
    return lp(x, 2600) * env_exp(d, .14, .003) * .12
def pluck(m, d=.3):
    f = mtof(m)
    x = saw(f, d) + .5 * saw(f * 2.003, d)
    return sweep_lp(x, 5000, 500) * env_exp(d, .09) * .09
def pad(ms, d):
    t = tt(d)
    x = sum(saw(mtof(m) * k, d, phase=rng.random()) for m in ms for k in (1, 1.004, .996, 1.009))
    x = lp(x, 1400, 2)
    a = np.minimum(1, t / .25) * np.minimum(1, (d - t) / .3)
    return x * a * .035
def bass_note(m, d):
    f = mtof(m)
    x = saw(f, d) * .6 + sine(f, d) * .7 + sine(f / 2, d) * .25
    x = sweep_lp(x, 900, 250)
    t = tt(d); a = np.minimum(1, t / .004) * np.minimum(1, (d - t) / .02)
    return x * a * .5

def reverb(x, secs=2.2, wet=.3, hpf=300):
    ir_n = int(secs * SR); t = np.arange(ir_n) / SR
    irL = rng.standard_normal(ir_n) * np.exp(-t / (secs / 5)); irR = rng.standard_normal(ir_n) * np.exp(-t / (secs / 5))
    irL[:int(.012 * SR)] = 0; irR[:int(.017 * SR)] = 0
    irL /= np.sqrt(np.sum(irL ** 2)); irR /= np.sqrt(np.sum(irR ** 2))
    src = hp(x.mean(1), hpf)
    L = signal.fftconvolve(src, irL)[:len(x)]; R = signal.fftconvolve(src, irR)[:len(x)]
    return x + np.stack([L, R], 1) * wet

# ---------- timeline helpers ----------
def shot_t(name, beat_in): return b2s(SH[name]['start'] + beat_in)
ease = lambda u: .5 - math.cos(math.pi * u) / 2
def key_time(name, value, lag=.08):
    """first time (s) the shot's keyed value crosses `value`"""
    ks = SH[name]['keys']
    for (b0, v0), (b1, v1) in zip(ks, ks[1:]):
        if v1 > v0 and v0 <= value <= v1:
            lo, hi = 0, 1
            for _ in range(40):
                m = (lo + hi) / 2
                if v0 + (v1 - v0) * ease(m) < value: lo = m
                else: hi = m
            return shot_t(name, b0 + (b1 - b0) * lo) + lag
    return None

# progression: Am F C G, one bar each
PROG = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
ROOT = [45, 41, 48, 43]
DROP = SH['hero']['start']
END = SH['end']['start']
TOT_B = D['TOTAL_BEATS']
BREAK = (SH['privacy']['start'], SH['free']['start'])

def chord_at(b): return int(((b - DROP) // 4) % 4)

# ---------- hook ----------
for b in [0, 1]:
    put('fx', impact(1.2, 55), b2s(b), .55)
    put('fx', snap(), b2s(b), .6)
    put('drums', kick(True), b2s(b), .8)
    put('fx', zip_(), b2s(b) + 6 / 30, .5, pan=-.3 if b == 0 else .3)
for i, (b, m) in enumerate([(2, [57, 64]), (2 + 1 / 3, [60, 67]), (2 + 2 / 3, [64, 71])]):
    put('music', stab([m[0], m[1], m[0] + 12]), b2s(b), 1.0, pan=[-.4, 0, .4][i])
    put('drums', kick(), b2s(b), .55)
    put('fx', snap(), b2s(b), .35)
put('fx', riser(b2s(1.85)), b2s(2.0), .8)
put('fx', reverse_cym(1.0), b2s(DROP) - 1.0, .9)
for k in range(8):  # stutter roll into the drop
    put('drums', snare(), b2s(3 + k / 8), .25 + .5 * k / 8)

# ---------- the groove ----------
for b in range(DROP, TOT_B):
    t = b2s(b)
    in_break = BREAK[0] <= b < BREAK[1]
    half = b < DROP + 4  # logo reveal: half-time
    outro = b >= END + 8
    if outro: continue
    if not in_break:
        if (not half) or (b - DROP) % 2 == 0:
            put('drums', kick(b in (DROP,)), t, .95)
        if not half:
            if b % 2 == 1: put('drums', clap(), t, .75)
            put('drums', hat(True), t + BEAT / 2, .8, pan=.2)
            for s in range(4):
                put('drums', hat(), t + s * BEAT / 4, .55 + .25 * (s == 2), pan=-.25)
    else:
        for s in range(4):
            put('drums', hat(), t + s * BEAT / 4, .35 + .2 * (s == 2), pan=-.25)
        if b >= BREAK[1] - 2:
            for s in range(4): put('drums', snare(), t + s * BEAT / 4, .2 + .4 * ((b - (BREAK[1] - 2)) * 4 + s) / 8)
    c = chord_at(b)
    # bass: eighths, sidechained by note gating
    if not half and not outro:
        for e in range(2):
            put('bass', bass_note(ROOT[c] + (12 if (e == 1 and b % 2 == 1) else 0), BEAT / 2 * .92), t + e * BEAT / 2 + .02, .9 if not in_break else .5)
    # plucks: 16th arpeggio
    if not half:
        notes = PROG[c] + [PROG[c][0] + 12]
        for s in range(4):
            m = notes[(b * 4 + s) % 4] + 12
            put('music', pluck(m), t + s * BEAT / 4, 1.0 if not in_break else .6, pan=.35 * (1 if s % 2 else -1))
# pads per bar
for bar_b in range(DROP, TOT_B, 4):
    c = chord_at(bar_b)
    d = b2s(min(4, TOT_B - bar_b)) + (.9 if bar_b + 4 >= TOT_B else .05)
    put('music', pad(PROG[c] + [PROG[c][0] - 12], d), b2s(bar_b), 1.0)
# fills before the smash cards
for name in ['look', 'pinch', 'speak', 'free']:
    b = SH[name]['start']
    for k in range(4): put('drums', snare(), b2s(b - 1 + k / 4), .3 + .12 * k)
    put('fx', whoosh(.5, 400, 7000), b2s(b) - .45, .6)
    put('fx', impact(1.6, 52), b2s(b), .65)
    put('fx', reverse_cym(.5), b2s(b) - .5, .5)
# end: the last big hit, then let it ring
put('fx', impact(3.5, 42), b2s(END), 1.0)
put('fx', reverse_cym(1.0), b2s(END) - 1.0, .8)
put('fx', riser(b2s(2)), b2s(END - 2), .6)
put('drums', kick(True), b2s(END), 1.0)
put('drums', kick(True), b2s(END + 8), .9)
put('fx', impact(3.0, 40), b2s(END + 8), .6)
for m in [69, 76, 81]: put('music', bell(m, 3.0), b2s(END + 8), .9)
put('bass', bass_note(33, 3.6), b2s(END + 8), .9)

# ---------- sound design locked to on-screen events ----------
# logo reveal shimmer
for i, m in enumerate([81, 84, 88, 93]): put('music', bell(m, 2.2), b2s(DROP) + .08 + i * .07, .7, pan=-.3 + .2 * i)
put('fx', impact(3.0, 44), b2s(DROP), 1.0)
# hero: icon tilts and explodes into three discs, docks into the menu bar
put('fx', whoosh(.9, 200, 5000), key_time('hero', .05), .7)
for i, v in enumerate([.24, .27, .30, .33]):  # callouts
    put('ui', pop(1200 + i * 150, 500 + i * 60), key_time('hero', v), .45, pan=-.4 + .27 * i)
put('fx', whoosh(.5, 3000, 300), key_time('hero', .52), .7)
put('fx', whoosh(.45, 2000, 200), key_time('hero', .6), .6)
put('ui', tick(1800, .7), key_time('hero', .70), 1.0)
put('ui', pop(700, 300), key_time('hero', .72), .7)
put('ui', tick(3000, .5), key_time('hero', .83), 1.0)
for i, v in enumerate([.905, .935, .965]):
    put('ui', pop(900 + i * 200, 420 + i * 100), key_time('hero', v), .9, pan=-.3 + .3 * i)
    put('ui', tick(2400 + i * 300, .6), key_time('hero', v), .8)

def step_ticks(name):
    for b in SH[name]['ticks']:
        t = shot_t(name, b + .1)
        put('ui', tick(2200, .55), t, .9); put('fx', whoosh(.25, 1500, 6000), t - .12, .25)
step_ticks('ojosDemo'); step_ticks('manosDemo'); step_ticks('bocasDemo')
for name in ['ojosOp', 'manosOp', 'bocasOp']:
    put('fx', whoosh(.7, 250, 3000), shot_t(name, 0), .45)
# pinch clicks across the manoS demo, the look + pinch save, typing in bocaS
for k in range(5): put('ui', pop(1500, 600), shot_t('manosDemo', 1.8 * 1 + .5 + k * .3), .35)
put('ui', pop(1300, 500), shot_t('lookpinch', 3.6), .9)
put('ui', bell(88, .8), shot_t('lookpinch', 3.75), .6)
for k in range(10): put('ui', tick(3500 + rng.integers(-500, 500), .25), shot_t('bocasDemo', 2.4 + k * .09), .7, pan=rng.uniform(-.3, .3))
put('fx', whoosh(1.2, 300, 2500), shot_t('privacy', 0), .4)
put('fx', riser(b2s(2)), b2s(BREAK[1] - 2), .55)
put('fx', whoosh(.5, 400, 7000), b2s(END) - .45, .7)
put('ui', pop(1000, 450), b2s(END) + 1.0, .5)
put('ui', pop(1100, 500), b2s(END) + 1.5, .5)
put('ui', bell(84, 1.5), b2s(END) + 2.0, .8)
put('ui', pop(800, 350), b2s(END) + 3.5, .8)

# ---------- mix ----------
# sidechain music and bass to the kick (four on the floor from the drop)
duck = np.ones(N)
for b in range(DROP, END + 8):
    if BREAK[0] <= b < BREAK[1]: continue
    if b < DROP + 4 and (b - DROP) % 2: continue
    i = int(b2s(b) * SR); d = int(.22 * SR)
    seg_ = 1 - .6 * np.exp(-np.arange(d) / (SR * .07))
    duck[i:i + d] = np.minimum(duck[i:i + d], seg_[:max(0, min(d, N - i))])
# breakdown filter on music + bass
lpf = np.ones(N)
music = bus['music'] * duck[:, None]
bass = bus['bass'] * duck[:, None]
a, z = int(b2s(BREAK[0]) * SR), int(b2s(BREAK[1]) * SR)
for ch in range(2):
    music[a:z, ch] = sweep_lp(music[a:z, ch], 700, 6000)
    bass[a:z, ch] = sweep_lp(bass[a:z, ch], 200, 900)
music = reverb(music, 2.6, .35)
fx = reverb(bus['fx'], 3.0, .25, 200)
ui = reverb(bus['ui'], 1.2, .18, 800)
drums = reverb(bus['drums'], .8, .06, 500)
mix = drums * .85 + bass * .8 + music * .9 + fx * .75 + ui * .8
mix = signal.sosfilt(signal.butter(2, 25, 'high', fs=SR, output='sos'), mix, axis=0)
mix = np.tanh(mix * 1.15) / np.tanh(1.15)
# fade out the tail
fo = int(.6 * SR); mix[-fo:] *= np.linspace(1, 0, fo)[:, None]
mix = mix / np.max(np.abs(mix)) * .89
wavfile.write('score.wav', SR, (mix * 32767).astype(np.int16))
print('wrote score.wav', round(TOTAL, 2), 's')
