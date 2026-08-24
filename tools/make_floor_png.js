// Generate assets/2D/transition/corridor_floor.png:
// light-grey big squares (2x2 per tile) with thin darker-grey outlines.
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const W = 512, H = 512;
const LIGHT = [199, 204, 207, 255]; // 浅灰
const LINE = [150, 155, 160, 255];   // 深一些的灰
const CELL = 256;                   // 2x2 大方块
const LW = 2;                       // 细描边宽度

const px = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) px.set(LIGHT, i * 4);
const put = (x, y) => px.set(LINE, (y * W + x) * 4);

// 网格线：边界居中画 LW 宽（b=0 时只向内画）
for (const b of [0, CELL, W]) {
  for (let t = 0; t < LW; t++) {
    const a = b + t, c = b - 1 - t;
    for (let i = 0; i < W; i++) {
      if (a < W) { put(i, a); put(a, i); }
      if (c >= 0) { put(i, c); put(c, i); }
    }
  }
}

// ---- PNG encoding ----
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
ihdr[8] = 8;  // bit depth
ihdr[9] = 6;  // RGBA
// scanlines with filter byte 0
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
const out = path.join(__dirname, '..', 'assets', '2D', 'transition', 'corridor_floor.png');
fs.writeFileSync(out, png);
console.log('wrote', out, png.length, 'bytes');
