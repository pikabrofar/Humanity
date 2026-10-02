// Film engine: deterministic draw(t) for any t in seconds, an event list for sound and VFX,
// headline/label reveals, and the audits the renderer runs (frame bounds, safe zones, reading time).
(() => {
const F = window.F = {};
window.FILM_READY = new Promise(r => (F._ready = r));
F.FPS = 30; F.DUR = 47.0; F.BEAT = .5;
const clamp = F.clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const seg = F.seg = (t, a, b) => clamp((t - a) / (b - a));
F.lerp = (a, b, t) => a + (b - a) * t;
F.mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
F.e = {
  o2: t => 1 - (1 - t) ** 2, o3: t => 1 - (1 - t) ** 3, o4: t => 1 - (1 - t) ** 4, o5: t => 1 - (1 - t) ** 5,
  i2: t => t * t, i3: t => t * t * t,
  io2: t => t < .5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2,
  io3: t => t < .5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2,
  expo: t => t >= 1 ? 1 : 1 - 2 ** (-10 * t),
  ss: t => t * t * (3 - 2 * t),
  back: (t, c = 1.5) => 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2,
};
// critically damped spring step response, like SwiftUI spring(response:, dampingFraction: 1)
F.spring = (t, response) => { if (t <= 0) return 0; const w = 2 * Math.PI / response; return 1 - (1 + w * t) * Math.exp(-w * t); };
// underdamped spring (dampingFraction < 1)
F.springU = (t, response, zeta) => { if (t <= 0) return 0; const w = 2 * Math.PI / response, wd = w * Math.sqrt(1 - zeta * zeta); return 1 - Math.exp(-zeta * w * t) * (Math.cos(wd * t) + zeta * w / wd * Math.sin(wd * t)); };
// value that hops between keyed targets with a spring: keys = [[t, value], ...]
F.hops = (t, keys, response, zeta = 1) => {
  let v = keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [tk, vk] = keys[i]; if (t < tk) break;
    const prev = v, k = zeta >= 1 ? F.spring(t - tk, response) : F.springU(t - tk, response, zeta);
    v = Array.isArray(prev) ? prev.map((p, j) => p + (vk[j] - p) * k) : prev + (vk - prev) * k;
  }
  return v;
};
F.$ = (s, r = document) => r.querySelector(s);
F.$$ = (s, r = document) => [...r.querySelectorAll(s)];
F.el = (tag, cls, html, parent) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; if (parent) parent.appendChild(e); return e; };
F.show = (e, on, d = 'block') => { e.style.display = on ? d : 'none'; };

// ---------- events (sound + vfx) and motion-blur spans ----------
F.events = [];
F.ev = (t, type, o = {}) => F.events.push(Object.assign({ t: +t.toFixed(4), type }, o));
F.fastSpans = [];
F.fast = (a, b, n = 4) => F.fastSpans.push([a, b, n]);
F.subframes = t => { let n = 1; for (const [a, b, k] of F.fastSpans) if (t >= a && t < b) n = Math.max(n, k); return n; };

// ---------- headlines and labels ----------
// F.head(html, tIn, tOut, {top, size, cls}) — lines split on <br>; each line rises out of a mask.
F.heads = [];
F.head = (html, tIn, tOut, o = {}) => {
  const box = F.el('div', 'head' + (o.cls ? ' ' + o.cls : ''), null, F.$('#heads'));
  box.dataset.read = ''; box.dataset.safe = '';
  box.style.top = (o.top ?? 368) + 'px';
  if (o.size) box.style.fontSize = o.size + 'px';
  if (o.left != null) { box.style.left = o.left + 'px'; box.style.right = (o.right ?? o.left) + 'px'; }
  box.innerHTML = html.split('<br>').map(l => `<span class="ln"><span>${l}</span></span>`).join('');
  const h = { box, tIn, tOut, o, lines: F.$$('.ln > span', box) };
  F.heads.push(h); return h;
};
F.label = (text, tIn, tOut, top, o = {}) => {
  const e = F.el('div', 'label', text, F.$('#heads')); e.style.top = top + 'px'; e.dataset.read = ''; e.dataset.safe = '';
  if (o.color) e.style.color = o.color;
  F.heads.push({ box: e, tIn, tOut, o: Object.assign({ fade: true }, o), lines: [e] }); return e;
};
function drawHeads(t) {
  for (const h of F.heads) {
    const { box, tIn, tOut, o } = h;
    if (t < tIn - .05 || t >= tOut + .4) { box.style.display = 'none'; continue; }
    box.style.display = '';
    const out = F.e.io2(seg(t, tOut, tOut + .32));
    if (o.slam) {
      const k = F.e.o5(seg(t, tIn, tIn + .16));
      box.style.opacity = clamp(k * 1.7) * (1 - out);
      box.style.transform = `scale(${(1 + .5 * (1 - k)) * (1 + .03 * seg(t, tIn, tIn + 2))}) translateY(${-14 * out}px)`;
      box.style.filter = k < 1 ? `blur(${(1 - k) * 12}px)` : (out > 0 ? `blur(${out * 6}px)` : '');
      continue;
    }
    if (o.fade) {
      const k = F.e.o3(seg(t, tIn, tIn + .35));
      box.style.opacity = k * (1 - out); box.style.transform = `translateY(${(1 - k) * 8 - out * 8}px)`; box.style.filter = '';
      continue;
    }
    box.style.opacity = 1 - out;
    box.style.transform = `translateY(${-16 * F.e.i2(out)}px)`;
    box.style.filter = out > .02 ? `blur(${out * 6}px)` : '';
    h.lines.forEach((ln, i) => {
      const k = F.e.expo(seg(t, tIn + i * .08, tIn + i * .08 + .62));
      ln.style.transform = `translateY(${(1 - k) * 112}%)`;
    });
  }
}

// ---------- the frame ----------
F.beats = [];          // {t0, t1, draw(t, lt)} registered by scenes.js
F.always = [];         // drawn every frame after beats
F.preps = [];
F.draw = t => {
  if (F.preps.length) { const p = F.preps.splice(0); p.forEach(f => f()); }
  for (const b of F.beats) if (t >= b.t0 && t < b.t1) b.draw(t, t - b.t0);
  for (const f of F.always) f(t);
  drawHeads(t);
  F.lastT = t;
};

// ---------- audits, run by the renderer on every frame ----------
const visible = e => { for (let n = e; n && n !== document.body; n = n.parentElement) { const s = getComputedStyle(n); if (s.display === 'none' || s.visibility === 'hidden' || +s.opacity < .9) return false; } return true; };
const settled = e => { for (let n = e; n && n !== document.body; n = n.parentElement) { if (n.style && /blur\((?!0)/.test(n.style.filter || '')) return false; } return true; };
const textRects = e => { // rects of the glyphs themselves (text nodes and keycaps), not of their boxes
  const out = [], w = document.createTreeWalker(e, NodeFilter.SHOW_TEXT);
  for (let n = w.nextNode(); n; n = w.nextNode()) { if (!n.textContent.trim()) continue; const r = document.createRange(); r.selectNodeContents(n); out.push(...r.getClientRects()); }
  return out.filter(q => q.width > 1 && q.height > 1); };
F.audit = () => {
  const out = { edge: [], safe: [], read: [] };
  for (const e of F.$$('[data-safe]')) {
    if (!visible(e) || !settled(e)) continue;
    const rs = textRects(e); if (!rs.length) continue;
    const L = Math.min(...rs.map(q => q.left)), R = Math.max(...rs.map(q => q.right)), T = Math.min(...rs.map(q => q.top)), B = Math.max(...rs.map(q => q.bottom));
    const name = (e.textContent || '').trim().slice(0, 28);
    if (L < 24 || R > 516) out.edge.push({ name, L: Math.round(L), R: Math.round(R) });
    // TikTok / Reels / Shorts chrome: top bar, bottom caption block, right action rail
    if (T < 78 || B > 772 || (R > 476 && B > 430 && T < 840)) out.safe.push({ name, T: Math.round(T), B: Math.round(B), R: Math.round(R) });
  }
  for (const e of F.$$('[data-read]')) if (visible(e)) out.read.push((e.textContent || '').replace(/\s+/g, ' ').trim());
  return out;
};
})();
