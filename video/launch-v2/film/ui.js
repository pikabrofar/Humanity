// macOS UI inside the screen crop. Coordinates are screen-crop CSS px (the crop is 504 wide; 1 pt = 1.25 px).
// Everything the app itself draws (gaze ring, dwell arc, manoS HUD ring, bocaS pill, QuickPanel) follows the SwiftUI source.
(() => {
const { el, $ } = F;
const W = () => UI.parent || $('#windows');
const pos = (e, x, y, w, h) => { e.style.left = x + 'px'; e.style.top = y + 'px'; if (w) e.style.width = w + 'px'; if (h) e.style.height = h + 'px'; return e; };
const bar = (title, extra = '') => `<div class="bar"><div class="tl"><i></i><i></i><i></i></div>${extra}<span style="flex:1;text-align:center;margin-right:40px">${title}</span></div>`;
const UI = window.UI = {};

UI.mail = (id, o = {}) => pos(el('div', 'win', `
  <div class="bar"><div class="tl"><i></i><i></i><i></i></div>
    <span class="btn blue send" style="margin-left:10px">${G.plane}<span>Send</span></span><span style="flex:1;text-align:center;margin-right:70px">${o.title || 'New Message'}</span></div>
  <div class="field">To: <b>Ana Ruiz</b></div>
  <div class="field">Subject: <b>${o.subject || 'Launch day'}</b></div>
  <div class="body" style="padding:14px 16px;font:400 calc(13 * var(--pt))/1.45 var(--sans);color:#e9e9eb;min-height:120px">${o.body || ''}</div>`, W()), o.x ?? 26, o.y ?? 58, o.w ?? 452, o.h);

UI.doc = (id, o = {}) => pos(el('div', 'win', `${bar('Field Notes')}
  <div style="padding:16px 22px 18px;font:400 calc(13 * var(--pt))/1.62 var(--sans);color:#d9d9dc">
    <div style="font:700 calc(18 * var(--pt))/1.2 var(--sans);color:#fff;margin-bottom:10px">Reading with your eyes</div>
    <p style="margin:0" class="txt">Your eyes don't glide across a page. They jump from word to word in quick saccades, and rest in short fixations while you read.</p>
  </div>`, W()), o.x ?? 26, o.y ?? 58, o.w ?? 452);

UI.browser = (id, o = {}) => pos(el('div', 'win', `
  <div class="bar"><div class="tl"><i></i><i></i><i></i></div>
    <span style="flex:1;margin:0 10px;height:28px;border-radius:8px;background:rgba(255,255,255,.08);display:flex;align-items:center;justify-content:center;font:500 calc(11.5 * var(--pt))/1 var(--sans);color:#c9c9cc">Release notes</span></div>
  <div class="pages" style="position:relative;height:250px;overflow:hidden">
    <div class="pg p1" style="position:absolute;inset:0;padding:18px 22px">
      <div style="font:700 calc(19 * var(--pt))/1.15 var(--sans);color:#fff">sentidoS 1.0</div>
      <div style="margin-top:8px;font:400 calc(12.5 * var(--pt))/1.5 var(--sans);color:#bdbdc1">Three senses for your Mac, in one menu bar app.</div>
      <div class="lnk" style="margin-top:16px;display:inline-block;font:600 calc(13 * var(--pt))/1.4 var(--sans);color:#3d9cff">What's new in 1.0 →</div>
      <div style="margin-top:12px;font:400 calc(12.5 * var(--pt))/1.5 var(--sans);color:#8e8e93">Install guide · Privacy · Changelog</div>
    </div>
    <div class="pg p2" style="position:absolute;inset:0;padding:18px 22px;background:#1f1f22">
      <div style="font:700 calc(19 * var(--pt))/1.15 var(--sans);color:#fff">What's new</div>
      <div style="margin-top:10px;display:grid;gap:9px;font:500 calc(12.5 * var(--pt))/1.3 var(--sans);color:#e2e2e5">
        <div><b style="color:#3d9cff">ojoS</b> · gaze cursor and dwell clicks</div>
        <div><b style="color:#c97af7">manoS</b> · pinch, drag and flick</div>
        <div><b style="color:#ffa31a">bocaS</b> · dictation that cleans itself up</div></div>
    </div></div>`, W()), o.x ?? 26, o.y ?? 58, o.w ?? 452);

const PHOTO = ['linear-gradient(160deg,#ffb36b,#e0563f 60%,#7a1f4a)', 'linear-gradient(200deg,#7fd3ff,#2b6fd6 60%,#1b2a6b)', 'linear-gradient(170deg,#ffe08a,#f3a23c 55%,#a8502a)',
  'linear-gradient(150deg,#b9f5c9,#38b07a 55%,#14513f)', 'linear-gradient(190deg,#f7b6e8,#b052c9 55%,#4b1d6b)', 'linear-gradient(165deg,#ffd0b0,#ff7d6b 50%,#9b2f4f)'];
UI.photos = (id, o = {}) => pos(el('div', 'win', `${bar('Photos')}
  <div style="display:flex;height:236px">
    <div style="width:118px;padding:12px 10px;background:#232327;font:500 calc(11 * var(--pt))/1 var(--sans);color:#bdbdc1;display:grid;align-content:start;gap:8px">
      <div style="font:600 calc(9.5 * var(--pt))/1 var(--sans);color:#6e6e73;letter-spacing:.04em">ALBUMS</div>
      <div class="alb" style="padding:7px 8px;border-radius:7px">Favorites</div>
      <div class="alb target" style="padding:7px 8px;border-radius:7px;display:flex;justify-content:space-between">Launch<span class="cnt" style="color:#8e8e93">3</span></div>
      <div class="alb" style="padding:7px 8px;border-radius:7px">Trips</div></div>
    <div class="grid" style="flex:1;padding:12px;display:grid;grid-template-columns:repeat(3,1fr);gap:8px;align-content:start">
      ${PHOTO.map((p, i) => `<div class="ph" data-i="${i}" style="height:96px;border-radius:7px;background:${p}"></div>`).join('')}</div></div>`, W()), o.x ?? 26, o.y ?? 52, o.w ?? 452);

UI.slides = (id, o = {}) => {
  const S = [['Launch plan', 'Q4 · sentidoS 1.0'], ['1. Ship it', 'Free for every Mac on Apple silicon'], ['2. Tell everyone', 'One video. Three senses.']];
  return pos(el('div', 'win', `<div class="deck" style="position:relative;height:100%;overflow:hidden;background:#0d0d10">
    ${S.map(([a, b], i) => `<div class="sl" style="position:absolute;inset:0;display:grid;align-content:center;padding:0 34px;background:${['linear-gradient(135deg,#1b1530,#0d0d10)', 'linear-gradient(135deg,#2b1622,#0d0d10)', 'linear-gradient(135deg,#132433,#0d0d10)'][i]}">
      <div style="font:400 calc(10 * var(--pt))/1 var(--mono);letter-spacing:.14em;color:#8e8e93">${String(i + 1).padStart(2, '0')} / 03</div>
      <div style="margin-top:10px;font:700 calc(26 * var(--pt))/1.05 var(--sans);letter-spacing:-.03em;color:#fff">${a}</div>
      <div style="margin-top:8px;font:400 calc(12.5 * var(--pt))/1.4 var(--sans);color:#bdbdc1">${b}</div></div>`).join('')}</div>`, W()), o.x ?? 26, o.y ?? 52, o.w ?? 452, o.h ?? 250);
};

UI.dialog = (id, o = {}) => {
  const back = pos(el('div', 'win', `${bar('Launch plan — Edited')}<div style="padding:18px 22px;font:400 calc(12.5 * var(--pt))/1.6 var(--sans);color:#8e8e93">Ship on Thursday. Tell support. Schedule the announcement…</div>`, W()), 26, 50, 452, 250);
  const d = pos(el('div', 'win', `<div style="padding:20px 20px 16px;display:grid;gap:14px">
      <div style="display:flex;gap:14px;align-items:flex-start">
        <svg viewBox="0 0 120 120" style="width:46px;height:46px;flex:none"><use href="#app-sentidos"/></svg>
        <div><div style="font:700 calc(13 * var(--pt))/1.3 var(--sans);color:#fff">Do you want to save the changes you made to “Launch plan”?</div>
        <div style="margin-top:5px;font:400 calc(11 * var(--pt))/1.35 var(--sans);color:#a1a1a6">Your changes will be lost if you don't save them.</div></div></div>
      <div style="display:flex;gap:8px"><span class="btn">Don't Save</span><span style="flex:1"></span><span class="btn">Cancel</span><span class="btn blue save">Save</span></div></div>`, W()), 50, 92, 404);
  d.style.background = '#2a2a2e';
  return { back, d };
};

UI.note = (id, o = {}) => pos(el('div', 'win', `${bar('Library')}
  <div style="padding:14px 16px">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px"><svg viewBox="0 0 120 120" style="width:26px;height:26px"><use href="#app-bocas"/></svg>
      <div style="font:600 calc(12.5 * var(--pt))/1 var(--sans)">Voice note</div><div style="margin-left:auto;font:400 calc(11 * var(--pt))/1 var(--mono);color:#8e8e93">1:48</div></div>
    <div class="card" style="padding:14px 16px;border-radius:calc(14 * var(--pt));background:rgba(255,255,255,.05);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)">
      <div style="display:flex;gap:7px;align-items:center;font:600 calc(12.5 * var(--pt))/1 var(--sans)"><span style="width:16px;height:16px;color:#ffd60a">${G.sparkles}</span>Summary</div>
      <div class="sum" style="margin-top:8px;font:400 calc(11.5 * var(--pt))/1.45 var(--sans);color:#d1d1d6">The launch moves to Thursday. Ana updates the release notes tonight, and the announcement waits until Friday.</div>
      <div style="margin-top:10px;font:600 calc(11.5 * var(--pt))/1 var(--sans)">Action items</div>
      <div class="items" style="margin-top:8px;display:grid;gap:7px;font:400 calc(11.5 * var(--pt))/1.2 var(--sans);color:#e5e5ea">
        ${['Update the release notes', 'Tell support about the new date', 'Schedule the announcement for Friday'].map(t => `<div class="it" style="display:flex;gap:8px;align-items:center"><span class="ck" style="width:16px;height:16px;flex:none;color:#8e8e93">${G.circle}</span>${t}</div>`).join('')}
      </div></div></div>`, W()), o.x ?? 26, o.y ?? 50, o.w ?? 452);

// ---- the app's overlays
UI.gaze = () => {
  const g = el('div', 'gaze', `<svg viewBox="-14 -14 28 28"><circle r="12" fill="none" stroke="rgba(10,132,255,.35)" stroke-width="2.4"/><circle class="arc" r="12" fill="none" stroke="#0a84ff" stroke-width="4" stroke-linecap="round" transform="rotate(-90)" stroke-dasharray="75.4" stroke-dashoffset="75.4"/></svg>`, $('#screen'));
  g.set = (x, y, o = {}) => {
    g.style.left = x + 'px'; g.style.top = y + 'px'; g.style.opacity = o.alpha ?? 1;
    g.style.transform = `scale(${o.scale ?? 1})`;
    const svg = g.querySelector('svg'); svg.style.opacity = o.dwell != null ? 1 : 0;
    g.querySelector('.arc').setAttribute('stroke-dashoffset', 75.4 * (1 - (o.dwell || 0)));
  };
  return g;
};
UI.pointer = () => {
  const p = el('div', 'ptr', `${G.pointer}<svg class="hudr" viewBox="-15 -15 30 30"><circle r="15" fill="rgba(0,0,0,.25)"/><circle r="12" fill="none" stroke="rgba(255,255,255,.35)" stroke-width="3"/><circle class="arc" r="12" fill="none" stroke="#0a84ff" stroke-width="3" stroke-linecap="round" transform="rotate(-90)" stroke-dasharray="75.4" stroke-dashoffset="75.4"/><g class="sym" transform="translate(-6.5,-6.5) scale(.54)" style="color:#fff"></g></svg>`, $('#screen'));
  p.set = (x, y, o = {}) => {
    p.style.left = (x - 3) + 'px'; p.style.top = (y - 3) + 'px'; p.style.opacity = o.alpha ?? 1;
    const h = p.querySelector('.hudr'); h.style.opacity = o.hud ?? 0;
    const arc = p.querySelector('.arc'); arc.setAttribute('stroke-dashoffset', 75.4 * (1 - (o.ring || 0))); arc.setAttribute('stroke', o.color || '#0a84ff');
    const sym = p.querySelector('.sym'); if (sym._s !== o.sym) { sym._s = o.sym; sym.innerHTML = o.sym ? G[o.sym].replace('<svg', '<svg width="24" height="24"') : ''; }
  };
  return p;
};
UI.pill = () => {
  const p = el('div', 'pill', `<span class="rec"></span><span class="lv">${'<i></i>'.repeat(5)}</span><span class="msg"><span></span></span><span class="esc">esc</span>`, $('#screen'));
  p.set = (o) => {
    p.style.left = o.x + 'px'; p.style.top = o.y + 'px'; p.style.width = o.w + 'px'; p.style.opacity = o.alpha ?? 1;
    p.style.transform = `scale(${o.scale ?? 1})`;
    p.querySelector('.rec').style.opacity = .35 + .65 * (.5 + .5 * Math.cos(o.t * Math.PI / .8));
    const prof = [.45, .75, 1, .75, .45];
    p.querySelectorAll('.lv i').forEach((b, i) => { b.style.height = (4 + 16 * (o.level || 0) * prof[i]) * 1.25 + 'px'; });
    const m = p.querySelector('.msg span'); if (m._h !== o.html) { m._h = o.html; m.innerHTML = o.html; }
    m.style.color = o.live ? '#fff' : 'rgba(255,255,255,.6)';
  };
  return p;
};
// QuickPanel: width 236 pt, padding 14, three 34 pt tiles, "Open sentidoS" capsule and an ellipsis button
UI.panel = (parent) => {
  const T = [['ojoS', 'eye', '#0a84ff', 'Tracking'], ['manoS', 'hand', '#bf5af2', 'Active'], ['bocaS', 'wave', '#ff9f0a', 'Ready']];
  const p = el('div', 'qpanel', `<div class="tiles">${T.map(([n, g, c, on]) => `<div class="tile" data-c="${c}" data-on="${on}"><div class="cb">${G[g]}</div><div class="nm">${n}</div><div class="st">Off</div></div>`).join('')}</div>
    <div class="bot"><span class="open">Open sentidoS</span><span class="more">···</span></div>`, parent);
  return p;
};
})();
