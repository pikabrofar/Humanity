// Captures every site shot frame by frame on a virtual clock.  usage: node capture.js [shotName ...]
const fs = require('fs');
const { open, settle } = require('./harness');
const { SHOTS, BEAT } = require('./shots');

const only = process.argv.slice(2);
const FT = 1000 / 30;
const ease = t => .5 - Math.cos(Math.PI * t) / 2;
function at(keys, beat) {
  if (beat <= keys[0][0]) return keys[0][1];
  for (let i = 1; i < keys.length; i++) {
    const [b1, v1] = keys[i], [b0, v0] = keys[i - 1];
    if (beat <= b1) return v0 + (v1 - v0) * ease((beat - b0) / (b1 - b0 || 1));
  }
  return keys[keys.length - 1][1];
}

const HIDE_CSS = `.nav, .scroll-hint { display: none !important; } html { scroll-behavior: auto !important; }`;

(async () => {
  const { browser, page } = await open();
  await page.addStyleTag({ content: HIDE_CSS });
  await settle(page, 3000);
  const cdp = await page.context().newCDPSession(page);
  const shoot = async file => {
    const r = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 94 });
    fs.writeFileSync(file, Buffer.from(r.data, 'base64'));
  };
  const geo = sel => page.evaluate(sel => { const e = document.querySelector(sel); const r = e.getBoundingClientRect(); return { top: r.top + scrollY, h: e.offsetHeight, VH: innerHeight }; }, sel);
  const yFor = (s, g, v) => Math.round(s.pin ? g.top + v * Math.max(1, g.h - g.VH) : g.top + v);
  const step = (y, ms = FT) => page.evaluate(([y, ms]) => { if (y !== null) window.scrollTo(0, y); window.__advance(ms); }, [y, ms]);

  for (const s of SHOTS) {
    if (s.kind === 'card') continue;
    if (only.length && !only.includes(s.name)) continue;
    const dir = `frames/${s.name}`; fs.mkdirSync(dir, { recursive: true });
    for (const f of fs.readdirSync(dir)) fs.unlinkSync(`${dir}/${f}`);
    const t0 = Date.now();
    if (s.kind === 'end') { await endCard(page, s, dir, shoot, step); console.log(s.name, 'done', ((Date.now() - t0) / 1000).toFixed(0) + 's'); continue; }
    if (!s.fresh) await remeasure(page, step);
    const g = await geo(s.sec);
    if (!s.fresh) {
      // park at the first position long enough for the pinned smoothing to settle, without spending the shot
      const y0 = yFor(s, g, at(s.keys, 0));
      await page.evaluate(y => window.scrollTo(0, y), y0); await page.waitForTimeout(150);
      for (let i = 0; i < 45; i++) await step(y0);
    }
    for (let f = 0; f < s.frames; f++) {
      const y = yFor(s, g, at(s.keys, f / BEAT));
      await step(y);
      if (f === 0) await page.waitForTimeout(60);
      await shoot(`${dir}/${String(f).padStart(4, '0')}.jpg`);
    }
    console.log(s.name, 'done', ((Date.now() - t0) / 1000).toFixed(0) + 's');
  }
  await browser.close();
})();

// The page caches section offsets; nudging the viewport width makes it re-measure.
async function remeasure(page, step) {
  await page.setViewportSize({ width: 541, height: 960 }); await page.waitForTimeout(80); await step(null);
  await page.setViewportSize({ width: 540, height: 960 }); await page.waitForTimeout(80); await step(null); await step(null);
}

async function endCard(page, s, dir, shoot, step) {
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(200);
  // shrink the icon: the hero sizes it to the gap above its (now hidden) footer, so lift the footer's top edge
  await page.evaluate(() => {
    const f = document.querySelector('#heroFoot'); f.style.visibility = 'hidden';
    const ft = f.getBoundingClientRect().top; f.style.paddingTop = Math.max(0, ft - innerHeight * .665) + 'px';
  });
  await remeasure(page, step);
  for (let i = 0; i < 30; i++) await step(0);
  await page.evaluate(() => {
    const css = document.createElement('style');
    css.textContent = `
      #endc { position: fixed; inset: 0; z-index: 90; pointer-events: none; font-family: var(--sans); color: var(--fg); }
      #endc .t1 { position: absolute; left: 0; right: 0; top: 61.5%; text-align: center; font: 600 34px/1.08 var(--sans); letter-spacing: -.025em; }
      #endc .t1 em { font-style: normal; }
      #endc .chips { position: absolute; left: 0; right: 0; top: 67.6%; display: flex; justify-content: center; gap: 8px; }
      #endc .chip { font: 400 11.5px/1 var(--mono); letter-spacing: .06em; text-transform: uppercase; color: var(--fg-2); border: 1px solid var(--line-2); border-radius: 99px; padding: 8px 12px; }
      #endc .url { position: absolute; left: 50%; top: 73%; transform: translateX(-50%); display: flex; align-items: center; gap: 10px; white-space: nowrap;
        background: var(--brand); color: var(--brand-ink); font: 600 19px/1 var(--sans); letter-spacing: -.01em; padding: 15px 22px; border-radius: 99px; box-shadow: 0 0 60px rgba(245,136,65,.45); }
      #endc .url svg { width: 18px; height: 18px; }
      #endc .bio { position: absolute; left: 0; right: 0; top: 80.2%; text-align: center; font: 500 15px/1.3 var(--sans); color: var(--fg-2); }
      #endc .bio b { color: var(--fg); font-weight: 600; }
      #endc [data-in] { opacity: 0; }
    `;
    document.head.appendChild(css);
    const d = document.createElement('div'); d.id = 'endc';
    d.innerHTML = `
      <div class="t1" data-in="0"><em style="color:var(--ojos)">Look.</em> <em style="color:var(--manos)">Pinch.</em> <em style="color:var(--bocas)">Speak.</em></div>
      <div class="chips" data-in="1"><span class="chip">Free</span><span class="chip">Open source</span><span class="chip">macOS 14+</span></div>
      <div class="url" data-in="2"><svg viewBox="0 0 24 24"><use href="#g-down"/></svg>pikabrofar.github.io/sentidoS</div>
      <div class="bio" data-in="3">Download free · <b>link in bio</b></div>`;
    document.body.appendChild(d);
    // replay the icon's intro and the word reveal
    const G = window.SENTIDOS_GL; if (G && G.onready) G.onready();
    window.gsap.fromTo('#heroWord .ch', { yPercent: 112 }, { yPercent: 0, duration: 1.2, ease: 'expo.out', stagger: .045, delay: .05 });
    const els = [...d.querySelectorAll('[data-in]')];
    els.forEach((e, i) => window.gsap.fromTo(e, { opacity: 0, y: 26, filter: 'blur(8px)' }, { opacity: 1, y: 0, filter: 'blur(0px)', duration: .7, ease: 'expo.out', delay: [1.0, 1.5, 2.0, 2.5][i] }));
    window.gsap.to('#endc .url', { scale: 1.06, duration: .25, ease: 'power2.out', yoyo: true, repeat: 1, delay: 3.5 });
  });
  await page.waitForTimeout(100);
  for (let f = 0; f < s.frames; f++) {
    await step(0);
    await shoot(`${dir}/${String(f).padStart(4, '0')}.jpg`);
  }
}
