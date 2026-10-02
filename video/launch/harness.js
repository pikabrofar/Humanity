const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DOCS = path.join(__dirname, '../../docs');
const V = path.join(__dirname, 'vendor');
const MAP = {
  'https://cdn.jsdelivr.net/npm/lenis@1.3.26/dist/lenis.min.js': null, // no smooth-scroll lib: we drive scrollY directly
  'https://cdn.jsdelivr.net/npm/gsap@3.13.0/dist/gsap.min.js': V + '/gsap-3.13.0/package/dist/gsap.min.js',
  'https://cdn.jsdelivr.net/npm/gsap@3.13.0/dist/SplitText.min.js': V + '/gsap-3.13.0/package/dist/SplitText.min.js',
  'https://cdn.jsdelivr.net/npm/three@0.170.0/build/three.module.min.js': V + '/three-0.170.0/package/build/three.module.min.js',
};
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.svg': 'image/svg+xml', '.css': 'text/css' };

async function open({ w = 540, h = 960, dpr = 2, page: url = 'https://sentidos.local/index.html' } = {}) {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--hide-scrollbars'] });
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
  await ctx.addInitScript({ path: path.join(__dirname, 'vtime.js') });
  await ctx.route('**/*', async route => {
    const u = route.request().url();
    if (u in MAP) {
      if (!MAP[u]) return route.fulfill({ status: 200, contentType: 'text/javascript', body: '' });
      return route.fulfill({ status: 200, contentType: 'text/javascript', headers: { 'access-control-allow-origin': '*' }, body: fs.readFileSync(MAP[u]) });
    }
    if (u.startsWith('https://sentidos.local/')) {
      let p = decodeURIComponent(new URL(u).pathname);
      const base = p.startsWith('/cards/') ? __dirname : DOCS;
      const f = path.join(base, p);
      if (!fs.existsSync(f)) return route.fulfill({ status: 404, body: '' });
      return route.fulfill({ status: 200, contentType: TYPES[path.extname(f)] || 'application/octet-stream', body: fs.readFileSync(f) });
    }
    if (/fonts\.(googleapis|gstatic)\.com/.test(u)) return route.continue();
    return route.fulfill({ status: 404, body: '' });
  });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.error('pageerror', e.message));
  await page.goto(url, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  return { browser, page };
}

// Let real time pass (for async loads like the WebGL module) while virtual time stands still.
async function settle(page, ms = 1500) { await page.waitForTimeout(ms); }

module.exports = { open, settle };
