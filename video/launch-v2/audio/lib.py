"""DSP helpers and instruments for the launch film's score and sound design (48 kHz, numpy/scipy only)."""
import math
import numpy as np
from scipy import signal

SR = 48000
rng = np.random.default_rng(42)


def tt(d):
    return np.arange(int(round(d * SR))) / SR


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def noise(d):
    return rng.standard_normal(int(round(d * SR)))


def sos(kind, f, order=2):
    return signal.butter(order, f, kind, fs=SR, output='sos')


def filt(x, kind, f, order=2):
    return signal.sosfilt(sos(kind, f, order), x, axis=-1)


def sweep(x, kind, f0, f1, order=2, block=256, q=None):
    """Time-varying filter: cutoff (or band centre) moves exponentially from f0 to f1."""
    out = np.zeros_like(x)
    zi = None
    n = len(x)
    for s in range(0, n, block):
        f = f0 * (f1 / f0) ** (s / max(1, n - 1))
        if kind == 'band':
            bw = 1 / (q or 1.4)
            sp = signal.butter(1, [max(20, f / (1 + bw)), min(SR * .45, f * (1 + bw))], 'band', fs=SR, output='sos')
        else:
            sp = signal.butter(order, min(f, SR * .45), kind, fs=SR, output='sos')
        if zi is None:
            zi = np.zeros((sp.shape[0], 2))
        out[s:s + block], zi = signal.sosfilt(sp, x[s:s + block], zi=zi)
    return out


def adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    e = np.full(n, s, float)
    if a:
        e[:a] = np.linspace(0, 1, a, endpoint=False)[:n]
    if d:
        e[a:a + d] = np.linspace(1, s, d, endpoint=False)[:max(0, min(d, n - a))]
    if r:
        e[-r:] *= np.linspace(1, 0, r) if r <= n else 1
    return e


def expenv(d, tau, att=.002):
    t = tt(d)
    return np.exp(-t / tau) * np.minimum(1, t / max(att, 1e-6))


def pan2(x, p):
    p = max(-1, min(1, p))
    return np.stack([x * math.cos((p + 1) * math.pi / 4), x * math.sin((p + 1) * math.pi / 4)]) * math.sqrt(2)


class Bus:
    def __init__(self, dur):
        self.n = int(dur * SR) + SR
        self.x = np.zeros((2, self.n))

    def add(self, sig, t, g=1.0, p=0.0):
        if sig.ndim == 1:
            sig = pan2(sig, p)
        i = int(round(t * SR))
        if i < 0:
            sig = sig[:, -i:]
            i = 0
        m = min(sig.shape[1], self.n - i)
        if m > 0:
            self.x[:, i:i + m] += sig[:, :m] * g


# ------------------------------------------------------------------ instruments
def additive(f, d, partials, att=.004, inharm=0.0):
    """partials: list of (k, amp, tau). Exact tuning, natural decay of high partials."""
    t = tt(d)
    y = np.zeros_like(t)
    for k, a, tau in partials:
        fk = f * k * math.sqrt(1 + inharm * k * k)
        if fk > SR * .45:
            continue
        y += a * np.sin(2 * math.pi * fk * t + k * .7) * np.exp(-t / tau)
    return y * np.minimum(1, t / att)


def pluck(m, d=1.2, bright=.55, g=1.0):
    f = mtof(m)
    P = [(k, (1 / k) * bright ** (k - 1), .55 / (1 + .55 * (k - 1))) for k in range(1, 18)]
    y = additive(f, d, P, att=.002)
    y += filt(noise(d), 'band', [min(1500, f * 3), min(9000, f * 12)]) * expenv(d, .006) * .12
    return y * g * .35


def felt_piano(m, d=2.5, vel=.7):
    f = mtof(m)
    P = [(k, (1 / k ** 1.25) * (.6 + .4 * vel) ** (k - 1), 1.8 / (1 + .35 * (k - 1))) for k in range(1, 14)]
    y = additive(f, d, P, att=.009, inharm=.00035)
    y += filt(noise(d), 'low', 900) * expenv(d, .012) * .05 * vel
    return filt(y, 'low', 2600 + 2000 * vel) * .3 * vel


def bell(m, d=2.5, idx=2.2, g=1.0):
    f = mtof(m)
    t = tt(d)
    mod = np.sin(2 * math.pi * f * 3.5 * t) * idx * np.exp(-t / .5)
    y = np.sin(2 * math.pi * f * t + mod) * np.exp(-t / 1.1)
    y += .35 * np.sin(2 * math.pi * f * 2.001 * t) * np.exp(-t / .6)
    return y * np.minimum(1, t / .002) * .22 * g


def mallet(m, d=.8, g=1.0):
    f = mtof(m)
    return additive(f, d, [(1, 1, .35), (4, .35, .08), (10, .08, .025)], att=.002) * .28 * g


def pad(ms, d, cutoff=1600, att=.6, rel=.9, g=1.0, bright_end=None):
    t = tt(d)
    y = np.zeros((2, len(t)))
    for j, m in enumerate(ms):
        f = mtof(m)
        for k, det in enumerate((-7, 0, 7)):
            ph = rng.random()
            ff = f * 2 ** (det / 1200)
            v = 2 * ((ff * t + ph) % 1) - 1
            y[(j + k) % 2] += v * (.8 if det == 0 else .6)
    e = adsr(len(t), att, .2, 1, rel)
    if bright_end:
        y = np.stack([sweep(c, 'low', cutoff, bright_end) for c in y])
    else:
        y = filt(y, 'low', cutoff, 2)
    return y * e * .02 * g


def bass(m, d, g=1.0):
    f = mtof(m)
    t = tt(d)
    y = np.sin(2 * math.pi * f * t) + .22 * np.sin(4 * math.pi * f * t) + .06 * np.sin(6 * math.pi * f * t)
    y = np.tanh(1.3 * y) / np.tanh(1.3)
    return filt(y * adsr(len(t), .012, .12, .65, .05), 'low', 700) * .32 * g


def shaker(g=1.0):
    d = .09
    return filt(noise(d), 'band', [5500, 12000]) * adsr(int(d * SR), .006, .04, .2, .03) * .16 * g


def snap(g=1.0):
    d = .22
    t = tt(d)
    y = filt(noise(d), 'band', [1400, 6000]) * expenv(d, .03, .001) * .55
    y += np.sin(2 * math.pi * 1850 * t) * expenv(d, .012) * .18
    return y * g * .5


def riser(d, f0=300, f1=9000, g=1.0):
    t = tt(d)
    u = t / d
    y = sweep(noise(d), 'band', f0, f1, q=2.0) * u ** 2.2 * .9
    for k in (1, 2):
        ff = 220 * k * 2 ** (u * 2)
        y += .05 * np.sin(2 * math.pi * np.cumsum(ff) / SR) * u ** 3
    return y * g


def whoosh(d=.5, f0=400, f1=6000, g=1.0, q=1.5):
    t = tt(d)
    e = np.sin(math.pi * np.clip(t / d, 0, 1)) ** 2
    return sweep(noise(d), 'band', f0, f1, q=q) * e * 1.3 * g


def tick(f=2400, d=.05, g=1.0):
    t = tt(d)
    y = np.sin(2 * math.pi * f * t) * expenv(d, .008, .0005) + filt(noise(d), 'high', 4500) * expenv(d, .0015, .0002) * .5
    return y * .45 * g


def pop(f0=1100, f1=450, g=1.0):
    d = .14
    t = tt(d)
    f = f1 + (f0 - f1) * np.exp(-t / .018)
    return np.sin(2 * math.pi * np.cumsum(f) / SR) * expenv(d, .035, .001) * .6 * g


def hit(g=1.0, low=52):
    """Cinematic hit without a kick-drum thump: air, crack, a slow-attack body and a shimmer tail."""
    d = 3.2
    t = tt(d)
    crack = filt(noise(d), 'high', 2200) * expenv(d, .045, .001) * .7
    body = filt(noise(d), 'band', [180, 1600]) * expenv(d, .32, .004) * .45
    low_s = np.sin(2 * math.pi * (low + 30 + 18 * np.exp(-t / .12)) * t) * expenv(d, .45, .03) * .16
    tail = filt(noise(d), 'band', [3000, 9000]) * expenv(d, .9, .02) * .08
    return (crack + body + low_s + tail) * g


def reverse_swell(d=1.0, g=1.0):
    x = filt(noise(d), 'band', [2000, 10000]) * expenv(d, .45)
    return x[::-1] * .5 * g


# ------------------------------------------------------------------ mixing
def reverb_ir(dur=2.6, t60=(2.8, 2.1, 1.1), pre=.018, er=True):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for ch in range(2):
        z = rng.standard_normal(n)
        lo, mid, hi = filt(z, 'low', 500), filt(z, 'band', [500, 4000]), filt(z, 'high', 4000)
        ir = sum(b * np.exp(-6.91 * t / T) for b, T in zip((lo, mid, hi), t60))
        ir[:int(pre * SR)] = 0
        if er:
            for k in range(6):
                i = int((pre * .5 + .007 * (k + 1) + .003 * ch) * SR)
                ir[i] += (.6 - .08 * k) * (1 if (k + ch) % 2 else -1)
        out[ch] = ir / np.sqrt(np.sum(ir ** 2))
    return out


def reverb(x, wet=.25, ir=None, hp=250):
    ir = reverb_ir() if ir is None else ir
    src = filt(x.mean(0), 'high', hp)
    w = np.stack([signal.fftconvolve(src, ir[c])[:x.shape[1]] for c in range(2)])
    return x * (1 - wet * .3) + w * wet


def compress(x, thr_db=-18, ratio=2.5, att=.01, rel=.15, makeup_db=0):
    lvl = np.sqrt(signal.lfilter([1 - math.exp(-1 / (.01 * SR))], [1, -math.exp(-1 / (.01 * SR))], (x ** 2).mean(0)) + 1e-12)
    db = 20 * np.log10(lvl)
    over = np.maximum(0, db - thr_db)
    gr = over * (1 - 1 / ratio)
    # smooth gain reduction with attack/release
    a_a, a_r = math.exp(-1 / (att * SR)), math.exp(-1 / (rel * SR))
    sm = np.zeros_like(gr)
    g = 0.0
    for i in range(0, len(gr), 64):
        target = gr[i:i + 64].max()
        coef = a_a ** 64 if target > g else a_r ** 64
        g = target + (g - target) * coef
        sm[i:i + 64] = g
    return x * 10 ** ((-sm + makeup_db) / 20)


def limit(x, ceiling_db=-1.2, look=.005):
    ceil = 10 ** (ceiling_db / 20)
    peak = np.abs(x).max(0)
    w = int(look * SR)
    pk = signal.convolve(peak, np.ones(1), mode='same')
    # running max over the look-ahead window
    from scipy.ndimage import maximum_filter1d, uniform_filter1d
    m = maximum_filter1d(pk, size=2 * w + 1)
    gain = np.minimum(1, ceil / np.maximum(m, 1e-9))
    gain = uniform_filter1d(gain, size=w)
    return x * gain
