// Macro eye for the input panel: a WebGL fragment shader (iris fibres, collarette, crypts, limbal ring,
// shaded sclera, soft lids, cornea reflections including the Mac's screen). Deterministic: no time noise.
(() => {
const cv = document.getElementById('irisGL');
const gl = cv.getContext('webgl', { preserveDrawingBuffer: true, premultipliedAlpha: false, antialias: true });
const VS = 'attribute vec2 p; void main(){ gl_Position = vec4(p, 0., 1.); }';
const FS = `
precision highp float;
uniform vec4 uPanel;
uniform vec2 uRes, uEyeC, uIrisC, uLook, uOpenC, uOpenHW, uZoomP, uClipX;
uniform float uEyeR, uIrisR, uPupil, uOpen, uZoom, uScreen, uFade;
float h3(vec3 p){ p = fract(p * vec3(.1031, .1030, .0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
float n3(vec3 x){ vec3 i = floor(x), f = fract(x); f = f*f*(3.-2.*f);
  return mix(mix(mix(h3(i), h3(i+vec3(1,0,0)), f.x), mix(h3(i+vec3(0,1,0)), h3(i+vec3(1,1,0)), f.x), f.y),
             mix(mix(h3(i+vec3(0,0,1)), h3(i+vec3(1,0,1)), f.x), mix(h3(i+vec3(0,1,1)), h3(i+vec3(1,1,1)), f.x), f.y), f.z); }
float fbm(vec3 p){ float a = .5, s = 0.; for (int i = 0; i < 5; i++) { s += a * n3(p); p *= 2.03; a *= .5; } return s; }
float rbox(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q, 0.)) + min(max(q.x, q.y), 0.) - r; }
void main(){
  vec2 fc = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y);
  if (fc.x < uClipX.x || fc.x > uClipX.y || fc.x < uPanel.x - 2. || fc.y < uPanel.y - 2. || fc.x > uPanel.x + uPanel.z + 2. || fc.y > uPanel.y + uPanel.w + 2.) { gl_FragColor = vec4(0.); return; }
  vec2 P = (fc - uZoomP) / uZoom + uZoomP;
  // ---- sclera (a shaded sphere)
  vec2 e = (P - uEyeC) / uEyeR; float er = length(e);
  float nz = sqrt(max(0., 1. - er * er));
  vec3 n = vec3(e, nz);
  float diff = clamp(dot(n, normalize(vec3(-.3, -.15, .94))), 0., 1.);
  vec3 sclera = vec3(.97, .93, .89) * (.16 + .92 * diff);
  sclera = mix(sclera, vec3(.74, .45, .42) * (.32 + .6 * diff), smoothstep(.5, 1., er) * .5);
  sclera *= .93 + .07 * fbm(vec3(P * .02, 1.));
  vec3 col = sclera;
  // ---- iris, foreshortened as the eye turns
  vec2 q = P - uIrisC;
  float lk = length(uLook);
  if (lk > .001) { vec2 d = uLook / lk; float al = dot(q, d); vec2 pe = q - al * d; al /= cos(min(lk, 1.) * .62); q = pe + al * d; }
  float r = length(q) / uIrisR, a = atan(q.y, q.x);
  vec3 ca = vec3(cos(a), sin(a), 0.);
  float fib = fbm(vec3(ca.xy * 9., r * 2.2)) * .65 + fbm(vec3(ca.xy * 31., r * 1.2 + 4.)) * .45;
  float crypt = smoothstep(.66, .8, fbm(vec3(ca.xy * 6., r * 5. + 9.)));
  float coll = .52 + .05 * (fbm(vec3(ca.xy * 5., 2.)) - .5);
  vec3 inner = vec3(1., .78, .40), mid = vec3(.78, .43, .14), outer = vec3(.36, .17, .05);
  vec3 iris = mix(inner, mid, smoothstep(coll - .06, coll + .1, r));
  iris = mix(iris, outer, smoothstep(.72, .97, r));
  iris *= .55 + .95 * fib;
  iris = mix(iris, iris * .62, crypt * .8 * smoothstep(coll, coll + .15, r) * (1. - smoothstep(.85, .95, r)));
  iris += vec3(1., .85, .55) * .09 * (1. - smoothstep(0., .04, abs(r - coll)));
  float pr = uPupil;
  iris = mix(vec3(.16, .07, .03) * (.6 + .5 * fib), iris, smoothstep(pr + .012, pr + .045, r));
  iris = mix(vec3(.008), iris, smoothstep(pr, pr + .018, r));
  iris *= mix(1., .55, smoothstep(pr + .02, pr + .1, r) * (1. - smoothstep(pr + .1, pr + .2, r)) * .4);
  float limb = smoothstep(.9, 1.04, r);
  vec3 irisC = mix(iris, vec3(.05, .025, .01), smoothstep(.86, 1., r));
  col = mix(irisC, col, smoothstep(.985, 1.06, r));
  // ---- lids: an almond opening; soft shadow under the upper lid; wet lower lid line
  vec2 o = (P - uOpenC) / uOpenHW;
  float span = clamp(1. - o.x * o.x, 0., 1.);
  float topL = -pow(span, .7) * uOpen, botL = pow(span, .8) * .95 * mix(.55, 1., uOpen);
  float inside = smoothstep(topL - .015, topL + .015, o.y) * (1. - smoothstep(botL - .02, botL + .02, o.y));
  float sh = 1. - smoothstep(topL + .02, topL + .7, o.y); col *= mix(1., .2, sh * sh * (3. - 2. * sh));   // cast shadow of the upper lid
  col *= mix(1., .08, 1. - smoothstep(topL, topL + .07, o.y));         // lash line
  col = mix(col, col * vec3(1., .7, .66), smoothstep(.72, .95, abs(o.x)) * .7);
  col *= mix(1., .7, smoothstep(botL - .14, botL, o.y));
  col += vec3(1., .9, .85) * .25 * (1. - smoothstep(0., .02, abs(o.y - (botL - .03)))) * span;
  // ---- cornea reflections (fixed to the light, not the iris)
  vec2 rc = mix(uEyeC, uIrisC, .65);
  vec2 sp = P - rc - vec2(-.4, -.42) * uIrisR; sp.y += .25 * sp.x * sp.x / uIrisR;
  float soft = (1. - smoothstep(-8., 14., rbox(sp, vec2(.19, .085) * uIrisR, 14.))) * .8;
  float dotH = 1. - smoothstep(0., 7., length(P - rc - vec2(.3, -.3) * uIrisR) - 4.);
  float scr = 1. - smoothstep(-3., 9., rbox(P - rc - vec2(.08, .34) * uIrisR, vec2(.15, .09) * uIrisR, 6.));
  float onC = 1. - smoothstep(.95, 1.15, length(P - rc) / uIrisR);
  col += vec3(1.) * soft * .85 * onC + vec3(1.) * dotH * .9 * onC + vec3(.55, .7, 1.) * scr * (.18 + .3 * uScreen) * onC;
  col += vec3(1., .95, .9) * .07 * (1. - smoothstep(0., 1.1, length(P - rc - vec2(-.3, -.35) * uIrisR) / uIrisR)) * onC;
  // outside the opening: skin in deep shadow
  vec2 sk = (P - uOpenC) / (uOpenHW * vec2(1.25, 2.4));
  vec3 skin = vec3(.13, .075, .055) * (1. - smoothstep(.2, 1.1, length(sk))) * (.75 + .25 * fbm(vec3(P * .05, 3.)));
  skin *= 1. - .6 * (1. - smoothstep(0., .05, abs(o.y - (topL - .28 - .1 * span)))) * span;  // lid crease
  col = mix(skin, col, inside);
  // panel vignette
  vec2 v = (fc - uPanel.xy) / uPanel.zw - .5; col *= 1. - .55 * dot(v * vec2(1.1, 1.6), v * vec2(1.1, 1.6));
  col = pow(max(col, 0.), vec3(.95));
  gl_FragColor = vec4(col * uFade, 1.);
}`;
function sh(type, src) { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s)); return s; }
const pg = gl.createProgram(); gl.attachShader(pg, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(pg, sh(gl.FRAGMENT_SHADER, FS)); gl.linkProgram(pg); gl.useProgram(pg);
const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
const loc = gl.getAttribLocation(pg, 'p'); gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
const U = n => gl.getUniformLocation(pg, n);
// params in page CSS px (the canvas covers the frame; CSS clip-path frames it); the canvas is 2x
window.Iris = {
  draw(o) {
    const k = 2, W = cv.width, H = cv.height;
    const cx = (o.cx ?? 270) * k, cy = (o.cy ?? 238) * k, R = (o.r ?? 88) * k, look = o.look || [0, 0];
    const eyeR = R * 2.25;
    const irisC = [cx + look[0] * R * 1.15, cy + look[1] * R * .95];
    gl.viewport(0, 0, W, H);
    gl.uniform2f(U('uRes'), W, H);
    gl.uniform2f(U('uEyeC'), cx, cy + R * .2);
    gl.uniform1f(U('uEyeR'), eyeR);
    gl.uniform2f(U('uIrisC'), irisC[0], irisC[1]);
    gl.uniform1f(U('uIrisR'), R);
    gl.uniform2f(U('uLook'), look[0], look[1]);
    gl.uniform1f(U('uPupil'), o.pupil ?? .3);
    gl.uniform2f(U('uOpenC'), cx, cy + R * .06);
    gl.uniform2f(U('uOpenHW'), (o.openW ?? 205) * k, R * 1.0);
    gl.uniform1f(U('uOpen'), o.open ?? .9);
    gl.uniform1f(U('uZoom'), o.zoom ?? 1);
    gl.uniform2f(U('uZoomP'), irisC[0], irisC[1]);
    gl.uniform1f(U('uScreen'), o.screen ?? .5);
    gl.uniform1f(U('uFade'), o.fade ?? 1);
    gl.uniform2f(U('uClipX'), (o.clip ? o.clip[0] : 0) * k, (o.clip ? o.clip[1] : 540) * k);
    const pn = o.panel || [20, 116, 500, 236]; gl.uniform4f(U('uPanel'), pn[0] * k, pn[1] * k, pn[2] * k, pn[3] * k);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    return irisC.map(v => v / k);
  },
  clear() { gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT); },
};
})();
