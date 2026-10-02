// A 21-joint hand (wrist, 4 thumb joints, 4 per finger) with forward kinematics, two-bone IK for the
// thumb, named poses, and a renderer in the style of a Vision hand-pose overlay. Units: wrist→middle knuckle ≈ 1.
(() => {
const D = Math.PI / 180;
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const mul = (a, s) => [a[0] * s, a[1] * s, a[2] * s], dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const len = a => Math.hypot(a[0], a[1], a[2]), norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const FING = [ // knuckle, segment lengths, spread angle (deg, + toward the little finger)
  { m: [-.31, .9, 0], l: [.42, .25, .19], a: -9 },
  { m: [-.09, .97, 0], l: [.46, .28, .2], a: -1 },
  { m: [.13, .93, 0], l: [.43, .26, .19], a: 7 },
  { m: [.32, .83, 0], l: [.34, .2, .17], a: 17 },
];
const TH = { c: [-.2, .2, .04], l: [.34, .28, .23] };
// poses: per finger [flex1, flex2, flex3, spreadDelta]; thumb: {a: angle from up toward thumb side, e: out of palm, f: [flex2, flex3]} or {to: 'index'|...}
const POSES = {
  open:   { f: [[6, 8, 5, -2], [5, 7, 5, 0], [6, 8, 5, 1], [8, 9, 6, 3]], th: { a: -36, e: 30, f: [10, 8] } },
  relax:  { f: [[16, 20, 12, 0], [14, 22, 12, 0], [18, 24, 14, 0], [22, 26, 16, 0]], th: { a: -30, e: 36, f: [14, 10] } },
  pinch:  { f: [[50, 60, 34, 3], [16, 24, 14, 0], [20, 26, 16, 0], [24, 28, 18, 0]], th: { to: 0 } },
  pinchM: { f: [[10, 12, 8, -3], [52, 62, 34, 0], [24, 28, 16, 0], [26, 30, 18, 0]], th: { to: 1 } },
  vsign:  { f: [[3, 4, 2, -9], [3, 4, 2, 9], [86, 100, 60, 0], [84, 98, 58, 0]], th: { to: 'ringmid' } },
  fist:   { f: [[86, 100, 62, 2], [88, 102, 62, 0], [88, 100, 60, -1], [84, 96, 58, -3]], th: { to: 'fist' } },
};
function fingers(fl) {
  return FING.map((F, i) => {
    const [f1, f2, f3, sp] = fl[i], a = (F.a + sp) * D;
    const up = [Math.sin(a), Math.cos(a), 0], out = [0, 0, 1];
    const pts = [F.m.slice()]; let c = 0, p = F.m.slice();
    [f1, f2, f3].forEach((f, j) => { c += f * D; const d = add(mul(up, Math.cos(c)), mul(out, Math.sin(c))); p = add(p, mul(d, F.l[j])); pts.push(p); });
    return pts;
  });
}
function ik(base, target, l1, l2, pole) {
  const d = sub(target, base), dist = Math.min(l1 + l2 - 1e-4, Math.max(Math.abs(l1 - l2) + 1e-4, len(d))), dn = norm(d);
  const A = Math.acos(Math.max(-1, Math.min(1, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist))));
  const n = norm(sub(pole, mul(dn, dot(pole, dn))));
  return [add(base, add(mul(dn, Math.cos(A) * l1), mul(n, Math.sin(A) * l1))), add(base, mul(dn, dist))];
}
function thumb(spec, F) {
  const c = TH.c.slice();
  if (spec.to === undefined) {
    const a = spec.a * D, e = spec.e * D;
    const d1 = norm([Math.sin(a) * Math.cos(e), Math.cos(a) * Math.cos(e), Math.sin(e)]);
    const m = add(c, mul(d1, TH.l[0]));
    let ang = 0; const pts = [c, m]; let p = m, d = d1;
    spec.f.forEach((f, j) => { ang = f * D; const side = norm(cross(d, [0, 0, 1])); d = norm(add(mul(d, Math.cos(ang)), mul(side, -Math.sin(ang) * .4)) ); d = norm(add(d, [0, 0, Math.sin(ang) * .3])); p = add(p, mul(d, TH.l[j + 1])); pts.push(p); });
    return pts;
  }
  let target;
  if (spec.to === 0 || spec.to === 1) { const t = F[spec.to][3]; target = add(t, [-.025, -.03, .03]); }
  else if (spec.to === 'ringmid') target = add(F[2][2], [-.06, .02, .1]);
  else target = add(mul(add(F[1][2], F[2][2]), .5), [-.04, -.06, .14]);
  const m = add(c, mul(norm(sub(add(target, [-.1, -.25, .05]), c)), TH.l[0]));
  const [ip, tip] = ik(m, target, TH.l[1], TH.l[2], [-.6, .2, .7]);
  return [c, m, ip, tip];
}
function pose(a, b = a, t = 0) {
  const A = POSES[a], B = POSES[b];
  const fl = A.f.map((r, i) => r.map((v, j) => v + (B.f[i][j] - v) * t));
  const Fa = fingers(fl);
  const ta = thumb(A.th, fingers(A.f)), tb = thumb(B.th, fingers(B.f));
  const th = ta.map((p, i) => [p[0] + (tb[i][0] - p[0]) * t, p[1] + (tb[i][1] - p[1]) * t, p[2] + (tb[i][2] - p[2]) * t]);
  return { w: [0, 0, 0], th, f: Fa };
}
function xform(H, o) { // yaw/pitch/roll in degrees about the palm centre
  const cy = Math.cos((o.yaw || 0) * D), sy = Math.sin((o.yaw || 0) * D), cp = Math.cos((o.pitch || 0) * D), sp = Math.sin((o.pitch || 0) * D), cr = Math.cos((o.roll || 0) * D), sr = Math.sin((o.roll || 0) * D);
  const R = p => { let [x, y, z] = [p[0], p[1] - .5, p[2]];
    [x, y] = [x * cr - y * sr, x * sr + y * cr]; [x, z] = [x * cy + z * sy, -x * sy + z * cy]; [y, z] = [y * cp - z * sp, y * sp + z * cp]; return [x, y + .5, z]; };
  return { w: R(H.w), th: H.th.map(R), f: H.f.map(c => c.map(R)) };
}
function project(H, o) {
  const S = o.s, k = p => 3.2 / (3.2 - p[2]);
  const P = p => [o.x + p[0] * S * k(p), o.y - p[1] * S * k(p), p[2]];
  return { w: P(H.w), th: H.th.map(P), f: H.f.map(c => c.map(P)) };
}
const bonesOf = Q => {
  const b = []; const chain = (arr, from) => { let prev = from; arr.forEach(p => { b.push([prev, p]); prev = p; }); };
  chain(Q.th, Q.w); Q.f.forEach(c => chain(c, Q.w)); b.push([Q.f[0][0], Q.f[1][0]], [Q.f[1][0], Q.f[2][0]], [Q.f[2][0], Q.f[3][0]]);
  return b;
};
window.Hand = {
  pose, xform, project, bonesOf,
  joints: Q => [Q.w, ...Q.th, ...Q.f.flat()],
  tips: Q => ({ thumb: Q.th[3], index: Q.f[0][3], middle: Q.f[1][3], ring: Q.f[2][3], little: Q.f[3][3] }),
  // o: {pose, to, t, x, y, s, yaw, pitch, roll, act:[tip names], color, alpha}
  draw(g, o) {
    const H = xform(pose(o.pose, o.to || o.pose, o.t || 0), o), Q = project(H, o), al = o.alpha ?? 1, hi = o.color || '#c97af7';
    const bones = bonesOf(Q).sort((a, b) => a[0][2] + a[1][2] - b[0][2] - b[1][2]);
    g.save(); g.lineCap = 'round'; g.lineJoin = 'round';
    // flesh: soft volume so the skeleton reads as a hand
    g.globalAlpha = .07 * al; g.strokeStyle = '#ffd9c2'; g.lineWidth = o.s * .17;
    bones.forEach(([a, b]) => { g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); });
    g.globalAlpha = .05 * al; g.fillStyle = '#ffd9c2';
    g.beginPath(); [Q.w, Q.th[0], Q.f[0][0], Q.f[1][0], Q.f[2][0], Q.f[3][0]].forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.closePath(); g.fill();
    g.globalAlpha = al;
    bones.forEach(([a, b]) => { const z = (a[2] + b[2]) / 2; g.strokeStyle = `rgba(255,255,255,${.5 + Math.max(0, Math.min(.45, z * .9))})`; g.lineWidth = 2.1 + z * 1.6; g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); });
    const tips = this.tips(Q), act = (o.act || []).map(n => tips[n]);
    this.joints(Q).sort((a, b) => a[2] - b[2]).forEach(p => {
      const isTip = Object.values(tips).includes(p), on = act.includes(p), r = (isTip ? 4.6 : 3.4) * (1 + p[2] * .5);
      g.fillStyle = '#060607'; g.beginPath(); g.arc(p[0], p[1], r + 2, 0, 7); g.fill();
      g.fillStyle = on ? hi : '#fff'; g.beginPath(); g.arc(p[0], p[1], r, 0, 7); g.fill();
      if (on) { g.shadowColor = hi; g.shadowBlur = 14; g.strokeStyle = hi; g.lineWidth = 1.6; g.beginPath(); g.arc(p[0], p[1], r + 7, 0, 7); g.stroke(); g.shadowBlur = 0; }
    });
    if (o.link && act.length === 2) {
      const [a, b] = act; g.setLineDash([3, 3]); g.strokeStyle = hi; g.lineWidth = 1.3; g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); g.setLineDash([]);
    }
    g.restore();
    return Q;
  },
};
})();
