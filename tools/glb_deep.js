// Deep-dive: for each mesh, print primitive index counts; for selected
// meshes print world-space vertex positions; print materials with factors.
const fs = require('fs');
const path = process.argv[2];
const sel = new Set((process.argv[3] || '').split(',').map(Number));
const buf = fs.readFileSync(path);
let off = 12, json = null, bin = null;
const total = buf.readUInt32LE(8);
while (off < total) {
  const len = buf.readUInt32LE(off);
  const type = buf.readUInt32LE(off + 4);
  const data = buf.subarray(off + 8, off + 8 + len);
  if (type === 0x4e4f534a) json = JSON.parse(data.toString('utf8'));
  if (type === 0x004e4942) bin = data; // "BIN\0"
  off += 8 + len;
}
const j = json;
console.log('materials:', JSON.stringify(j.materials));

// quaternion helpers
const qmul = (a, b) => [
  a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
  a[3] * b[1] + a[1] * b[3] + a[2] * b[0] - a[0] * b[2],
  a[3] * b[2] + a[2] * b[3] + a[0] * b[1] - a[1] * b[0],
  a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
];
function nodeXform(n) {
  let q = n.rotation || [0, 0, 0, 1];
  const s = n.scale || [1, 1, 1];
  const t = n.translation || [0, 0, 0];
  return { q, s, t };
}
const rot = (q, v) => {
  // v' = v + 2*q.xyz x (q.xyz x v + w*v)  -- standard
  const qv = [q[0], q[1], q[2]], w = q[3];
  const c1 = [qv[1] * v[2] - qv[2] * v[1], qv[2] * v[0] - qv[0] * v[2], qv[0] * v[1] - qv[1] * v[0]];
  const c2 = [c1[0] + w * v[0], c1[1] + w * v[1], c1[2] + w * v[2]];
  const c3 = [qv[1] * c2[2] - qv[2] * c2[1], qv[2] * c2[0] - qv[0] * c2[2], qv[0] * c2[1] - qv[1] * c2[0]];
  return [v[0] + 2 * c3[0], v[1] + 2 * c3[1], v[2] + 2 * c3[2]];
};
const xf = (x, v) => {
  const { q, s, t } = x;
  return rot(q, [v[0] * s[0], v[1] * s[1], v[2] * s[2]]).map((c, i) => c + t[i]);
};
function readAcc(ai) {
  const a = j.accessors[ai];
  const bv = j.bufferViews[a.bufferView];
  const comp = { 5126: 'f', 5123: 'u16', 5125: 'u32' }[a.componentType];
  const ncomp = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[a.type];
  const base = (bv.byteOffset || 0) + (a.byteOffset || 0);
  const out = [];
  for (let i = 0; i < a.count; i++) {
    const p = base + i * ncomp * (comp === 'f' ? 4 : comp === 'u16' ? 2 : 4);
    const vals = [];
    for (let c = 0; c < ncomp; c++) {
      const q = p + c * (comp === 'f' ? 4 : comp === 'u16' ? 2 : 4);
      if (comp === 'f') vals.push(bin.readFloatLE(q));
      else if (comp === 'u16') vals.push(bin.readUInt16LE(q));
      else vals.push(bin.readUInt32LE(q));
    }
    out.push(vals);
  }
  return out;
}
console.log('--- mesh summaries (verts/indices) ---');
j.meshes.forEach((m, i) => {
  const p = m.primitives[0];
  const pos = p.attributes.POSITION;
  const ind = p.indices != null ? j.accessors[p.indices].count : 0;
  console.log(i, m.name, 'verts=' + (pos != null ? j.accessors[pos].count : 0), 'indices=' + ind, 'mode=' + p.mode);
});
for (const mi of sel) {
  const m = j.meshes[mi];
  if (!m) { console.log('mesh', mi, 'not found'); continue; }
  const p = m.primitives[0];
  const pos = p.attributes.POSITION;
  if (pos == null) continue;
  const verts = readAcc(pos);
  const node = j.nodes.find((n) => n.mesh === mi);
  const x = node ? nodeXform(node) : { q: [0, 0, 0, 1], s: [1, 1, 1], t: [0, 0, 0] };
  console.log('--- mesh', mi, m.name, 'node:', node && JSON.stringify(node), 'verts:', verts.length, '---');
  for (const v of verts) {
    const w = xf(x, v);
    console.log(w.map((c) => c.toFixed(3)).join(' '));
  }
}
