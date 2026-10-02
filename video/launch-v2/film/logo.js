// The sentidoS icon as a lit object: an extruded squircle tile with the brand gradient under a clearcoat,
// and three discs that arrive in their module colours (eye, hand, wave) and turn into the milky discs of the logo.
import * as THREE from 'three';
import { RoomEnvironment } from '/three/examples/jsm/environments/RoomEnvironment.js';

const canvas = document.getElementById('gl3');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1); renderer.setSize(1080, 1920, false);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NeutralToneMapping; renderer.toneMappingExposure = 1;
renderer.setClearColor(0x000000, 0);
const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), .04).texture;
scene.environmentIntensity = .7;
const camera = new THREE.PerspectiveCamera(24, 1080 / 1920, .1, 100); camera.position.set(0, 0, 10);
const key = new THREE.DirectionalLight(0xffffff, 2.2); key.position.set(-3, 5, 6); scene.add(key);
const rim = new THREE.DirectionalLight(0xffc6a0, 1.6); rim.position.set(4, -2, -3); scene.add(rim);
const UNIT = 960 / (2 * 10 * Math.tan(12 * Math.PI / 180)); // CSS px per world unit at z = 0

function canvasTex(w, h, paint) { const c = document.createElement('canvas'); c.width = w; c.height = h; paint(c.getContext('2d'), w, h); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
const grad = canvasTex(512, 512, (g, w, h) => { const l = g.createLinearGradient(0, 0, 0, h); l.addColorStop(0, '#f8954a'); l.addColorStop(.5, '#c3554d'); l.addColorStop(1, '#8a1f57'); g.fillStyle = l; g.fillRect(0, 0, w, h); });
grad.repeat.set(.5, .5); grad.offset.set(.5, .5);

// tile: 2 x 2 units, corner radius 27/120 of the side (as in the app icon)
const s = new THREE.Shape(), R = .45, a = 1;
s.moveTo(-a + R, -a); s.lineTo(a - R, -a); s.quadraticCurveTo(a, -a, a, -a + R); s.lineTo(a, a - R); s.quadraticCurveTo(a, a, a - R, a);
s.lineTo(-a + R, a); s.quadraticCurveTo(-a, a, -a, a - R); s.lineTo(-a, -a + R); s.quadraticCurveTo(-a, -a, -a + R, -a);
const tileGeo = new THREE.ExtrudeGeometry(s, { depth: .2, bevelEnabled: true, bevelThickness: .06, bevelSize: .06, bevelSegments: 8, curveSegments: 32 });
tileGeo.translate(0, 0, -.2);
const tileMat = new THREE.MeshPhysicalMaterial({ map: grad, roughness: .38, metalness: 0, clearcoat: 1, clearcoatRoughness: .1, transparent: true });
const sideMat = new THREE.MeshPhysicalMaterial({ color: 0x8e3a36, roughness: .32, clearcoat: 1, clearcoatRoughness: .12, transparent: true });
const tile = new THREE.Mesh(tileGeo, [tileMat, sideMat]);

const GL = { ojos: 'M1.9 12c2.4-4.2 6-6.5 10.1-6.5s7.7 2.3 10.1 6.5c-2.4 4.2-6 6.5-10.1 6.5S4.3 16.2 1.9 12Z',
  manos: 'M8.3 13.2V5.6a1.3 1.3 0 0 1 2.6 0V11V3.9a1.3 1.3 0 0 1 2.6 0V11V4.9a1.3 1.3 0 0 1 2.6 0v6.7V7.4a1.3 1.3 0 0 1 2.6 0v7.2c0 4.1-2.7 7.2-6.3 7.2-2.5 0-4.1-1.1-5.4-3.1L4 14.4a1.35 1.35 0 0 1 2.2-1.6l2.1 2.5Z',
  bocas: 'M3.2 10.6v2.8M6.6 8.2v7.6M10 4.6v14.8M13.4 7.4v9.2M16.8 9.4v5.2M20.2 11v2' };
const COL = { ojos: '#2f8dff', manos: '#a960f0', bocas: '#ff9a1f' };
const discGeo = new THREE.CylinderGeometry(.42, .42, .08, 96, 1); discGeo.rotateX(Math.PI / 2);
const glyphGeo = new THREE.PlaneGeometry(.5, .5);
const SPOT = [[0, .24], [-.22, -.152], [.22, -.152]];
const discs = ['ojos', 'manos', 'bocas'].map((m, i) => {
  const g = new THREE.Group();
  const col = new THREE.Mesh(discGeo, new THREE.MeshPhysicalMaterial({ color: COL[m], roughness: .28, clearcoat: 1, clearcoatRoughness: .08, emissive: COL[m], emissiveIntensity: .18, transparent: true }));
  const milk = new THREE.Mesh(discGeo, new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: .55, clearcoat: .8, clearcoatRoughness: .2, transparent: true, opacity: .6, depthWrite: false }));
  const tex = canvasTex(256, 256, (c) => {
    c.scale(256 / 24, 256 / 24); c.strokeStyle = '#fff'; c.fillStyle = '#fff'; c.lineCap = 'round'; c.lineJoin = 'round';
    const p = new Path2D(GL[m]);
    if (m === 'ojos') { c.lineWidth = 1.9; c.stroke(p); c.beginPath(); c.arc(12, 12, 3.9, 0, 7); c.fill(); }
    else if (m === 'manos') { c.lineWidth = 1.7; c.stroke(p); }
    else { c.lineWidth = 2; c.stroke(p); }
  });
  const glyph = new THREE.Mesh(glyphGeo, new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false }));
  glyph.position.z = .05;
  g.add(col, milk, glyph); g.userData = { col, milk, glyph, spot: SPOT[i] };
  return g;
});
const icon = new THREE.Group(); icon.add(tile, ...discs); scene.add(icon);

window.Logo = {
  SPOT,
  // o: { x, y, size (CSS px), rx, ry, rz (deg), tileAlpha, tileY (units), discs: [{x, y, z, rz, s, milk, alpha}] , exposure }
  draw(o) {
    const sc = o.size / (2 * UNIT);
    icon.position.set((o.x - 270) / UNIT, -(o.y - 480) / UNIT, 0);
    icon.scale.setScalar(sc);
    icon.rotation.set((o.rx || 0) * Math.PI / 180, (o.ry || 0) * Math.PI / 180, (o.rz || 0) * Math.PI / 180);
    tile.position.y = o.tileY || 0; tile.rotation.x = (o.tileRx || 0) * Math.PI / 180;
    tileMat.opacity = sideMat.opacity = o.tileAlpha ?? 1; tile.visible = tileMat.opacity > .001;
    discs.forEach((d, i) => {
      const p = (o.discs && o.discs[i]) || {}, u = d.userData, m = p.milk ?? 1, al = p.alpha ?? 1;
      d.position.set(p.x ?? u.spot[0], p.y ?? u.spot[1], p.z ?? .03);
      d.rotation.set(p.rx || 0, p.ry || 0, p.rz || 0); d.scale.setScalar(p.s ?? 1);
      u.col.material.opacity = (1 - m) * al; u.milk.material.opacity = .62 * m * al; u.glyph.material.opacity = (1 - m) * al;
      u.col.visible = u.col.material.opacity > .002; u.glyph.visible = u.col.visible; u.milk.visible = u.milk.material.opacity > .002;
    });
    renderer.toneMappingExposure = o.exposure ?? 1;
    key.position.set(o.keyX ?? -3, 5, 6);
    renderer.render(scene, camera);
  },
  clear() { renderer.clear(); },
};
F._ready();
