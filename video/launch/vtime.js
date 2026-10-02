// Virtual clock: the page only advances when the harness calls __advance(ms).
(() => {
  let vt = 0;
  const t0 = 1790000000000;
  const raf = new Map(); let rid = 1;
  const timers = new Map(); let tid = 1;
  performance.now = () => vt;
  const RD = Date;
  function VDate(...a) { return a.length ? new RD(...a) : new RD(t0 + vt); }
  VDate.prototype = RD.prototype; VDate.now = () => t0 + vt; VDate.UTC = RD.UTC; VDate.parse = RD.parse;
  window.Date = VDate;
  window.requestAnimationFrame = cb => { const id = rid++; raf.set(id, cb); return id; };
  window.cancelAnimationFrame = id => { raf.delete(id); };
  window.setTimeout = (fn, ms = 0, ...a) => { const id = tid++; timers.set(id, { at: vt + Math.max(0, +ms || 0), fn, a }); return id; };
  window.clearTimeout = id => { timers.delete(id); };
  window.setInterval = (fn, ms = 0, ...a) => { const id = tid++; const iv = Math.max(4, +ms || 0); timers.set(id, { at: vt + iv, fn, a, iv }); return id; };
  window.clearInterval = id => { timers.delete(id); };
  const syncAnims = () => {
    for (const an of document.getAnimations()) {
      if (an.__v0 === undefined) { an.__v0 = vt; try { an.pause(); } catch (e) {} }
      try { an.currentTime = vt - an.__v0; } catch (e) {}
    }
  };
  window.__vt = () => vt;
  window.__advance = (ms) => {
    const target = vt + ms;
    for (;;) {
      let best = null, bid = 0;
      for (const [id, t] of timers) if (t.at <= target && (!best || t.at < best.at)) { best = t; bid = id; }
      if (!best) break;
      vt = Math.max(vt, best.at);
      if (best.iv) best.at += best.iv; else timers.delete(bid);
      try { typeof best.fn === 'function' ? best.fn(...best.a) : eval(best.fn); } catch (e) { console.error(e); }
    }
    vt = target;
    window.dispatchEvent(new Event('scroll'));
    const q = [...raf]; raf.clear();
    for (const [, cb] of q) { try { cb(vt); } catch (e) { console.error(e); } }
    syncAnims();
  };
})();
