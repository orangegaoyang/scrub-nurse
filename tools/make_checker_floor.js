// Generate assets/2D/common/floor_checker.png: repeatable lavender/grey
// checkerboard tile with thin grout lines, matching the reference surgery
// floor. 4x4 checks per tile so the plane UV can repeat it.
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const W = 512, H = 512;
const CHECKS = 4;
const CELL = W / CHECKS;

// Reference floor: soft lavender squares + pale grey squares.
const A = [172, 150, 200, 255]; // lavender (deep, survives toon banding)
const B = [244, 240, 248, 255]; // pale grey (bright)
const GROUT = [150, 136, 172, 255];
const LW = 3;

const px = Buffer.alloc(W * H * 4);
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const cx = Math.floor(x / CELL);
    const cy = Math.floor(y / CELL);
    const c = ((cx + cy) % 2 === 0) ? A : B;
    px.set(c, (y * W + x) * 4);
  }
}
const put = (x, y) => { if (x >= 0 && x < W && y >= 0 && y < H) px.set(GROUT, (y * W + x) * 4); };
for (let i = 0; i <= CHECKS; i++) {
  const a = Math.floor(i * CELL);
  for (let t = 0; t < LW; t++) {
    for (let k = 0; k < W; k++) {
      put(a + t, k);
      put(k, a + t);
    }
  }
}

// ---- PNG encode (same approach as make_floor_png.js) ----
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0);
ihdr.writeUInt32BE(H, 4);
ihdr[8] = 8;
ihdr[9] = 6;
const raw = Buffer.alloc(H * (1 + W * 4));
for (let y = 0; y < H; y++) {
  raw[y * (1 + W * 4)] = 0;
  px.copy(raw, y * (1 + W * 4) + 1, y * W * 4, (y + 1) * W * 4);
}
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);
const out = path.join(__dirname, '..', 'assets', '2D', 'common', 'floor_checker.png');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, png);
console.log('wrote', out, png.length, 'bytes');
