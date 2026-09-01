// Sample pixels from a PNG at a few points to diagnose black/white frames.
const zlib = require('zlib');
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
let off = 8;
const idat = [];
const W = buf.readUInt32BE(16), H = buf.readUInt32BE(20);
const ct = buf[25];
while (off < buf.length) {
  const len = buf.readUInt32BE(off);
  const t = buf.toString('ascii', off + 4, off + 8);
  if (t === 'IDAT') idat.push(buf.subarray(off + 8, off + 8 + len));
  off += 12 + len;
}
const raw = zlib.inflateSync(Buffer.concat(idat));
const bpp = ct === 6 ? 4 : ct === 2 ? 3 : 1;
const stride = W * bpp;
let prev = Buffer.alloc(stride);
const rows = [];
for (let y = 0; y < H; y++) {
  const f = raw[y * (stride + 1)];
  const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
  const cur = Buffer.alloc(stride);
  for (let x = 0; x < stride; x++) {
    const a = x >= bpp ? cur[x - bpp] : 0;
    const bb = y === 0 ? 0 : prev[x];
    const c = x >= bpp ? cur[x - bpp] : 0;
    let v = line[x];
    if (f === 1) v = (v + a) & 255;
    else if (f === 2) v = (v + bb) & 255;
    else if (f === 3) v = (v + ((a + bb) >> 1)) & 255;
    else if (f === 4) {
      const p = a + bb - c;
      const pa = Math.abs(p - a), pb = Math.abs(p - bb), pc = Math.abs(p - c);
      const pr = pa <= pb && pa <= pc ? a : pb <= pc ? bb : c;
      v = (v + pr) & 255;
    }
    cur[x] = v;
  }
  prev = cur;
  rows.push(cur);
}
const pts = [[10, 10], [640, 360], [1270, 710], [100, 600], [640, 100], [320, 360], [960, 360]];
for (const [px, py] of pts) {
  const row = rows[Math.min(py, H - 1)];
  const x = Math.min(px, W - 1) * bpp;
  console.log(`(${px},${py}) = (${row[x]},${row[x + 1]},${row[x + 2]})`);
}
