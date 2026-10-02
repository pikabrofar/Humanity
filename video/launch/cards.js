const fs = require('fs');
const { open } = require('./harness');
const { SHOTS } = require('./shots');
(async () => {
  const { browser, page } = await open({ page: 'https://sentidos.local/cards/cards.html' });
  await page.waitForTimeout(800);
  const cdp = await page.context().newCDPSession(page);
  for (const s of SHOTS.filter(s => s.kind === 'card')) {
    const dir = `frames/${s.name}`; fs.mkdirSync(dir, { recursive: true });
    for (let f = 0; f < s.frames; f++) {
      await page.evaluate(([c, f]) => window.draw(c, f), [s.card, f]);
      const r = await cdp.send('Page.captureScreenshot', { format: 'jpeg', quality: 94 });
      fs.writeFileSync(`${dir}/${String(f).padStart(4, '0')}.jpg`, Buffer.from(r.data, 'base64'));
    }
    console.log(s.name, s.frames);
  }
  await browser.close();
})();
