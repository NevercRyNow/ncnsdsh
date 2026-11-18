// NcnsDSH icon 2.0: dark glass tile with the ">ncn._" wordmark.
// Pixel-by-pixel, no image libraries.
// Usage: node tools/make-icon-2.mjs [size]
import zlib from 'node:zlib';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const size = Number(process.argv[2] || 1024);
const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, '..', 'App', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon-1024.png');

const s = size / 1024;
const px = Buffer.alloc(size * size * 4);
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
const smooth = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

function segDist(x, y, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay;
  const wx = x - ax, wy = y - ay;
  const len = vx * vx + vy * vy;
  const t = len === 0 ? 0 : Math.min(1, Math.max(0, (wx * vx + wy * vy) / len));
  return Math.hypot(x - (ax + vx * t), y - (ay + vy * t));
}

// distance to a circular arc, angles in degrees, 0 = +x, 90 = +y (screen)
function arcDist(x, y, cx, cy, r, from, to) {
  const d = Math.hypot(x - cx, y - cy);
  let ang = (Math.atan2(y - cy, x - cx) * 180) / Math.PI;
  if (ang < 0) ang += 360;
  let a = from, b = to;
  if (b < a) b += 360;
  let t = ang;
  if (t < a) t += 360;
  if (t >= a && t <= b) return Math.abs(d - r);
  const p1 = [cx + r * Math.cos((a * Math.PI) / 180), cy + r * Math.sin((a * Math.PI) / 180)];
  const p2 = [cx + r * Math.cos((b * Math.PI) / 180), cy + r * Math.sin((b * Math.PI) / 180)];
  return Math.min(Math.hypot(x - p1[0], y - p1[1]), Math.hypot(x - p2[0], y - p2[1]));
}

// stroke layer: union of primitives, thickness w
function stroke(x, y, w) {
  let d = 1e9;
  const half = w / 2;

  // > 
  d = Math.min(d, segDist(x, y, 205, 432, 300, 512));
  d = Math.min(d, segDist(x, y, 300, 512, 205, 592));

  // n (first)
  d = Math.min(d, segDist(x, y, 336, 592, 336, 474));
  d = Math.min(d, segDist(x, y, 336, 500, 336, 470));
  d = Math.min(d, arcDist(x, y, 392, 470, 56, 180, 360));
  d = Math.min(d, segDist(x, y, 448, 470, 448, 592));

  // c
  d = Math.min(d, arcDist(x, y, 540, 511, 62, 40, 320));

  // n (second)
  d = Math.min(d, segDist(x, y, 624, 592, 624, 474));
  d = Math.min(d, arcDist(x, y, 680, 470, 56, 180, 360));
  d = Math.min(d, segDist(x, y, 736, 470, 736, 592));

  // dot
  d = Math.min(d, Math.hypot(x - 790, y - 592) - 13);

  // underscore
  d = Math.min(d, segDist(x, y, 806, 620, 872, 620));

  return 1 - smooth(half - 1.2, half + 1.2, d);
}

function psf(x, y) {
  // smooth distance from the rounded-square edge, for the glass rim
  const cx = 512, cy = 512, half = 500, radius = 190;
  const qx = Math.abs(x - cx) - half + radius;
  const qy = Math.abs(y - cy) - half + radius;
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - radius;
}

for (let y = 0; y < size; y++) {
  for (let x = 0; x < size; x++) {
    const ux = x / s, uy = y / s;
    const edge = psf(ux, uy);

    // base: near-black with a cool radial tint towards the right edge
    const r1 = Math.hypot(ux - 760, uy - 420) / 900;
    const tint = Math.max(0, 1 - r1);
    let r = 6 + 10 * tint;
    let g = 10 + 22 * tint;
    let b = 16 + 42 * tint;

    // rim glow along the outer edge
    const rim = 1 - smooth(0, 26, Math.abs(edge));
    const rim2 = 1 - smooth(0, 10, Math.abs(edge));
    r += 10 * rim; g += 34 * rim; b += 70 * rim;
    b += 40 * rim2;

    // specular arc: a wide diagonal highlight in the upper right
    const arc = Math.abs(Math.hypot(ux - 250, uy - 120) - 620);
    const spec = (1 - smooth(0, 170, arc)) * smooth(180, 380, ux) * smooth(700, 500, uy);
    r += 90 * spec; g += 110 * spec; b += 140 * spec;

    // soft inner vignette so the wordmark area stays dark
    const vig = 1 - smooth(0, 520, Math.hypot(ux - 512, uy - 512));
    r -= 6 * vig; g -= 8 * vig; b -= 10 * vig;

    // wordmark
    const m = stroke(ux, uy, 26);
    if (m > 0) {
      const t = smooth(430, 600, uy);
      const wr = 252 - 40 * t;
      const wg = 250 - 24 * t;
      const wb = 248 + 6 * t;
      r = r + (wr - r) * m;
      g = g + (wg - g) * m;
      b = b + (wb - b) * m;
    }

    const o = (y * size + x) * 4;
    px[o] = clamp(r);
    px[o + 1] = clamp(g);
    px[o + 2] = clamp(b);
    px[o + 3] = 255;
  }
}

// PNG encode (RGBA, filter 0)
import { deflateSync } from 'node:zlib';
const raw = Buffer.alloc((size * 4 + 1) * size);
for (let y = 0; y < size; y++) {
  raw[y * (size * 4 + 1)] = 0;
  px.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
}
const crcTable = [];
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  crcTable[n] = c >>> 0;
}
const crc = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4);
  c.writeUInt32BE(crc(body));
  return Buffer.concat([len, body, c]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(size, 0);
ihdr.writeUInt32BE(size, 4);
ihdr[8] = 8;
ihdr[9] = 6;
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);
fs.writeFileSync(out, png);
console.log('wrote', out, png.length, 'bytes');
