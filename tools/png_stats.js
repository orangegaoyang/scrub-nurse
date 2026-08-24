// PNG stats: decode 8-bit RGBA PNG, report mean color and alpha coverage.
const zlib = require('zlib');
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
let off = 8;
let idat = [];
const W = buf.readUInt32BE(16), H = buf.readUInt32BE(20);
const bd = buf[24], ct = buf[25];
while (off < buf.length) {
  const len = buf.readUInt32BE(off);
  const t = buf.toString('ascii', off + 4, off + 8);
  if (t === 'IDAT') idat.push(buf.subarray(off + 8, off + 8 + len));
  off += 12 + len;
}
const raw = zlib.inflateSync(Buffer.concat(idat));
// Palette support
let palette = null;
if (ct === 3) {
  let o = 8;
  while (o < buf.length) {
    const len = buf.readUInt32BE(o);
    const t = buf.toString('ascii', o + 4, o + 8);
    if (t === 'PLTE') {
      palette = buf.subarray(o + 8, o + 8 + len);
      break;
    }
    o += 12 + len;
  }
  if (!palette) { console.log('no PLTE chunk'); process.exit(1); }
}
const bpp = ct === 6 ? 4 : ct === 2 ? 3 : 1;
const stride = W * bpp;
let r = 0, g = 0, b = 0, n = 0, alphaMin = 255, alphaMax = 0, opaque = 0;
let prev = Buffer.alloc(stride);
for (let y = 0; y < H; y++) {
  const f = raw[y * (stride + 1)];
  const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
  let cur = Buffer.alloc(stride);
  for (let x = 0; x < stride; x++) {
    const a = x >= bpp ? cur[x - bpp] : 0;
    const bb = y === 0 ? 0 : prev[x];
    const c = x >= bpp ? cur[x - bpp] : 0;
    let v = line[x];
    if (f === 1) v = (v + a) & 255;
    else if (f === 2) v = (v + bb) & 255;
    else if (f === 3) v = (v + ((a + bb) >> 1)) & 255;
    else if (f === 4) {
      const p = (a + bb - c);
      const pa = Math.abs(p - a), pb = Math.abs(p - bb), pc = Math.abs(p - c);
      const pr = pa <= pb && pa <= pc ? a : pb <= pc ? bb : c;
      v = (v + pr) & 255;
    }
    cur[x] = v;
  }
  prev = cur;
  for (let x = 0; x < W; x++) {
    let rp, gp, bp;
    if (ct === 3) {
      const idx = cur[x] * 3;
      rp = palette[idx]; gp = palette[idx + 1]; bp = palette[idx + 2];
    } else {
      const px = cur.subarray(x * bpp, x * bpp + bpp);
      rp = px[0]; gp = px[1]; bp = px[2];
    }
    r += rp; g += gp; b += bp; n++;
    if (bpp === 4) {
      const al = cur[x * bpp + 3];
      if (al < alphaMin) alphaMin = al;
      if (al > alphaMax) alphaMax = al;
      if (al > 250) opaque++;
    }
  }
}
console.log(`size ${W}x${H} bitdepth ${bd} colortype ${ct}`);
console.log(`mean RGB = (${Math.round(r / n)}, ${Math.round(g / n)}, ${Math.round(b / n)})`);
if (bpp === 4) console.log(`alpha range ${alphaMin}..${alphaMax}, opaque px ${opaque}/${n}`);
