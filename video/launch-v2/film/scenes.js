// The launch film, beat by beat. Times in seconds. See LAUNCH_PLAN.md §3 for the beat sheet.
(() => {
const { $, $$, el, show, clamp, seg, lerp, e, spring, springU, hops, ev, fast } = F;
const T = F.T = {
  hook: [0, 3.1], title: [2.95, 6.35], eyes1: [6.0, 9.5], eyes2: [9.5, 13.0], hands1: [13.0, 16.8], hands2: [16.8, 20.5],
  peak: [20.5, 25.5], voice1: [25.5, 31.0], voice2: [31.0, 33.0], trust: [33.0, 38.0], device: [38.0, 41.0], cta: [41.0, 47.4],
};
F.DUR = 47.4;
const SCR = [18, 464];                         // the screen crop's page offset
const inT = (t, r) => t >= r[0] && t < r[1];
const lookFor = ([x, y]) => [(x - 252) / 252 * .5, -.06 + y / 300 * .46];   // mirrored selfie view: looking left on screen = left here
const ctr = (n, base = $('#screen')) => { const r = n.getBoundingClientRect(), s = base.getBoundingClientRect(); return [r.left - s.left + r.width / 2, r.top - s.top + r.height / 2]; };
const hash = n => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };

// ======================================================================= build
const split = $('#Lsplit'), full = $('#Lfull'), topCv = $('#topCv'), g = topCv.getContext('2d');
const irisCv = $('#irisGL'), tag = $('#topTag'), mac = $('#mac'), screenEl = $('#screen'), win = $('#windows');
const SP = {}, ORDER = [[0, 'mail', 'Mail'], [6.0, 'doc', 'Notes', 'cut'], [9.5, 'browser', 'Safari'], [13.0, 'photos', 'Photos'], [16.8, 'slides', 'Keynote'],
  [20.5, 'dialog', 'Pages'], [25.5, 'mail2', 'Mail'], [31.0, 'note', 'sentidoS']];
ORDER.forEach(([, k]) => { SP[k] = el('div', 'space', null, win); SP[k].style.cssText = 'position:absolute;inset:0;'; });
const mk = (k, f) => { UI.parent = SP[k]; const r = f(); UI.parent = null; return r; };
const W = {
  mail: mk('mail', () => UI.mail('m1', { subject: 'Launch day', body: 'Hi Ana,<br>It’s ready. We ship today.' })),
  doc: mk('doc', () => UI.doc('d1')),
  browser: mk('browser', () => UI.browser('b1')),
  photos: mk('photos', () => UI.photos('p1')),
  slides: mk('slides', () => UI.slides('s1')),
  dialog: mk('dialog', () => UI.dialog('dl')),
  mail2: mk('mail2', () => UI.mail('m2', { subject: 'Launch date', body: '<span class="ins"></span><span class="caret"></span>' })),
  note: mk('note', () => UI.note('n1')),
};
const gaze = UI.gaze(), ptr = UI.pointer(), pill = UI.pill();
const raw = el('canvas', null, null, screenEl); raw.width = 1008; raw.height = 1200; raw.style.cssText = 'position:absolute;left:0;top:0;width:504px;height:600px;z-index:24;pointer-events:none';
const rg = raw.getContext('2d');
$('#mbIcon').innerHTML = G.figure; $('#mbWifi').innerHTML = G.wifi;
$('#clock').insertAdjacentHTML('beforebegin', `<span class="si" style="width:30px">${G.battery}</span>`);
// caret
const caretCss = el('style', null, '.caret{display:inline-block;width:2px;height:1.2em;vertical-align:-.22em;background:#0a84ff;margin-left:1px}.ins{border-radius:4px}', document.head);

// HUD: three senses
const HUD = $('#hud'); HUD.innerHTML = [['eye', '#3d9cff'], ['hand', '#c97af7'], ['wave', '#ffa31a']].map(([gl, c]) => `<div class="s" data-c="${c}">${G[gl]}</div>`).join('');
const hudS = $$('.s', HUD);

// big keycaps for the voice panel
const bigKeys = el('div', null, ['⌃', '⌥', '⌘', 'D'].map(k => `<span class="key">${k}</span>`).join(''), $('#top'));
bigKeys.style.cssText = 'position:absolute;left:0;right:0;top:40px;text-align:center;font:600 40px/1 var(--sans);z-index:4;display:none';
// the split-panel divider (look + pinch)
const divider = el('div', null, null, $('#Lsplit')); divider.style.cssText = 'position:absolute;top:116px;height:236px;left:266px;width:8px;background:#000;z-index:3;display:none';
const tag2 = el('div', 'tag', '<i></i><span>Camera · manoS</span>', $('#Lsplit')); tag2.id = 'topTag2'; tag2.style.cssText = 'position:absolute;left:290px;top:130px;z-index:4;font:400 10.5px/1 var(--mono);letter-spacing:.14em;text-transform:uppercase;color:rgba(255,255,255,.55);display:none;align-items:center;gap:7px';
tag2.querySelector('i').style.cssText = 'width:6px;height:6px;border-radius:50%;background:#30d158;box-shadow:0 0 8px #30d158;display:block';

// full-frame layers
const trust = el('div', null, `<canvas id="tCv" width="1080" height="1920" style="position:absolute;left:0;top:0;width:540px;height:960px"></canvas>`, full);
trust.id = 'trustL'; trust.style.cssText = 'position:absolute;inset:0;display:none';
const tCv = $('#tCv'), tg = tCv.getContext('2d');

const dev = el('div', null, `<div id="devWorld" style="position:absolute;inset:0;perspective:1400px;perspective-origin:270px 300px">
  <div id="mb" style="position:absolute;left:30px;top:150px;width:480px;transform-style:preserve-3d">
    <div id="lid" style="position:relative;width:480px;height:312px;border-radius:20px 20px 8px 8px;background:#0a0a0b;box-shadow:inset 0 0 0 2px #2d2d31, 0 30px 80px rgba(0,0,0,.6)">
      <div id="dScreen" style="position:absolute;left:12px;top:12px;right:12px;bottom:14px;border-radius:10px;overflow:hidden;background:#160b12">
        <div style="position:absolute;inset:-20px;background:radial-gradient(55% 45% at 22% 70%,rgba(214,104,64,.55),transparent 70%),radial-gradient(50% 40% at 85% 25%,rgba(231,140,64,.45),transparent 70%),radial-gradient(70% 60% at 60% 95%,rgba(140,40,90,.55),transparent 70%),linear-gradient(165deg,#2a1024,#120810 55%,#1d0a18)"></div>
        <div id="dMenu" style="position:absolute;left:0;right:0;top:0;height:13px;display:flex;align-items:center;gap:7px;padding:0 7px;font:500 6.4px/1 var(--sans);color:#fff;background:rgba(20,8,16,.4)">
          <b style="font-weight:700">Finder</b><span>File</span><span>Edit</span><span>View</span><span style="margin-left:auto;display:flex;gap:6px;align-items:center"><span id="dIcon" style="width:12px;height:10px;border-radius:3px;display:grid;place-items:center"><span style="width:8px;height:8px;display:block">${G.figure}</span></span><span>Thu 9:41</span></span></div>
        <div id="dNotch" style="position:absolute;left:50%;top:0;width:66px;height:13px;margin-left:-33px;border-radius:0 0 6px 6px;background:#0a0a0b"></div>
        <div id="dPanelWrap" style="position:absolute;right:20px;top:17px;transform-origin:85% 0"></div>
      </div>
    </div>
    <div style="position:absolute;left:-40px;right:-40px;top:312px;height:330px;transform-origin:50% 0;transform:rotateX(90deg);border-radius:8px 8px 26px 26px;background:linear-gradient(#cfd2d7,#9fa2a8)">
      <div style="position:absolute;left:34px;right:34px;top:20px;height:128px;border-radius:8px;background:repeating-linear-gradient(90deg,#1d1e21 0 26px,transparent 26px 29px),repeating-linear-gradient(0deg,#1d1e21 0 22px,transparent 22px 25px);opacity:.92"></div>
      <div style="position:absolute;left:50%;top:166px;width:210px;height:130px;margin-left:-105px;border-radius:10px;background:linear-gradient(#c3c6cb,#b3b6bc);box-shadow:inset 0 0 0 1px rgba(0,0,0,.12)"></div></div>
    <div style="position:absolute;left:-40px;right:-40px;top:312px;height:11px;border-radius:0 0 18px 18px;background:linear-gradient(#d9dbe0,#8d9097);box-shadow:0 18px 40px rgba(0,0,0,.6)"><i style="position:absolute;left:50%;top:0;width:76px;height:5px;margin-left:-38px;border-radius:0 0 7px 7px;background:#9a9da3"></i></div>
  </div></div>`, full);
dev.id = 'devL'; dev.style.cssText = 'position:absolute;inset:0;display:none';
const panel = UI.panel($('#dPanelWrap')); panel.style.cssText += ';position:relative;--pt:.5px';

const cta = el('div', null, `
  <div id="wm" class="big" style="top:410px;font-size:82px;letter-spacing:-.055em" data-safe></div>
  <div id="tagl" class="big" style="top:518px;font-size:27px;line-height:1.22;letter-spacing:-.02em" data-safe data-read>Control your Mac with your<br><em style="color:#3d9cff">eyes</em>, <em style="color:#c97af7">hands</em> and <em style="color:#ffa31a">voice</em>.</div>
  <div id="cPill" data-safe data-read style="position:absolute;left:50%;top:612px;transform:translateX(-50%);white-space:nowrap;padding:12px 20px;border-radius:99px;background:var(--brand);color:var(--ink);font:600 19px/1 var(--sans);box-shadow:0 0 60px rgba(245,136,65,.45)">Free for Mac · Out now</div>
  <div id="cUrl" data-safe data-read style="position:absolute;left:0;right:0;top:672px;text-align:center;font:600 19px/1 var(--sans);letter-spacing:-.01em;color:#fff">pikabrofar.github.io/sentidoS</div>
  <div id="cBio" data-safe data-read style="position:absolute;left:0;right:0;top:706px;text-align:center;font:500 15px/1 var(--sans);color:var(--fg2)">Link in bio · macOS 14+ · Apple silicon</div>`, full);
cta.id = 'ctaL'; cta.style.cssText = 'position:absolute;inset:0;display:none';
$('#wm').innerHTML = [...'sentido'].map(c => `<span class="m" style="display:inline-block;overflow:hidden;padding:.06em .01em .14em;margin:-.06em -.01em -.14em;vertical-align:bottom"><span class="c" style="display:inline-block">${c}</span></span>`).join('') + '<span class="m" style="display:inline-block;overflow:hidden;padding:.06em .01em .14em;margin:-.06em -.01em -.14em;vertical-align:bottom"><b class="c" style="display:inline-block;color:var(--brand);font-weight:inherit">S</b></span>';

// ======================================================================= headlines
const K = s => [...s].map(k => `<span class="key">${k}</span>`).join('');
F.head('It clicks where<br>you look.', .15, 2.5);
F.head('Meet sentido<em style="color:var(--brand)">S</em>.', 4.45, 6.0, { top: 520, size: 56 });
F.label('Spanish for “senses”', 4.75, 6.0, 592, { color: '#a1a1a6' });
F.head('Steady while<br>you read.', 6.35, 9.3);
const hG = F.head(`Look, then press<br>${K('⌃⌥⌘G')}`, 9.75, 12.8);
F.head('Pinch to click.<br>Hold to drag.', 13.35, 16.6);
F.head('Flick a V for<br>the next slide.', 17.05, 20.3);
F.head('Look at it.<br>Pinch to click.', 20.75, 23.35);
F.head('No headset<br>required.', 23.8, 25.3, { slam: true, size: 46 });
const hD = F.head(`Hold ${K('⌃⌥⌘D')}<br>and talk.`, 25.75, 28.3);
F.head('Let go. It types it,<br>cleaned up.', 28.5, 31.0);
F.head('Notes that<br>summarize themselves.', 31.15, 32.95);
F.head('Video and audio<br>never leave your Mac.', 33.4, 35.85, { top: 548 });
F.head('No account.<br>No subscription.<br>No telemetry.', 35.95, 38.0, { top: 540, size: 36 });
F.head('All three senses.<br>One menu bar app.', 38.35, 40.85, { top: 560 });

// ======================================================================= helpers per frame
function spaces(t) {
  let k = 0; ORDER.forEach(([t0], i) => { if (t >= t0) k = i; });
  ORDER.forEach(([t0, key, app, mode], i) => {
    const s = SP[key];
    if (i === k) {
      const swipe = mode !== 'cut' && i > 0 && t < t0 + .5;
      s.style.display = 'block'; s.style.transform = swipe ? `translateX(${(1 - e.io3(seg(t, t0, t0 + .5))) * 108}%)` : 'none';
      $('#appName').textContent = app;
    } else if (i === k - 1 && ORDER[k][3] !== 'cut' && t < ORDER[k][0] + .5) {
      s.style.display = 'block'; s.style.transform = `translateX(${-e.io3(seg(t, ORDER[k][0], ORDER[k][0] + .5)) * 108}%)`;
    } else s.style.display = 'none';
  });
}
const panelClip = (l, tp, r, b, rad = 28) => `inset(${tp}px ${r}px ${b}px ${l}px round ${rad}px)`;
function topReset() { g.setTransform(2, 0, 0, 2, 0, 0); g.clearRect(0, 0, 500, 236); }
function camBg(alpha = 1, x0 = 0, x1 = 500) { // camera-view backdrop: faint grid
  g.save(); g.beginPath(); g.rect(x0, 0, x1 - x0, 236); g.clip(); g.globalAlpha = alpha;
  g.strokeStyle = 'rgba(255,255,255,.045)'; g.lineWidth = 1;
  for (let x = x0 + 10; x < x1; x += 28) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, 236); g.stroke(); }
  for (let y = 10; y < 236; y += 28) { g.beginPath(); g.moveTo(x0, y); g.lineTo(x1, y); g.stroke(); }
  g.restore();
}
function hud(t) {
  const on = [6.2, 13.2, 25.7], pul0 = 38.9, vis = (t >= 6.0 && t < 33.3) || (t >= 38.3 && t < 41.0);
  HUD.style.display = vis ? 'flex' : 'none';
  HUD.style.opacity = vis ? e.o3(seg(t, 6.0, 6.4)) * (1 - seg(t, 33.0, 33.3)) * (t > 38 ? e.o3(seg(t, 38.3, 38.7)) : 1) * (1 - seg(t, 40.6, 41.0)) : 0;
  hudS.forEach((s, i) => {
    const k = e.o3(seg(t, on[i], on[i] + .25)), pulse = Math.max(0, 1 - Math.abs(t - (38.95 + i * .25)) / .25);
    const c = s.dataset.c;
    s.style.background = k > .5 ? c : 'rgba(255,255,255,.07)';
    s.style.boxShadow = k > .5 ? `0 0 ${10 + 18 * pulse}px ${c}` : 'inset 0 0 0 1px rgba(255,255,255,.12)';
    s.style.transform = `scale(${1 + .35 * Math.sin(Math.PI * seg(t, on[i], on[i] + .3)) + .25 * pulse})`;
    s.querySelector('svg').style.color = k > .5 ? '#fff' : 'rgba(255,255,255,.35)';
  });
}

// reading path for "Steady while you read": word rects from the paragraph
let WORDS = [], SEND, LINK, ITEMS, SAVE, PHOTO1, ALBUM, PHOTO_EL;
F.preps.push(() => {
  show(split, true); mac.style.transform = 'none'; split.style.transform = 'none';
  ORDER.forEach(([, k]) => { SP[k].style.display = 'block'; SP[k].style.transform = 'none'; });
  SEND = ctr($('.send', W.mail));
  const p = $('.txt', W.doc), tn = p.firstChild, txt = tn.textContent; let i = 0;
  txt.split(/(\s+)/).forEach(w => { if (w.trim()) { const r = document.createRange(); r.setStart(tn, i); r.setEnd(tn, i + w.length); const q = r.getBoundingClientRect(), s = screenEl.getBoundingClientRect(); WORDS.push([q.left - s.left + q.width / 2, q.top - s.top + q.height / 2]); } i += w.length; });
  LINK = ctr($('.lnk', W.browser)); ITEMS = $$('.p2 > div:nth-child(2) > div', W.browser).map(n => ctr(n));
  SAVE = ctr($('.save', W.dialog.d)); PHOTO_EL = $$('.ph', W.photos)[1]; PHOTO1 = ctr(PHOTO_EL); ALBUM = ctr($('.target', W.photos));
  ORDER.forEach(([, k]) => { SP[k].style.display = 'none'; });
  show(split, false);
  if (!SEND[0] || !SAVE[0] || !PHOTO1[0]) throw new Error('UI targets measured as zero');
});

// ======================================================================= beat: hook + split-screen grammar
const GZ = { // gaze keys per beat, in screen-crop coordinates
  hook: () => [[0, [214, 236]], [.27, SEND], [2.2, [252, 118]]],
  eyes1: () => { const k = [[6.0, WORDS[0]]]; const pick = [0, 2, 3, 5, 7, 8, 10, 12, 13, 15, 17, 18, 20]; pick.forEach((w, i) => WORDS[w] && k.push([6.15 + i * .26, WORDS[w]])); return k; },
  eyes2: () => [[9.5, [200, 70]], [10.05, LINK], [11.55, ITEMS[0]], [11.95, ITEMS[1]], [12.35, ITEMS[2]]],
  peak: () => [[20.5, [252, 60]], [21.25, SAVE]],
};
let gk = null;
const gazeAt = (t, keys, resp = .28) => hops(t, keys, resp);
const eyeAt = (t, keys) => { const p = hops(t, keys, .07); const tw = [Math.sin(t * 7.3) * 1.2, Math.cos(t * 5.1) * 1.0]; return lookFor([p[0] + tw[0], p[1] + tw[1]]); };

F.beats.push({ t0: 0, t1: T.hook[1], draw(t) {
  show(split, true); mac.style.transform = ''; mac.style.opacity = 1;
  const keys = GZ.hook();
  const pos = gazeAt(t, keys), look = eyeAt(t, keys);
  // the push through the pupil
  const pz = e.i3(seg(t, 2.5, 3.08)), clipK = e.io3(seg(t, 2.5, 2.95));
  irisCv.style.clipPath = panelClip(20 * (1 - clipK), 116 * (1 - clipK), 20 * (1 - clipK), 608 * (1 - clipK), 28 * (1 - clipK));
  const L = look.map(v => v * (1 - e.io3(seg(t, 2.2, 2.6))));
  const pr = [20 * (1 - clipK), 116 * (1 - clipK), 540 - 40 * (1 - clipK), 960 - 724 * (1 - clipK)];
  Iris.draw({ look: L, pupil: .3 + .04 * seg(t, 2.6, 3.0), zoom: 1 + 34 * pz, screen: .5 + .5 * Math.max(0, 1 - Math.abs(t - 1.9) / .3), cx: 270, cy: 238, panel: pr });
  topReset(); tag.style.display = 'flex'; tag.querySelector('span').textContent = 'Camera · ojoS'; tag.style.opacity = 1 - clipK;
  $('#led').classList.add('on');
  mac.style.transform = `translateY(${e.i3(seg(t, 2.45, 2.95)) * 520}px)`;
  spaces(t);
  // dwell 1.0 s (the default), click, send
  const dwell = seg(t, .62, 1.62), clicked = t >= 1.62;
  gaze.set(pos[0], pos[1], { dwell: t > .55 && !clicked ? dwell : null, alpha: 1 - seg(t, 2.3, 2.5), scale: 1 - .12 * Math.sin(Math.PI * seg(t, 1.62, 1.8)) });
  $('.send', W.mail).classList.toggle('dn', t >= 1.62 && t < 1.76);
  const se = e.io3(seg(t, 1.76, 2.2));
  W.mail.style.transform = `translate(${-10 * se}px, ${-300 * se * se}px) scale(${1 - .28 * se})`; W.mail.style.opacity = 1 - e.i2(se);
  ptr.style.display = 'none'; pill.style.display = 'none'; rg.clearRect(0, 0, 1008, 1200);
}});
ev(.27, 'lockon', { x: -.4 }); ev(.62, 'dwell', { dur: 1.0 }); ev(1.62, 'click', { hit: .35 }); ev(1.76, 'send'); ev(2.5, 'pupil'); fast(.25, .5); fast(1.74, 2.3); fast(2.5, 3.1);

// ======================================================================= beat: title (3D icon assembles out of the dark)
F.beats.push({ t0: T.title[0], t1: T.title[1] + .1, draw(t) {
  if (t < 3.1) show(split, true); else show(split, false);
  const l = t - 3.0;
  const rise = e.o4(seg(l, .3, 1.15)), settle = springU(l - .55, .9, .62);
  const drop = e.io3(seg(l, .95, 1.3)), milk = e.o3(seg(l, 1.2, 1.55));
  const fly = [0, 1, 2].map(i => e.o4(seg(l, i * .09, .85 + i * .09)));
  const EX = [[0, 1.05, 1.1], [-.95, -.45, .8], [.95, -.45, .5]];
  // after the title, the icon hands off to the HUD: it shrinks toward the senses lights
  const off = e.io3(seg(t, 6.0, 6.35));
  const discs = Logo.SPOT.map((sp, i) => {
    const f = fly[i], st = [EX[i][0] * 3.2, EX[i][1] * 3.2, -9];
    const ex = [lerp(st[0], EX[i][0], f), lerp(st[1], EX[i][1], f), lerp(st[2], EX[i][2], f)];
    return { x: lerp(ex[0], sp[0], drop), y: lerp(ex[1], sp[1], drop), z: lerp(ex[2], .03, drop), rz: (1 - f) * (i % 2 ? -5 : 5), s: lerp(.6, 1, f), milk, alpha: clamp(f * 3) };
  });
  Logo.draw({
    x: lerp(270, 270, off), y: lerp(330, 95, off), size: lerp(232, 40, off),
    rx: lerp(28, 0, settle) + Math.sin(l * 1.1) * 2 * seg(l, 1.6, 2.4), ry: lerp(-16, 0, settle) + Math.sin(l * .8) * 6 * seg(l, 1.6, 2.6), rz: lerp(-8, 0, settle),
    tileY: lerp(-3.6, 0, rise), tileRx: lerp(55, 0, rise), tileAlpha: clamp(rise * 2) * (1 - off), discs: discs.map(d => Object.assign(d, { alpha: d.alpha * (1 - off) })),
    keyX: lerp(-7, 7, e.io2(seg(l, 1.35, 2.6))), exposure: .9 + .25 * Math.max(0, 1 - Math.abs(l - 1.3) / .35),
  });
}});
ev(3.0, 'emerge'); ev(3.05, 'fly', { pan: 0 }); ev(3.14, 'fly', { pan: -.6 }); ev(3.23, 'fly', { pan: .6 }); ev(4.3, 'impact', { hit: .9, flash: '#ffffff' }); ev(4.42, 'shimmer'); ev(4.45, 'motif');
ev(6.0, 'whooshUp'); fast(2.95, 4.35); fast(6.0, 6.4);
F.always.push(t => { if (!(t >= T.title[0] && t < T.title[1] + .1) && !(t >= T.cta[0])) Logo.clear(); });

// ======================================================================= the split screen, beats 3–9
function irisPanel(t, keys, o = {}) {
  irisCv.style.display = 'block';
  irisCv.style.clipPath = o.clip || panelClip(20, 116, 20, 608);
  const look = eyeAt(t, keys);
  Iris.draw(Object.assign({ look, pupil: .29 + .015 * Math.sin(t * .9), screen: .55 }, o.iris || {}));
}
F.beats.push({ t0: T.eyes1[0], t1: T.voice2[1] + .45, draw(t) {
  show(split, true);
  const enter = e.o4(seg(t, 6.0, 6.45)), exit = e.io3(seg(t, 33.0, 33.45));
  split.style.opacity = enter * (1 - exit);
  split.style.transform = `scale(${(.94 + .06 * enter) * (1 - .06 * exit)})`;
  split.style.filter = exit > .01 ? `blur(${exit * 8}px)` : (enter < 1 ? `blur(${(1 - enter) * 6}px)` : '');
  mac.style.transform = ''; spaces(t); $('#led').classList.add('on');
  irisCv.style.display = 'none'; topReset(); tag.style.display = 'flex'; tag.style.opacity = 1; divider.style.display = 'none'; tag2.style.display = 'none'; bigKeys.style.display = 'none';
  gaze.style.display = 'none'; ptr.style.display = 'none'; pill.style.display = 'none'; rg.clearRect(0, 0, 1008, 1200);
  W.mail.style.transform = ''; W.mail.style.opacity = 1;
  if (t < T.eyes2[0]) eyes1(t);
  else if (t < T.hands1[0]) eyes2(t);
  else if (t < T.hands2[0]) hands1(t);
  else if (t < T.peak[0]) hands2(t);
  else if (t < T.voice1[0]) peak(t);
  else voice(t);
}});

function eyes1(t) {
  tag.querySelector('span').textContent = 'Camera · ojoS';
  const keys = GZ.eyes1(); irisPanel(t, keys);
  const p = gazeAt(t, keys);
  gaze.style.display = 'block'; gaze.set(p[0], p[1], {});
  // raw, noisy webcam estimates around the steady cursor
  rg.setTransform(2, 0, 0, 2, 0, 0); rg.clearRect(0, 0, 504, 600);
  const fi = Math.floor(t * 30);
  for (let k = 0; k < 9; k++) {
    const n = fi - k, a = hash(n) * 6.283, r = 10 + hash(n + .5) * 34, al = (1 - k / 9) * .8;
    const q = gazeAt(n / 30, keys, .05);
    rg.fillStyle = `rgba(120,190,255,${al})`; rg.shadowColor = '#3d9cff'; rg.shadowBlur = 6; rg.beginPath(); rg.arc(q[0] + Math.cos(a) * r, q[1] + Math.sin(a) * r, 3.4, 0, 7); rg.fill(); rg.shadowBlur = 0;
  }
  const la = seg(t, 6.6, 7.0); rg.font = '400 12px "Fragment Mono"'; rg.textAlign = 'left';
  rg.fillStyle = `rgba(120,190,255,${la})`; rg.beginPath(); rg.arc(40, 262, 4, 0, 7); rg.fill(); rg.fillText('RAW WEBCAM GAZE', 50, 266);
  rg.strokeStyle = `rgba(10,132,255,${la})`; rg.lineWidth = 2.5; rg.beginPath(); rg.arc(228, 262, 6, 0, 7); rg.stroke(); rg.fillStyle = `rgba(255,255,255,${la})`; rg.fillText('CURSOR, HELD STILL', 240, 266);
}
GZ.eyes1Keys = null;
function eyes2(t) {
  tag.querySelector('span').textContent = 'Camera · ojoS';
  const keys = GZ.eyes2(); irisPanel(t, keys);
  const p = gazeAt(t, keys);
  gaze.style.display = 'block'; gaze.set(p[0], p[1], { scale: 1 - .14 * Math.sin(Math.PI * seg(t, 11.05, 11.2)) });
  const keysEl = $$('.key', hG.box);
  keysEl.forEach((k, i) => k.classList.toggle('dn', t >= 10.85 + i * .07 && t < 11.25));
  const pg = e.io3(seg(t, 11.12, 11.5));
  $('.p1', W.browser).style.transform = `translateX(${-30 * pg}%)`; $('.p1', W.browser).style.opacity = 1 - pg;
  $('.p2', W.browser).style.transform = `translateX(${(1 - pg) * 100}%)`;
  $('.lnk', W.browser).style.textDecoration = t > 10.2 && t < 11.12 ? 'underline' : 'none';
}
[10.85, 10.92, 10.99, 11.06].forEach((tk, i) => ev(tk, 'key', { i })); ev(11.08, 'click', { hit: .3 }); ev(11.12, 'page');
ev(6.2, 'hud', { i: 0 }); [6.15, 6.41, 6.67, 6.93, 7.19, 7.45, 7.71, 7.97, 8.23, 8.49, 8.75, 9.01, 9.27].forEach(tk => ev(tk, 'saccade'));
ev(10.05, 'lockon', { x: -.2 }); ev(9.5, 'swipe'); fast(9.5, 10.0); fast(11.1, 11.5);

// ---- hands
const HAND = { yaw: -30, pitch: -10, roll: -8 };
function handIn(t, o) { return Object.assign({ x: 262, y: 230, s: 106, act: [], color: '#c97af7', link: true }, HAND, o); }
function morphIrisToHand(t, t0, handO) {
  const k = seg(t, t0, t0 + .62);
  if (k <= 0 || k >= 1) return false;
  const H = Hand.project(Hand.xform(Hand.pose(handO.pose), handO), handO), pts = Hand.joints(H);
  Hand.bonesOf(H).forEach(([a, b]) => pts.push([(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]));
  g.save();
  pts.forEach((q, i) => {
    const a = i * 2.39996, r = 20 + (i % 7) * 11, src = [250 + Math.cos(a) * r, 122 + Math.sin(a) * r * .8];
    const u = e.io3(seg(k, i * .006, .7 + i * .006)), x = lerp(src[0], q[0], u), y = lerp(src[1], q[1], u) - Math.sin(Math.PI * u) * 22;
    g.fillStyle = `rgba(255,255,255,${.9})`; g.shadowColor = '#c97af7'; g.shadowBlur = 10; g.beginPath(); g.arc(x, y, 2.6, 0, 7); g.fill();
  });
  g.restore();
  return true;
}
const PTR = () => [[13.0, [330, 200]], [13.25, [250, 150]], [13.9, PHOTO1], [14.55, [PHOTO1[0] - 60, PHOTO1[1] - 10]], [15.05, ALBUM], [15.9, [ALBUM[0] + 70, ALBUM[1] + 50]]];
function hands1(t) {
  tag.querySelector('span').textContent = 'Camera · manoS · 21 joints';
  const fadeIris = 1 - seg(t, 13.0, 13.3);
  if (fadeIris > 0) irisPanel(t, [[0, [252, 150]]], { iris: { fade: fadeIris } });
  camBg(seg(t, 13.1, 13.5));
  const pp = hops(t, PTR(), .32);
  const pin = clamp(e.io2(seg(t, 14.0, 14.2)) - e.io2(seg(t, 15.15, 15.35)));
  const ho = handIn(t, { pose: 'open', to: 'pinch', t: pin, x: 262 + (pp[0] - 252) * .3, y: 232 + (pp[1] - 150) * .16, act: pin > .75 ? ['thumb', 'index'] : [] });
  if (!morphIrisToHand(t, 13.0, ho) || t > 13.45) { g.globalAlpha = seg(t, 13.45, 13.62); Hand.draw(g, ho); g.globalAlpha = 1; }
  ptr.style.display = 'block';
  const dragging = t >= 14.2 && t < 15.25;
  ptr.set(pp[0], pp[1], { hud: seg(t, 13.6, 13.8), ring: pin, color: dragging ? '#30d158' : '#0a84ff', sym: dragging ? 'drag' : null });
  // the dragged photo follows the pointer and drops into the album
  const ph = PHOTO_EL, k = seg(t, 14.2, 14.35);
  if (t >= 14.2 && t < 15.4) {
    const s = screenEl.getBoundingClientRect(), r0 = PHOTO1;
    ph.style.position = 'relative'; ph.style.zIndex = 5;
    const dx = (pp[0] - r0[0]) + 14, dy = (pp[1] - r0[1]) + 14, drop = e.io2(seg(t, 15.25, 15.4));
    ph.style.transform = `translate(${dx}px, ${dy}px) scale(${lerp(1, .55, e.o3(k)) * (1 - .9 * drop)})`; ph.style.opacity = 1 - .2 * k - .8 * drop; ph.style.boxShadow = `0 ${12 * k}px ${30 * k}px rgba(0,0,0,.5)`;
  } else if (t >= 15.4) { ph.style.transform = 'scale(0)'; ph.style.opacity = 0; }
  else { ph.style.transform = ''; ph.style.opacity = 1; ph.style.boxShadow = ''; }
  const al = $('.target', W.photos), over = t >= 14.95 && t < 15.6;
  al.style.background = over ? 'rgba(10,132,255,.35)' : (t >= 15.6 ? 'rgba(255,255,255,.08)' : 'transparent');
  $('.cnt', al).textContent = t >= 15.35 ? '4' : '3';
}
ev(13.0, 'morph'); ev(13.0, 'swipe'); ev(13.2, 'hud', { i: 1 }); ev(14.08, 'pinch'); ev(14.25, 'drag'); ev(15.3, 'drop'); fast(13.0, 13.7); fast(13.85, 14.4); fast(14.5, 15.15);

function hands2(t) {
  tag.querySelector('span').textContent = 'Camera · manoS · 21 joints';
  camBg(1);
  const v = e.io2(seg(t, 16.85, 17.15));
  const fl = [17.7, 18.9].map(t0 => Math.sin(Math.PI * e.o2(seg(t, t0, t0 + .32))) * (t < t0 + .32 ? 1 : 0));
  const up = fl[0] + fl[1];
  Hand.draw(g, handIn(t, { pose: 'open', to: 'vsign', t: v, yaw: -36, y: 232 - up * 52, x: 262, act: v > .8 ? ['index', 'middle'] : [], link: false }));
  // slides advance with a vertical push
  const sl = $$('.sl', W.slides);
  const n1 = e.io3(seg(t, 17.78, 18.18)), n2 = e.io3(seg(t, 18.98, 19.38));
  sl[0].style.transform = `translateY(${-100 * n1}%)`; sl[1].style.transform = `translateY(${100 * (1 - n1) - 100 * n2}%)`; sl[2].style.transform = `translateY(${100 * (1 - n2)}%)`;
  ptr.style.display = 'block';
  const sym = (t >= 17.72 && t < 18.22) || (t >= 18.92 && t < 19.42) ? 'chevUp2' : null;
  ptr.set(392, 196, { hud: 1, ring: sym ? 1 : 0, color: '#0a84ff', sym });
}
ev(16.8, 'swipe'); ev(17.7, 'flick'); ev(17.8, 'slide'); ev(18.9, 'flick'); ev(19.0, 'slide'); fast(16.8, 17.3); fast(17.65, 18.25); fast(18.85, 19.45);

// ---- look + pinch
function peak(t) {
  const sp = e.io3(seg(t, 20.5, 20.95));
  tag.querySelector('span').textContent = 'Camera · ojoS';
  // left: the eye, right: the hand
  const keys = GZ.peak();
  irisPanel(t, keys, { clip: panelClip(20, 116, lerp(20, 274, sp), 608), iris: { cx: lerp(270, 143, sp), r: lerp(88, 70, sp), openW: lerp(205, 120, sp), fade: sp, panel: [20, 116, lerp(500, 246, sp), 236] } });
  divider.style.display = 'block'; divider.style.opacity = sp;
  tag2.style.display = 'flex'; tag2.style.opacity = sp;
  g.save(); g.beginPath(); g.rect(lerp(0, 254, sp), 0, 500, 236); g.clip(); camBg(1, lerp(0, 254, sp), 500);
  const pin = clamp(e.io2(seg(t, 21.95, 22.12)) - e.io2(seg(t, 22.35, 22.55)));
  Hand.draw(g, handIn(t, { pose: 'open', to: 'pinch', t: pin, x: lerp(262, 392, sp), y: lerp(230, 226, sp), s: lerp(106, 86, sp), act: pin > .75 ? ['thumb', 'index'] : [] }));
  g.restore();
  const p = gazeAt(t, keys);
  gaze.style.display = 'block'; gaze.set(p[0], p[1], { scale: 1 - .16 * pin, alpha: 1 - seg(t, 22.3, 22.5) });
  const d = W.dialog.d, saved = e.io3(seg(t, 22.18, 22.42));
  $('.save', d).classList.toggle('dn', t >= 22.05 && t < 22.2);
  d.style.transform = `scale(${1 - .06 * saved})`; d.style.opacity = 1 - saved;
  const bt = $('.bar span:last-child', W.dialog.back); if (bt) bt.textContent = t >= 22.3 ? 'Launch plan' : 'Launch plan — Edited';
  // "Saved" toast
  rg.setTransform(2, 0, 0, 2, 0, 0); rg.clearRect(0, 0, 504, 600);
  const ts = e.o3(seg(t, 22.35, 22.6)) * (1 - seg(t, 23.3, 23.6));
  if (ts > 0) { rg.globalAlpha = ts; rg.fillStyle = 'rgba(40,40,44,.95)'; rg.beginPath(); rg.roundRect(192, 190 - 8 * ts, 120, 40, 20); rg.fill();
    rg.fillStyle = '#30d158'; rg.beginPath(); rg.arc(214, 210 - 8 * ts, 8, 0, 7); rg.fill(); rg.fillStyle = '#fff'; rg.font = '600 15px "Instrument Sans"'; rg.textAlign = 'left'; rg.textBaseline = 'middle'; rg.fillText('Saved', 230, 211 - 8 * ts); rg.globalAlpha = 1; }
}
ev(20.5, 'swipe'); ev(21.25, 'lockon', { x: .3 }); ev(22.0, 'pinch'); ev(22.06, 'click', { hit: .3 }); ev(22.36, 'saved');
ev(23.5, 'silence', { dur: .3 }); ev(23.8, 'impact', { hit: 1, shake: .5 }); fast(20.5, 20.95); fast(21.2, 21.5);

// ---- voice
const SPOKEN = 'um so I think we should uh move the launch to thursday'.split(' ');
const CLEAN = 'So I think we should move the launch to Thursday.';
function voice(t) {
  const fromHand = seg(t, 25.5, 25.9);
  tag.querySelector('span').textContent = 'Microphone · bocaS';
  camBg(1 - fromHand);
  if (fromHand < 1) { // hand joints flatten into a line, then the line becomes the waveform
    const ho = handIn(t, { pose: 'open' });
    const H = Hand.project(Hand.xform(Hand.pose('open'), ho), ho), pts = Hand.joints(H);
    pts.sort((a, b) => a[0] - b[0]).forEach((q, i) => {
      const u = e.io3(fromHand), x = lerp(q[0], 80 + i * 17, u), y = lerp(q[1], 150, u);
      g.fillStyle = u > .6 ? '#ffa31a' : '#fff'; g.beginPath(); g.arc(x, y, 3 - u, 0, 7); g.fill();
    });
  }
  const talking = t >= 26.15 && t < 28.45 ? 1 : 0;
  const wa = seg(t, 25.8, 26.1) * (t < 31.0 ? 1 : 1 - seg(t, 32.6, 33.0));
  if (wa > 0) {
    for (let i = 0; i < 46; i++) {
      const x = 52 + i * 8.6, env = Math.sin(Math.PI * i / 45) ** .7;
      const syl = .25 + .75 * Math.abs(Math.sin(t * 9.3 + i * .21) * Math.sin(t * 3.7 + i * .05));
      const h = (5 + (talking ? 66 : 8) * env * syl) * wa;
      const grad = g.createLinearGradient(0, 150 - h / 2, 0, 150 + h / 2); grad.addColorStop(0, '#ffcf7a'); grad.addColorStop(1, '#ff7a2e');
      g.fillStyle = grad; g.beginPath(); g.roundRect(x - 2.2, 150 - h / 2, 4.4, h, 2.2); g.fill();
    }
  }
  bigKeys.style.display = t < 31.0 ? 'block' : 'none';
  bigKeys.style.opacity = seg(t, 25.75, 26.0) * (1 - seg(t, 30.6, 31.0));
  const held = t >= 25.95 && t < 28.45;
  $$('.key', bigKeys).forEach((k, i) => { k.classList.toggle('dn', held && t >= 25.95 + i * .05); k.style.setProperty('--kc', 'rgba(255,163,26,.55)'); });
  $$('.key', hD.box).forEach((k, i) => k.classList.toggle('dn', held && t >= 25.95 + i * .05));
  // the bocaS pill: live words while held, cleanup on release
  if (t >= 25.5 && t < 31.0) {
    const pa = e.o3(seg(t, 25.98, 26.2)) * (1 - seg(t, 29.05, 29.3));
    pill.style.display = pa > 0 ? 'flex' : 'none';
    const nW = Math.floor(clamp((t - 26.2) / .2, 0, SPOKEN.length));
    let html = nW ? SPOKEN.slice(0, nW).join(' ') : 'Listening…';
    const clean = seg(t, 28.55, 28.9);
    if (t >= 28.45 && t < 28.55) html = 'Polishing…';
    if (t >= 28.55) html = SPOKEN.map(w => (w === 'um' || w === 'uh') ? `<span style="display:inline-block;color:#ff453a;text-decoration:line-through;max-width:${(1 - clean) * 3}em;overflow:hidden;vertical-align:bottom;opacity:${1 - clean}">${w}</span>`
      : w === 'so' ? (clean > .5 ? 'So' : 'so') : w === 'thursday' ? (clean > .5 ? 'Thursday.' : 'thursday') : w).join(' ');
    pill.set({ x: 42, y: 250, w: 420, alpha: pa, t, level: talking ? .35 + .65 * Math.abs(Math.sin(t * 9.3)) : .05, html, live: nW > 0 && t < 28.45 || t >= 28.55 });
    const ins = $('.ins', W.mail2), ia = seg(t, 29.0, 29.05);
    ins.textContent = ia > 0 ? CLEAN : ''; ins.style.background = `rgba(10,132,255,${.35 * (1 - seg(t, 29.1, 29.7))})`;
    $('.caret', W.mail2).style.opacity = Math.floor(t * 2.2) % 2 ? 1 : .15;
  }
  if (t >= 31.0) { // a voice note's summary
    const items = $$('.it', W.note), card = $('.card', W.note);
    card.style.opacity = e.o3(seg(t, 31.35, 31.6)); card.style.transform = `translateY(${(1 - e.o3(seg(t, 31.35, 31.6))) * 14}px)`;
    $('.sum', W.note).style.opacity = seg(t, 31.5, 31.8);
    items.forEach((it, i) => { const k = e.o3(seg(t, 31.85 + i * .22, 32.05 + i * .22)); it.style.opacity = k; it.style.transform = `translateX(${(1 - k) * 12}px)`; });
  }
}
ev(25.5, 'swipe'); ev(25.5, 'morph'); ev(25.7, 'hud', { i: 2 }); [25.95, 26.0, 26.05, 26.1].forEach((tk, i) => ev(tk, 'key', { i })); ev(26.0, 'micOn');
SPOKEN.forEach((w, i) => ev(26.2 + i * .2, 'syllable', { n: w.length }));
ev(28.45, 'keyUp'); ev(28.6, 'strike'); ev(28.72, 'strike'); ev(29.0, 'paste'); ev(31.0, 'swipe'); ev(31.35, 'card'); [31.85, 32.07, 32.29].forEach(tk => ev(tk, 'pop', { p: 1000 }));
fast(25.5, 25.95); fast(31.0, 31.5); fast(33.0, 33.5);

// ======================================================================= trust: nothing leaves the Mac
function rr(c, x, y, w, h, r) { c.beginPath(); c.roundRect(x, y, w, h, r); }
function c0() {}
function drawTrust(t) {
  c0(); const c = tg, B = { x: 56, y: 210, w: 428, h: 296 }, CH = { x: 270, y: 364, s: 112 };
  const ink = e.o3(seg(t, 33.2, 33.65));
  c.globalAlpha = ink;
  // the Mac: a screen outline with its notch camera and mic
  c.strokeStyle = 'rgba(255,255,255,.3)'; c.lineWidth = 1.6; rr(c, B.x, B.y, B.w, B.h, 30); c.stroke();
  const gl = c.createRadialGradient(CH.x, CH.y, 10, CH.x, CH.y, 230); gl.addColorStop(0, 'rgba(245,136,65,.16)'); gl.addColorStop(1, 'rgba(245,136,65,0)');
  c.fillStyle = gl; rr(c, B.x, B.y, B.w, B.h, 30); c.fill();
  c.fillStyle = '#0b0b0c'; rr(c, 226, B.y - 1, 88, 22, 10); c.fill(); c.strokeStyle = 'rgba(255,255,255,.3)'; c.stroke();
  const lens = c.createRadialGradient(268, B.y + 9, 1, 270, B.y + 10, 6); lens.addColorStop(0, '#5a6c92'); lens.addColorStop(1, '#0b0f18');
  c.fillStyle = lens; c.beginPath(); c.arc(270, B.y + 10, 5.5, 0, 7); c.fill();
  c.fillStyle = '#32d74b'; c.beginPath(); c.arc(286, B.y + 10, 2, 0, 7); c.fill();
  c.font = '400 10px "Fragment Mono"'; c.textAlign = 'center'; c.fillStyle = 'rgba(255,255,255,.5)';
  c.fillText('CAMERA', 270, B.y + 40); c.fillText('MIC', 104, B.y + 40);
  c.strokeStyle = 'rgba(255,255,255,.55)'; c.lineWidth = 1.6; rr(c, 99, B.y + 12, 10, 15, 5); c.stroke(); c.beginPath(); c.arc(104, B.y + 22, 8, 0, Math.PI); c.stroke();
  // the chip where everything is processed
  const pulse = [...Array(12)].reduce((m, _, i) => Math.max(m, Math.max(0, 1 - Math.abs(t - (34.05 + i * .32)) / .18)), 0) * (t < 37.9 ? 1 : 0);
  c.save(); c.shadowColor = 'rgba(245,136,65,.9)'; c.shadowBlur = 18 + 30 * pulse;
  const cg = c.createLinearGradient(0, CH.y - 56, 0, CH.y + 56); cg.addColorStop(0, '#2a2a2f'); cg.addColorStop(1, '#141417');
  c.fillStyle = cg; rr(c, CH.x - 56, CH.y - 56, 112, 112, 18); c.fill(); c.restore();
  c.strokeStyle = `rgba(245,136,65,${.5 + .5 * pulse})`; c.lineWidth = 1.5; rr(c, CH.x - 56, CH.y - 56, 112, 112, 18); c.stroke();
  c.fillStyle = 'rgba(255,255,255,.18)'; for (let i = 0; i < 7; i++) { const o = -42 + i * 14; [[o, -64], [o, 60], [-64, o], [60, o]].forEach(([x, y]) => c.fillRect(CH.x + x, CH.y + y, 4, 4)); }
  c.fillStyle = '#fff'; c.font = '600 15px "Instrument Sans"'; c.fillText('On your Mac', CH.x, CH.y + 6);
  c.fillStyle = 'rgba(255,255,255,.5)'; c.font = '400 9px "Fragment Mono"'; c.fillText('VISION · SPEECH', CH.x, CH.y + 24);
  // camera frames and audio fall into the chip and are absorbed
  for (let i = 0; i < 11; i++) {
    const t0 = 33.55 + i * .32, k = seg(t, t0, t0 + .62); if (k <= 0 || k >= 1 || t > 37.95) continue;
    const vid = i % 3 !== 2, sx = vid ? 270 : 104, sy = B.y + 26, u = e.i2(k);
    const x = lerp(sx, CH.x, u), y = lerp(sy, CH.y, u), sc = lerp(1, .15, u), al = 1 - seg(k, .7, 1);
    c.save(); c.translate(x, y); c.scale(sc, sc); c.globalAlpha = al * ink;
    if (vid) { c.strokeStyle = 'rgba(255,255,255,.8)'; c.lineWidth = 1.5; rr(c, -40, -26, 80, 52, 7); c.stroke();
      c.fillStyle = '#3d9cff'; for (let j = 0; j < 12; j++) { const a = j / 12 * 6.283; c.beginPath(); c.arc(Math.cos(a) * 15, Math.sin(a) * 17 - 2, 1.8, 0, 7); c.fill(); }
      c.fillStyle = '#c97af7'; c.beginPath(); c.arc(-6, -4, 2.2, 0, 7); c.arc(6, -4, 2.2, 0, 7); c.fill(); }
    else { c.fillStyle = '#ffa31a'; for (let j = 0; j < 9; j++) { const h = 6 + 22 * Math.abs(Math.sin(j * 1.7 + i)); rr(c, -32 + j * 8, -h / 2, 4, h, 2); c.fill(); } }
    c.restore();
  }
  c.globalAlpha = ink;
  // the way out is closed
  const cl = e.o3(seg(t, 34.3, 34.7));
  c.globalAlpha = cl * ink;
  c.strokeStyle = 'rgba(255,255,255,.5)'; c.lineWidth = 1.6; c.beginPath(); c.arc(256, 152, 13, Math.PI * .9, Math.PI * 1.9); c.arc(276, 146, 16, Math.PI * 1.1, Math.PI * 2.05); c.arc(292, 156, 10, Math.PI * 1.5, Math.PI * .5); c.lineTo(250, 166); c.arc(250, 156, 10, Math.PI * .5, Math.PI * 1.3); c.stroke();
  c.fillStyle = 'rgba(255,255,255,.45)'; c.font = '400 9px "Fragment Mono"'; c.fillText('CLOUD', 272, 186);
  c.setLineDash([4, 5]); c.strokeStyle = 'rgba(255,255,255,.35)'; c.beginPath(); c.moveTo(270, B.y - 2); c.lineTo(270, 192); c.stroke(); c.setLineDash([]);
  c.strokeStyle = '#ff453a'; c.lineWidth = 3; c.lineCap = 'round'; c.beginPath(); c.moveTo(304, 186); c.lineTo(320, 202); c.moveTo(320, 186); c.lineTo(304, 202); c.stroke();
  // the lock
  const lk = e.back(seg(t, 34.6, 34.95)); c.globalAlpha = ink;
  c.save(); c.translate(B.x + B.w - 8, B.y + 8); c.scale(lk, lk);
  c.fillStyle = t > 34.75 ? '#f58841' : '#1c1c1f'; c.beginPath(); c.arc(0, 0, 20, 0, 7); c.fill(); c.strokeStyle = 'rgba(255,255,255,.3)'; c.lineWidth = 1.5; c.stroke();
  c.fillStyle = t > 34.75 ? '#1b0d04' : '#fff'; rr(c, -8, -2, 16, 12, 3); c.fill(); c.strokeStyle = c.fillStyle; c.lineWidth = 2.4; c.beginPath(); c.arc(0, -3, 5, Math.PI, 0); c.stroke();
  c.restore(); c.globalAlpha = 1;
}

F.beats.push({ t0: T.trust[0], t1: T.trust[1] + .55, draw(t) {
  show(full, true); trust.style.display = 'block'; dev.style.display = t >= 38.0 ? 'block' : 'none'; cta.style.display = 'none';
  const inK = e.o4(seg(t, 33.15, 33.6)), out = e.io3(seg(t, 37.9, 38.4));
  trust.style.opacity = inK * (1 - out);
  trust.style.transform = `scale(${(.92 + .08 * inK) * (1 + .3 * out)})`;
  tg.setTransform(2, 0, 0, 2, 0, 0); tg.clearRect(0, 0, 540, 960);
  drawTrust(t);
  // morph into the MacBook: the boundary grows into the device screen
}});
ev(33.0, 'whoosh'); ev(33.45, 'frames'); ev(34.45, 'deny'); ev(34.75, 'lock'); ev(35.95, 'tick3'); fast(33.0, 33.6);

// ======================================================================= the device: one menu bar app
F.beats.push({ t0: T.device[0], t1: T.device[1] + .5, draw(t) {
  show(full, true); dev.style.display = 'block'; cta.style.display = 'none'; if (t >= 38.45) trust.style.display = 'none';
  const l = t - 38.0, inK = e.o4(seg(l, 0, .7)), push = e.io3(seg(l, 1.55, 2.6)), out = e.io3(seg(t, 40.85, 41.25));
  const mbx = $('#mb');
  // pull back from the screen, orbit a little, then push in on the panel
  const s = lerp(1.35, 1, inK) * lerp(1, 2.35, push);
  mbx.style.transformOrigin = '78% 6%';
  mbx.style.transform = `translateY(${lerp(30, -10, inK) + 70 * push}px) rotateX(${lerp(32, 22, inK) - 18 * push}deg) rotateY(${lerp(-24, -10, inK) + 10 * push}deg) scale(${s})`;
  dev.style.opacity = inK * (1 - out);
  dev.style.filter = out > .01 ? `blur(${out * 10}px)` : '';
  const op = e.o3(seg(l, .6, .8));
  $('#dPanelWrap').style.opacity = op; $('#dPanelWrap').style.transform = `translateY(${(1 - op) * -6}px) scale(${.94 + .06 * op})`;
  $('#dIcon').style.background = op > .3 ? 'rgba(255,255,255,.28)' : 'transparent';
  $$('.tile', panel).forEach((tl, i) => {
    const on = seg(l, .9 + i * .25, 1.05 + i * .25), cb = $('.cb', tl);
    cb.style.background = on > .5 ? `linear-gradient(${tl.dataset.c}, ${tl.dataset.c}cc)` : 'rgba(255,255,255,.1)';
    cb.style.transform = `scale(${1 + .16 * Math.sin(Math.PI * on)})`;
    $('.st', tl).textContent = on > .5 ? tl.dataset.on : 'Off';
  });
}});
ev(38.0, 'whoosh'); ev(38.6, 'click', { hit: .2 }); [38.9, 39.15, 39.4].forEach((tk, i) => ev(tk, 'toggle', { i })); ev(39.4, 'riser', { len: 1.6 }); fast(38.0, 38.7); fast(39.55, 40.6, 2); fast(40.85, 41.3);

// ======================================================================= CTA
F.beats.push({ t0: T.cta[0], t1: F.DUR + 1, draw(t) {
  show(full, true); trust.style.display = 'none'; dev.style.display = t < 41.3 ? 'block' : 'none'; cta.style.display = 'block';
  const l = t - 41.0;
  const rise = e.o5(seg(l, 0, .9)), settle = springU(l - .1, 1.1, .7);
  Logo.draw({ x: 270, y: lerp(250, 282, rise), size: lerp(60, 200, rise), rx: lerp(-30, 0, settle) + Math.sin(l * .9) * 3, ry: Math.sin(l * .6) * 9 * seg(l, .8, 2), rz: 0,
    tileAlpha: clamp(rise * 2), discs: [{}, {}, {}].map(() => ({ milk: 1, alpha: clamp(rise * 2) })), keyX: lerp(-6, 5, e.io2(seg(l, .4, 2.2))), exposure: 1 });
  $$('#wm .c').forEach((c, i) => { const k = e.expo(seg(l, .55 + i * .045, 1.25 + i * .045)); c.style.transform = `translateY(${(1 - k) * 112}%)`; });
  const tk = e.o3(seg(l, .95, 1.35)); $('#tagl').style.opacity = tk; $('#tagl').style.transform = `translateY(${(1 - tk) * 14}px)`;
  [['#cPill', 2.6], ['#cUrl', 2.85], ['#cBio', 3.1]].forEach(([s, d]) => { const k = e.o4(seg(l, d, d + .45)), el2 = $(s);
    el2.style.opacity = k; el2.style.filter = k < 1 ? `blur(${(1 - k) * 6}px)` : '';
    el2.style.transform = (s === '#cPill' ? 'translateX(-50%) ' : '') + `translateY(${(1 - k) * 18}px) scale(${s === '#cPill' ? 1 + .05 * Math.sin(Math.PI * seg(l, 4.0, 4.35)) : 1})`; });
}});
ev(41.0, 'emerge'); ev(41.5, 'impact', { hit: .7, flash: '#f58841' }); ev(41.6, 'motif', { final: true }); ev(43.6, 'pop', { p: 900 }); ev(43.85, 'chime'); ev(44.1, 'pop', { p: 1100 }); ev(45.0, 'pop', { p: 800 });
fast(41.0, 41.9);

// layers off by default each frame
F.beats.unshift({ t0: -1, t1: 999, draw(t) { show(split, false); show(full, false); irisCv.style.display = 'block'; } });
F.always.push(hud);
})();
