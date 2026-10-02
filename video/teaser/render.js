// Renders teaser.html frame by frame to frames/NNNN.jpg at 1080x1920 and writes events.json.
// usage: node render.js [outDir] [from] [to]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');

const OUT = process.argv[2] || path.join(__dirname, 'frames');
const FROM = +(process.argv[3] || 0), TO = process.argv[4] ? +process.argv[4] : null;

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--hide-scrollbars'] });
  const page = await browser.newPage({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 2 });
  await page.route('**/*', r => {
    const u = r.request().url();
    if (u === 'https://teaser.local/') return r.fulfill({ contentType: 'text/html', body: fs.readFileSync(path.join(__dirname, 'teaser.html')) });
    if (u.startsWith('https://teaser.local/fonts/')) { const f = path.join(__dirname, 'fonts', path.basename(new URL(u).pathname));
      return r.fulfill({ contentType: f.endsWith('.css') ? 'text/css' : 'font/woff2', body: fs.readFileSync(f) }); }
    return r.fulfill({ status: 404, body: '' });
  });
  page.on('pageerror', e => console.error('pageerror', e.message));
  await page.goto('https://teaser.local/', { waitUntil: 'load' });
  await page.evaluate(sym => { document.getElementById('defs').innerHTML = sym; return Promise.all(['600 22px "Instrument Sans"', '400 13px "Fragment Mono"'].map(f => document.fonts.load(f))).then(() => document.fonts.ready).then(() => { if (!document.fonts.check('600 22px "Instrument Sans"') || ![...document.fonts].some(f => f.status === 'loaded')) throw new Error('fonts did not load'); }); }, fs.readFileSync(path.join(__dirname, 'brand-symbols.svgfrag'), 'utf8'));
  const total = await page.evaluate(() => window.TOTAL);
  fs.writeFileSync(path.join(__dirname, 'events.json'), JSON.stringify({ total, fps: 30, events: await page.evaluate(() => window.EV) }, null, 1));
  const bad = [];
  for (let f = FROM; f < (TO ?? total); f++) {
    const o = await page.evaluate(f => { window.draw(f); return window.overflow(); }, f);
    if (o.length) bad.push([f, o]);
    await page.screenshot({ path: path.join(OUT, String(f).padStart(4, '0') + '.jpg'), type: 'jpeg', quality: 95 });
  }
  if (bad.length) { console.log('TEXT OUTSIDE FRAME on', bad.length, 'frames'); bad.slice(0, 12).forEach(b => console.log(JSON.stringify(b))); }
  else console.log('all text inside the frame');
  await browser.close();
})();
