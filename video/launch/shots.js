// Edit decision list, in beats (120 BPM, 0.5 s per beat, 15 frames per beat at 30 fps).
// Site shots: keys are [beat, value]; pinned scenes use scene progress p (0..1), others use px offset from section top.
const FPS = 30, BEAT = 15;
const steps = (n, per, a = .03, b = .97) => {
  // hold on each step's middle, move between steps
  const k = [[0, a]];
  for (let i = 0; i < n; i++) { const c = (i + .5) / n; k.push([i * per + per * .45, Math.max(a, c - .5 / n * .35)]); k.push([i * per + per * .95, Math.min(b, c + .5 / n * .3)]); }
  k.push([n * per, b]);
  return k;
};
// bounds: the scene progress where each caption step starts (measured with probe4.js); w: beats per step
const stepKeys = (bounds, w) => {
  const k = []; let t = 0;
  bounds.forEach((a, i) => {
    const b = i + 1 < bounds.length ? bounds[i + 1] : 1;
    k.push([t + (i ? .22 : 0), a + (i ? .012 : .005)]);
    k.push([t + w[i], b - .008]);
    t += w[i];
  });
  return k;
};
const ticksOf = w => w.slice(0, -1).map((_, i) => w.slice(0, i + 1).reduce((a, b) => a + b, 0));
const SHOTS = [
  { name: 'hook', kind: 'card', card: 'hook', beats: 4 },
  { name: 'hero', kind: 'site', sec: '#top', pin: true, beats: 16, fresh: true,
    keys: [[0, 0], [4.5, 0], [6.5, .31], [8, .47], [10, .745], [11.5, .80], [13, .88], [15, 1], [16, 1]] },
  { name: 'look', kind: 'card', card: 'look', beats: 1 },
  { name: 'ojosOp', kind: 'site', sec: '#ojos', beats: 3, keys: [[0, -400], [3, 270]] },
  { name: 'ojosDemo', kind: 'site', sec: '#ojosDemo', pin: true, beats: 8, keys: stepKeys([0, .36, .54, .79], [2.4, 1.6, 2.2, 1.8]), ticks: ticksOf([2.4, 1.6, 2.2, 1.8]) },
  { name: 'pinch', kind: 'card', card: 'pinch', beats: 1 },
  { name: 'manosOp', kind: 'site', sec: '#manos', beats: 3, keys: [[0, -400], [3, 190]] },
  { name: 'manosDemo', kind: 'site', sec: '#manosDemo', pin: true, beats: 9, keys: stepKeys([0, .23, .42, .60, .79], [1.8, 1.8, 1.8, 1.8, 1.8]), ticks: ticksOf([1.8, 1.8, 1.8, 1.8, 1.8]) },
  { name: 'lookpinch', kind: 'site', sec: '#look', pin: true, beats: 6, keys: [[0, .02], [1, .15], [5.2, .86], [6, .9]] },
  { name: 'speak', kind: 'card', card: 'speak', beats: 1 },
  { name: 'bocasOp', kind: 'site', sec: '#bocas', beats: 3, keys: [[0, -400], [3, 190]] },
  { name: 'bocasDemo', kind: 'site', sec: '#bocasDemo', pin: true, beats: 8, keys: stepKeys([0, .47, .65, .82], [2.6, 1.6, 1.8, 2.0]), ticks: ticksOf([2.6, 1.6, 1.8, 2.0]) },
  { name: 'privacy', kind: 'site', sec: '#privacy', pin: true, beats: 6, keys: [[0, 0], [5, .97], [6, 1]] },
  { name: 'free', kind: 'site', sec: '#download', beats: 4, keys: [[0, 0], [4, 80]] },
  { name: 'end', kind: 'end', beats: 12 },
];
let b = 0;
for (const s of SHOTS) { s.start = b; b += s.beats; s.frames = s.beats * BEAT; }
module.exports = { SHOTS, FPS, BEAT, TOTAL_BEATS: b };
if (require.main === module) { for (const s of SHOTS) console.log(s.name.padEnd(10), 'beat', s.start, 't=' + (s.start / 2).toFixed(1) + 's', s.beats); console.log('total', b / 2, 's'); }
