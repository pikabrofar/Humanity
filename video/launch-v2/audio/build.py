"""Builds the launch film's audio from events.json (written by render.js):
stems  score.wav, sfx.wav, amb.wav
mixes  mix_full.wav (score + sfx + ambience) and mix_nomusic.wav (sfx + ambience)
Loudness is set afterwards with ffmpeg loudnorm (see ../README.md)."""
import json, math, os, sys
import numpy as np
from scipy.io import wavfile
sys.path.insert(0, os.path.dirname(__file__))
from lib import *  # noqa

HERE = os.path.dirname(__file__)
EV = json.load(open(os.path.join(HERE, '..', 'events.json')))
DUR = EV['dur'] + .6
BPM, BEAT, BAR = 120, .5, 2.0

score, sfx, amb = Bus(DUR), Bus(DUR), Bus(DUR)


def M(*xs):
    """Layer sounds of different lengths."""
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[:len(x)] += x
    return out

# ======================================================================= score
CH = {  # pad voicings (MIDI) and bass roots
    'Am9': ([45, 52, 59, 60, 67], 33), 'C': ([48, 55, 64, 71, 74], 36), 'Am': ([45, 52, 60, 67, 71], 33),
    'F': ([41, 48, 57, 64, 67], 29), 'G': ([43, 50, 59, 62, 69], 31), 'Gsus': ([43, 50, 60, 62, 67], 31), 'Em': ([40, 47, 55, 62, 67], 28),
}
ARP = {k: sorted(set(v[0][1:])) for k, v in CH.items()}


def groove(t0, bars, chords, layers, energy=1.0):
    """bars of 4 beats from t0; chords: one name per bar; layers: set of 'pad','bass','arp','shaker','snap','mallet'."""
    for b in range(bars):
        tb, ch = t0 + b * BAR, chords[b % len(chords)]
        notes, root = CH[ch]
        if 'pad' in layers:
            score.add(pad(notes, BAR + .9, cutoff=1500 + 600 * energy, att=.25, rel=.8, g=.9 * energy), tb)
        for s in range(8):  # eighths
            t = tb + s * BEAT / 2
            if 'bass' in layers:
                m = root + (12 if s % 4 == 3 else 0)
                score.add(bass(m + 12, BEAT / 2 * .92, g=.8 * energy), t)
        for s in range(16):  # sixteenths
            t = tb + s * BEAT / 4
            if 'arp' in layers:
                seq = ARP[ch] + [ARP[ch][1] + 12]
                pat = [0, 2, 1, 3, 2, 4, 1, 3]
                m = seq[pat[s % 8] % len(seq)] + 12
                score.add(pluck(m, .9, bright=.5 + .1 * energy, g=(.55 if s % 4 == 0 else .38) * energy), t, p=(-.35 if s % 2 else .35))
            if 'shaker' in layers:
                score.add(shaker(g=(.9 if s % 4 == 2 else .45) * energy), t, p=.25)
        if 'snap' in layers:
            for beat in (1, 3):
                score.add(snap(g=.5 * energy), tb + beat * BEAT, p=-.1)
        if 'mallet' in layers:
            line = {'C': [76, 74, 72, 71], 'Am': [72, 71, 69, 67], 'F': [69, 72, 74, 76], 'G': [74, 71, 67, 71], 'Gsus': [74, 72, 74, 79]}[ch]
            for i, m in enumerate(line):
                score.add(mallet(m, .7, g=.55 * energy), tb + i * BEAT + BEAT / 2, p=.3)


def duck(bus, t0, t1, depth=.22, period=BEAT, att=.004, rel=.18):
    """A gentle pump on every beat, so the groove breathes without a kick drum."""
    i0, i1 = int(t0 * SR), int(t1 * SR)
    t = np.arange(i1 - i0) / SR
    ph = (t % period)
    g = 1 - depth * np.where(ph < att, ph / att, np.exp(-(ph - att) / rel))
    bus.x[:, i0:i1] *= g


# S0 hook: tension under the first click
score.add(pad(CH['Am9'][0], 3.2, cutoff=1100, att=.08, rel=.5, g=1.0), 0.0)
for s in range(12):
    m = [57, 64, 69, 64, 72, 64, 69, 64][s % 8]
    score.add(pluck(m, .8, bright=.42, g=.42), s * BEAT / 2, p=(-.3 if s % 2 else .3))
score.add(riser(1.0, 400, 8000, g=.45), 2.0)
score.add(reverse_swell(.9, g=.7), 2.15)
# S1 title: the three senses, then the brand chord
for i, (m, t) in enumerate([(76, 3.05), (79, 3.14), (83, 3.23)]):
    score.add(bell(m, 2.4, g=.9), t, p=[-.4, 0, .4][i])
score.add(pad([36, 43, 52, 59, 62], 1.6, cutoff=700, att=.6, rel=.3, g=.8), 3.0)
score.add(pad(CH['C'][0] + [76], 2.2, cutoff=1800, att=.02, rel=1.2, g=1.3), 4.3)
for i, m in enumerate([72, 76, 79, 83, 86]):
    score.add(bell(m, 2.6, g=.8), 4.42 + i * .06, p=-.5 + .25 * i)
for m in (48, 55, 64):
    score.add(felt_piano(m, 2.4, vel=.8), 4.3)
score.add(pad(CH['C'][0], 1.9, cutoff=1200, att=.2, rel=.6, g=.6), 5.0)
# S2 groove A: eyes and hands
groove(6.0, 7, ['C', 'Am', 'F', 'G'], {'pad', 'bass', 'arp', 'shaker', 'snap'}, energy=.85)
groove(20.0, 1, ['Gsus'], {'pad', 'bass', 'arp', 'shaker', 'snap', 'mallet'}, energy=1.0)
groove(22.0, 1, ['G'], {'pad', 'bass', 'arp', 'shaker', 'mallet'}, energy=1.05)
groove(13.0, 3, ['Am', 'F', 'G'], {'mallet'}, energy=.8)  # counter-melody joins with the hands
for k in range(8):  # snap roll into the silence
    score.add(snap(g=.25 + .5 * k / 8), 23.0 + k * .0625)
score.add(riser(1.5, 300, 9000, g=.5), 22.0)
duck(score, 6.0, 23.5)
# S3 silence: cut everything at 23.5, back at 23.8
i0, i1 = int(23.5 * SR), int(23.8 * SR)
score.x[:, i0:i1] *= np.linspace(1, 0, i1 - i0) ** 6
score.x[:, i1:i1 + int(.02 * SR)] *= 0
# S4 groove B: the peak line, then voice
score.add(pad(CH['C'][0] + [79], 2.4, cutoff=2400, att=.01, rel=1.0, g=1.4), 23.8)
for m in (36, 48, 55, 64, 72):
    score.add(felt_piano(m, 2.8, vel=.9), 23.8)
groove(23.8, 5, ['C', 'Am', 'F', 'G', 'C'], {'pad', 'bass', 'arp', 'shaker', 'snap'}, energy=.95)
groove(23.8, 1, ['C'], {'mallet'}, energy=1.0)
duck(score, 23.8, 33.0)
# soften the arp under the dictation so the words and keys read
seg_ = slice(int(25.6 * SR), int(31.0 * SR)); score.x[:, seg_] *= .82
# S5 breakdown: trust
score.x[:, int(32.8 * SR):int(33.1 * SR)] *= np.linspace(1, .25, int(33.1 * SR) - int(32.8 * SR))
score.x[:, int(33.1 * SR):] *= .25
for i, (ch, t) in enumerate([('Am', 33.0), ('F', 34.25), ('C', 35.5), ('G', 36.75)]):
    notes, root = CH[ch]
    score.add(pad(notes, 1.6, cutoff=900, att=.35, rel=.7, g=.8), t)
    for j, m in enumerate([root + 12] + notes[1:4]):
        score.add(felt_piano(m + 12, 2.2, vel=.55 + .1 * (j == 0)), t + j * .03)
# S6 rebuild: the device
groove(38.0, 2, ['F', 'G'], {'pad', 'bass', 'arp', 'shaker'}, energy=.8)
groove(40.0, 1, ['G'], {'snap'}, energy=.8)
score.add(riser(1.5, 300, 9500, g=.55), 40.0)
duck(score, 38.0, 41.5, depth=.18)
for k in range(8):
    score.add(snap(g=.2 + .45 * k / 8), 41.0 + k * .0625)
# S7 finale: resolve
score.add(pad(CH['C'][0] + [76, 79], 5.5, cutoff=2200, att=.02, rel=2.5, g=1.5), 41.5)
for m in (36, 48, 55, 64, 71):
    score.add(felt_piano(m, 4.5, vel=.85), 41.5)
for i, m in enumerate([76, 79, 83, 84]):
    score.add(bell(m, 3.0, g=.85), 41.62 + i * .14, p=-.4 + .27 * i)
for b in range(2):
    for s in range(8):
        score.add(bass(48, BEAT / 2 * .9, g=.55 * (1 - b * .4)), 41.5 + b * BAR + s * BEAT / 2)
score.add(pad([48, 55, 64, 67, 74], 3.5, cutoff=1600, att=1.0, rel=1.5, g=.7), 44.0)
score.x = reverb(score.x, wet=.32, ir=reverb_ir(2.8))
# the silence before "No headset required." must be silent after the reverb too
g0, g1, g2 = int(23.46 * SR), int(23.52 * SR), int(23.8 * SR)
score.x[:, g0:g1] *= np.linspace(1, 0, g1 - g0); score.x[:, g1:g2] = 0

# ======================================================================= sound design
HIT = []
for e in EV['events']:
    t, ty = e['t'], e['type']
    p = e.get('x', e.get('pan', 0))
    if ty == 'lockon':
        sfx.add(M(tick(2600, g=.9), tick(3900, g=.4)), t, p=p); sfx.add(whoosh(.12, 2000, 7000, g=.25), t - .06, p=p)
    elif ty == 'dwell':
        d = e.get('dur', 1.0); tt_ = tt(d)
        f = 620 * 2 ** (tt_ / d)
        sfx.add(np.sin(2 * math.pi * np.cumsum(f) / SR) * (tt_ / d) ** 1.5 * .07 * (1 + .25 * np.sin(2 * math.pi * 14 * tt_)), t, p=-.3)
    elif ty == 'click':
        h = e.get('hit', .3); sfx.add(M(tick(3400, .04, g=1.4), pop(900, 500, g=.6)), t); HIT.append((t, h))
    elif ty == 'send':
        sfx.add(whoosh(.5, 500, 7000, g=.8), t, p=.2)
    elif ty == 'pupil':
        sfx.add(whoosh(.75, 3000, 220, g=.9, q=1.2), t); sfx.add(np.sin(2 * math.pi * 72 * tt(1.0)) * adsr(SR, .4, .3, .5, .3) * .09, t + .2)
    elif ty == 'emerge':
        sfx.add(reverse_swell(.6, g=.35), t)
    elif ty == 'fly':
        sfx.add(whoosh(.42, 700, 5200, g=.55), t, p=p)
    elif ty == 'impact':
        sfx.add(hit(g=.9 * e.get('hit', 1)), t); HIT.append((t, e.get('hit', 1)))
    elif ty == 'shimmer':
        for i, m in enumerate([96, 100, 103, 107]):
            sfx.add(bell(m, 1.4, idx=1.2, g=.35), t + i * .035, p=-.5 + .33 * i)
    elif ty == 'whooshUp':
        sfx.add(whoosh(.45, 900, 9000, g=.5), t)
    elif ty == 'hud':
        i = e.get('i', 0); sfx.add(M(pop(1200 + 250 * i, 600 + 120 * i, g=.7), tick(2200 + 400 * i, g=.4)), t, p=-.3 + .3 * i)
    elif ty == 'saccade':
        sfx.add(tick(1800 + 300 * ((t * 7) % 3), .03, g=.22), t, p=-.2 + .4 * ((t * 3) % 1))
    elif ty == 'key':
        i = e.get('i', 0); d = .08
        sfx.add(filt(noise(d), 'band', [900, 4200]) * expenv(d, .006, .0005) * .5 + np.sin(2 * math.pi * (190 + 15 * i) * tt(d)) * expenv(d, .02) * .35, t, p=-.15 + .1 * i)
    elif ty == 'keyUp':
        for i in range(4):
            sfx.add(filt(noise(.05), 'band', [1200, 5000]) * expenv(.05, .004) * .25, t + i * .012)
    elif ty == 'page':
        sfx.add(whoosh(.3, 1200, 5000, g=.35), t, p=.3)
    elif ty == 'swipe':
        sw = whoosh(.48, 300, 3200, g=.55)
        sfx.add(np.stack([sw * np.linspace(.4, 1.2, len(sw)), sw * np.linspace(1.2, .4, len(sw))]), t)
    elif ty == 'morph':
        for k in range(10):
            sfx.add(tick(2400 + 180 * k, .03, g=.18), t + k * .045, p=-.6 + .12 * k)
    elif ty == 'pinch':
        sfx.add(M(pop(1500, 620, g=.9), tick(3300, g=.35)), t)
    elif ty == 'drag':
        sfx.add(whoosh(1.0, 400, 1200, g=.22, q=1.0), t, p=-.2)
    elif ty == 'drop':
        d = .25; sfx.add(M(np.sin(2 * math.pi * 320 * tt(d)) * expenv(d, .05) * .35, tick(2600, g=.4)), t)
    elif ty == 'flick':
        sfx.add(whoosh(.26, 1500, 9000, g=.65), t)
    elif ty == 'slide':
        sfx.add(whoosh(.4, 400, 2400, g=.35), t)
        sfx.add(tick(2000, g=.35), t + .05)
    elif ty == 'saved':
        sfx.add(bell(88, 1.0, idx=1.0, g=.5), t); sfx.add(bell(95, 1.0, idx=1.0, g=.4), t + .09)
    elif ty == 'micOn':
        sfx.add(bell(81, .7, idx=.8, g=.45), t); sfx.add(bell(88, .8, idx=.8, g=.4), t + .08)
    elif ty == 'syllable':
        n = e.get('n', 3); d = .05 + .03 * n
        sfx.add(filt(noise(d), 'band', [500, 2600]) * np.sin(math.pi * np.clip(tt(d) / d, 0, 1)) ** 1.5 * .05, t, p=-.1)
    elif ty == 'strike':
        d = .16; tt_ = tt(d); f = 5000 * np.exp(-tt_ / .06) + 600
        sfx.add((filt(noise(d), 'band', [2000, 9000]) * .4 + np.sin(2 * math.pi * np.cumsum(f) / SR) * .12) * np.sin(math.pi * tt_ / d), t, p=.2)
    elif ty == 'paste':
        sfx.add(M(pop(1300, 700, g=.6), tick(4200, g=.3)), t); sfx.add(whoosh(.2, 2000, 8000, g=.25), t - .1)
    elif ty == 'card':
        sfx.add(whoosh(.35, 600, 4000, g=.4), t - .1); sfx.add(tick(2200, g=.3), t + .15)
    elif ty == 'pop':
        q = e.get('p', 1000); sfx.add(pop(q, q * .45, g=.55), t)
    elif ty == 'whoosh':
        sfx.add(whoosh(.6, 300, 4500, g=.5), t)
    elif ty == 'frames':
        for i in range(11):  # each frame absorbed by the chip
            ta = 34.05 + i * .32
            if ta < 37.9:
                sfx.add(M(bell(98 - (i % 3) * 2, .35, idx=.6, g=.16), tick(3000 + 200 * (i % 4), .03, g=.15)), ta, p=[-.35, .35, 0][i % 3])
    elif ty == 'deny':
        for k in range(2):
            d = .12; sfx.add(np.sin(2 * math.pi * 330 * tt(d)) * expenv(d, .04) * .22, t + k * .1)
    elif ty == 'lock':
        sfx.add(tick(2800, .04, g=.9), t); sfx.add(tick(1900, .05, g=.7), t + .05)
        d = .3; sfx.add(filt(noise(d), 'band', [300, 1400]) * expenv(d, .05) * .35, t + .05)
    elif ty == 'tick3':
        for k in range(3):
            sfx.add(tick(2000 + 300 * k, .04, g=.4), t + k * .08, p=-.2 + .2 * k)
    elif ty == 'toggle':
        i = e.get('i', 0); sfx.add(M(pop(900 + 220 * i, 430 + 100 * i, g=.85), tick(2600 + 300 * i, g=.4)), t, p=-.35 + .35 * i)
    elif ty == 'riser':
        sfx.add(riser(e.get('len', 1.5), 500, 9000, g=.3), t)
    elif ty == 'chime':
        sfx.add(bell(91, 1.4, idx=1.0, g=.55), t); sfx.add(bell(96, 1.6, idx=1.0, g=.45), t + .1)
sfx.x = reverb(sfx.x, wet=.16, ir=reverb_ir(1.2, (1.2, .9, .5)), hp=500)
sfx.x[:, int(23.52 * SR):int(23.79 * SR)] *= .15   # let the gap breathe

# ======================================================================= ambience: a quiet room so silence is never empty
n = amb.n
z = rng.standard_normal((2, n))
pink = filt(z, 'low', 900, 1) * .5 + filt(z, 'low', 220, 1) * .5
amb.x = filt(pink, 'high', 110, 2) * .006   # room tone without rumble
air = filt(rng.standard_normal((2, int(3.4 * SR))), 'band', [3000, 9000]) * np.sin(np.linspace(0, math.pi, int(3.4 * SR))) ** 2 * .01
amb.add(air, 2.9)

# ======================================================================= write stems and mixes
def write(name, x):
    x = np.clip(x, -1, 1)
    wavfile.write(os.path.join(HERE, name), SR, (x.T * 32767).astype(np.int16))

def master(x, ceiling=-1.5):
    x = filt(x, 'high', 30, 2)
    x = compress(x, thr_db=-20, ratio=2.0, att=.012, rel=.2)
    x = np.tanh(x * 1.05) / np.tanh(1.05)
    return limit(x, ceiling)

S, X, A = score.x, sfx.x, amb.x
full = master(S * .62 + X * 1.0 + A)
nomus = master(X * 1.0 + A * 1.2)
for nm, b in (('score.wav', S), ('sfx.wav', X), ('amb.wav', A)):
    write(nm, b / max(1e-9, np.abs(b).max()) * .9)
write('mix_full_raw.wav', full / np.abs(full).max() * .84)
write('mix_nomusic_raw.wav', nomus / np.abs(nomus).max() * .84)
# objective checks: low-end energy (the brief: no thumping) and peaks
def band_db(x, lo, hi):
    f = np.fft.rfftfreq(x.shape[1], 1 / SR); P = np.abs(np.fft.rfft(x.mean(0))) ** 2
    return 10 * np.log10(P[(f >= lo) & (f < hi)].sum() / P.sum())
print('score: energy below 60 Hz = %.1f dB of total, 60-120 Hz = %.1f dB' % (band_db(S, 20, 60), band_db(S, 60, 120)))
print('full : energy below 60 Hz = %.1f dB of total' % band_db(full, 20, 60))
print('wrote stems and raw mixes, %.1f s' % (full.shape[1] / SR))
