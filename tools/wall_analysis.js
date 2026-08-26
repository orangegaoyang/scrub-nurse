// Analyze the wall mesh of surgery_room.glb: bucket triangles by dominant
// face normal and report each bucket's bounding box, so we know exactly which
// walls exist, where, and how big.
const fs = require('fs');
const path = process.argv[2];
const wallIdx = Number(process.argv[3] || 9);
const buf = fs.readFileSync(path);
let off = 12, json = null, bin = null;
const total = buf.readUInt32LE(8);
while (off < total) {
  const len = buf.readUInt32LE(off);
  const type = buf.readUInt32LE(off + 4);
  const data = buf.subarray(off + 8, off + 8 + len);
  if (type === 0x4e4f534a) json = JSON.parse(data.toString('utf8'));
  if (type === 0x004e4942) bin = data;
  off += 8 + len;
}
const j = json;
const m = j.meshes[wallIdx];
const p = m.primitives[0];
const posAcc = j.accessors[p.attributes.POSITION];
const indAcc = j.accessors[p.indices];
const bv = j.bufferViews[posAcc.bufferView];
const base = (bv.byteOffset || 0) + (posAcc.byteOffset || 0);
const verts = [];
for (let i = 0; i < posAcc.count; i++) {
  const q = base + i * 12;
  verts.push([bin.readFloatLE(q), bin.readFloatLE(q + 4), bin.readFloatLE(q + 8)]);
}
const ibv = j.bufferViews[indAcc.bufferView];
const ibase = (ibv.byteOffset || 0) + (indAcc.byteOffset || 0);
const idx = [];
for (let i = 0; i < indAcc.count; i++) {
  idx.push(indAcc.componentType === 5123 ? bin.readUInt16LE(ibase + i * 2) : bin.readUInt32LE(ibase + i * 4));
}
const axes = { '+x': [], '-x': [], '+z': [], '-z': [], 'up/down': [], 'other': [] };
function bucket(v) {
  const ax = Math.abs(v[0]), ay = Math.abs(v[1]), az = Math.abs(v[2]);
  if (ay > ax && ay > az) return 'up/down';
  if (ax > az) return v[0] > 0 ? '+x' : '-x';
  return v[2] > 0 ? '+z' : '-z';
}
for (let t = 0; t < idx.length; t += 3) {
  const a = verts[idx[t]], b = verts[idx[t + 1]], c = verts[idx[t + 2]];
  const e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
  const e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
  const n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
  const k = bucket(n);
  axes[k].push([a, b, c]);
}
for (const k of Object.keys(axes)) {
  const tris = axes[k];
  if (!tris.length) continue;
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (const t of tris) for (const v of t) for (let i = 0; i < 3; i++) {
    mn[i] = Math.min(mn[i], v[i]);
    mx[i] = Math.max(mx[i], v[i]);
  }
  console.log(k, 'tris=' + tris.length,
    'bbox=[' + mn.map((v) => v.toFixed(2)) + ']..[' + mx.map((v) => v.toFixed(2)) + ']');
}
// Cluster each vertical-facing bucket by its constant coordinate.
console.log('--- clusters ---');
const axisOf = { '+x': 0, '-x': 0, '+z': 2, '-z': 2 };
for (const k of Object.keys(axisOf)) {
  const tris = axes[k] || [];
  if (!tris.length) continue;
  const a = axisOf[k];
  const clusters = {};
  for (const t of tris) {
    for (const v of t) {
      const key = Math.round(v[a] * 20) / 20;
      (clusters[key] = clusters[key] || []).push(v);
    }
  }
  for (const key of Object.keys(clusters).sort((x, y) => x - y)) {
    const vs = clusters[key];
    let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
    for (const v of vs) for (let i = 0; i < 3; i++) {
      mn[i] = Math.min(mn[i], v[i]);
      mx[i] = Math.max(mx[i], v[i]);
    }
    console.log(k, 'coord=' + key,
      'verts=' + vs.length,
      'bbox=[' + mn.map((v) => v.toFixed(2)) + ']..[' + mx.map((v) => v.toFixed(2)) + ']');
  }
}
