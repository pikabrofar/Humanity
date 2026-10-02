// Renders film/index.html frame by frame (1080x1920, 30 fps) with sub-frame motion blur, and runs the
// audits: fonts loaded, text inside the frame, text inside the platform safe zones, reading time at 200 wpm.
// usage: node render.js <outDir> [fromSec] [toSec]        all frames in a range
//        node render.js <outDir> --at 0.5,2,3.3            single stills (no blur), for review
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const FILM = path.join(__dirname, 'film');
const THREE = process.env.THREE_DIR || path.join(__dirname, 'vendor/three/package');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };

(async () => {
  const out = process.argv[2] || path.join(__dirname, 'frames');
  const atIdx = process.argv.indexOf('--at');
  const stills = atIdx > 0 ? process.argv[atIdx + 1].split(',').map(Number) : null;
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ args: ['--hide-scrollbars', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 2 });
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.host !== 'film.local') return r.fulfill({ status: 404, body: '' });
    let p = decodeURIComponent(u.pathname);
    let f = p.startsWith('/three/') ? path.join(THREE, p.slice(7)) : path.join(FILM, p === '/' ? 'index.html' : p);
    if (p.startsWith('/fonts/fonts/')) f = path.join(FILM, 'fonts', path.basename(p));
    if (!fs.existsSync(f)) { console.error('404', p); return r.fulfill({ status: 404, body: '' }); }
    return r.fulfill({ contentType: TYPES[path.extname(f)] || 'application/octet-stream', body: fs.readFileSync(f) });
  });
  page.on('pageerror', e => console.error('pageerror', e.message));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.error('console', m.text()); });
  await page.goto('https://film.local/', { waitUntil: 'load' });
  await page.evaluate(async sym => {
    document.getElementById('defs').innerHTML = sym;
    await Promise.all(['600 38px "Instrument Sans"', '500 16px "Instrument Sans"', '400 16px "Instrument Sans"', '400 11px "Fragment Mono"'].map(f => document.fonts.load(f)));
    await document.fonts.ready;
    if (![...document.fonts].some(f => f.family.includes('Instrument') && f.status === 'loaded')) throw new Error('Instrument Sans did not load');
    if (window.FILM_READY) await window.FILM_READY;
  }, fs.readFileSync(path.join(FILM, 'brand-symbols.svgfrag'), 'utf8'));
  const meta = await page.evaluate(() => ({ dur: F.DUR, fps: F.FPS, events: F.events.sort((a, b) => a.t - b.t) }));
  fs.writeFileSync(path.join(__dirname, 'events.json'), JSON.stringify(meta, null, 1));

  const shot = async (t, file) => { await page.evaluate(t => F.draw(t), t); await page.screenshot({ path: file, type: 'jpeg', quality: 94 }); };
  if (stills) {
    for (const t of stills) await shot(t, path.join(out, `still_${t.toFixed(2)}.jpg`));
    const a = []; for (const t of stills) { await page.evaluate(t => F.draw(t), t); a.push([t, await page.evaluate(() => F.audit())]); }
    a.forEach(([t, r]) => { if (r.edge.length || r.safe.length) console.log('t', t, JSON.stringify({ edge: r.edge, safe: r.safe })); });
    await browser.close(); return;
  }
  const from = +(process.argv[3] || 0), to = +(process.argv[4] || meta.dur);
  const f0 = Math.round(from * meta.fps), f1 = Math.round(to * meta.fps);
  const seen = new Map(), edge = new Map(), safe = new Map();
  for (let f = f0; f < f1; f++) {
    const t = f / meta.fps;
    const n = await page.evaluate(t => F.subframes(t), t);
    for (let s = 0; s < n; s++) {
      const ts = n === 1 ? t : t + ((s + .5) / n - .5) * .5 / meta.fps;   // 180-degree shutter centred on the frame
      await shot(ts, path.join(out, `${String(f).padStart(4, '0')}_${s}.jpg`));
      if (s === 0 || n === 1) {
        await page.evaluate(t => F.draw(t), t);
        const r = await page.evaluate(() => F.audit());
        r.read.forEach(x => seen.set(x, (seen.get(x) || 0) + 1));
        r.edge.forEach(x => edge.set(x.name, [...(edge.get(x.name) || []), f]));
        r.safe.forEach(x => safe.set(x.name, [...(safe.get(x.name) || []), f]));
      }
    }
    if (f % 150 === 0) console.log('frame', f, '/', f1);
  }
  // reading-time audit: 200 wpm = 9 frames per word, plus 8 frames to find the line
  const short = [...seen].map(([txt, fr]) => { const w = txt.split(/\s+/).filter(Boolean).length; return { txt, w, fr, need: w * 9 + 8 }; }).filter(x => x.fr < x.need);
  const report = { frames: [f0, f1], edge: Object.fromEntries(edge), safe: Object.fromEntries(safe), readingShort: short };
  fs.writeFileSync(path.join(__dirname, 'audit.json'), JSON.stringify(report, null, 1));
  console.log('edge:', edge.size, 'safe-zone:', safe.size, 'reading-short:', short.length, '(details in audit.json)');
  await browser.close();
})();
