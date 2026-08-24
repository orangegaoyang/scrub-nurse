// Scan a Godot binary .scn for: (1) orthonormal Transform3D blocks (basis
// rows + origin = 12 floats), (2) runs of vertex-like float triples whose
// y is in [0,2.6] and x is narrow (the door thickness axis), to see whether
// the imported mesh z axis was flipped relative to the raw glTF data.
const fs = require('fs');

const file = process.argv[2];
const buf = fs.readFileSync(file);
const N = buf.length - 4 * 12;

console.log('file size:', buf.length, 'bytes');
console.log('--- candidate transform blocks (first 20) ---');
let shown = 0;
for (let off = 0; off <= N && shown < 20; off += 4) {
  const f = [];
  for (let i = 0; i < 12; i++) f.push(buf.readFloatLE(off + 4 * i));
  const r0 = f.slice(0, 3), r1 = f.slice(3, 6), r2 = f.slice(6, 9);
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const len = (a) => Math.sqrt(dot(a, a));
  const isNum = f.every((v) => Number.isFinite(v) && Math.abs(v) < 1e6);
  if (!isNum) continue;
  if (Math.abs(len(r0) - 1) < 0.02 && Math.abs(len(r1) - 1) < 0.02 &&
      Math.abs(len(r2) - 1) < 0.02 && Math.abs(dot(r0, r1)) < 0.02 &&
      Math.abs(dot(r0, r2)) < 0.02 && Math.abs(dot(r1, r2)) < 0.02) {
    console.log('off=' + off,
      'rows=', f.slice(0, 9).map((v) => v.toFixed(4)).join(' '),
      'origin=', f.slice(9).map((v) => v.toFixed(3)).join(' '));
    shown++;
    off += 44; // skip ahead
  }
}

console.log('--- vertex-run scan (x narrow, y in [0,2.6], z in [-1.2,1.2]) ---');
let best = { len: 0 };
let run = 0, runStart = 0;
let zMin = 0, zMax = 0;
for (let off = 0; off <= buf.length - 12; off += 4) {
  const x = buf.readFloatLE(off), y = buf.readFloatLE(off + 4), z = buf.readFloatLE(off + 8);
  const ok = Number.isFinite(x) && Number.isFinite(y) && Number.isFinite(z) &&
    Math.abs(x) < 0.12 && y >= 0 && y <= 2.6 && z >= -1.2 && z <= 1.2;
  if (ok) {
    if (run === 0) runStart = off;
    run++;
    if (run === 1) { zMin = z; zMax = z; }
    else { zMin = Math.min(zMin, z); zMax = Math.max(zMax, z); }
    if (run > best.len) {
      best = { len: run, start: runStart, zMin, zMax };
    }
  } else {
    run = 0;
  }
}
console.log('longest vertex-like run:', JSON.stringify(best, null, 0));
