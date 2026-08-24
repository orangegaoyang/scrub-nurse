// Dump the glTF JSON chunk from a GLB for inspection.
const fs = require('fs');

function glbJson(path) {
  const buf = fs.readFileSync(path);
  if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error('not GLB: ' + path);
  const total = buf.readUInt32LE(8);
  let off = 12;
  let json = null;
  while (off < total) {
    const len = buf.readUInt32LE(off);
    const type = buf.readUInt32LE(off + 4);
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 0x4e4f534a) { // "JSON"
      json = JSON.parse(data.toString('utf8'));
      break;
    }
    off += 8 + len;
  }
  return json;
}

for (const file of process.argv.slice(2)) {
  const j = glbJson(file);
  console.log('===== ' + file + ' =====');
  console.log('scene:', j.scene, '| scenes:', JSON.stringify(j.scenes));
  console.log('--- nodes ---');
  for (const [i, n] of (j.nodes || []).entries()) {
    console.log(i, JSON.stringify(n));
  }
  console.log('--- meshes ---');
  for (const [i, m] of (j.meshes || []).entries()) {
    for (const p of m.primitives) {
      const acc = p.attributes && p.attributes.POSITION;
      const a = acc != null ? j.accessors[acc] : null;
      console.log('mesh', i, 'name=' + m.name, 'posAcc=' + acc,
        'min=' + JSON.stringify(a && a.min), 'max=' + JSON.stringify(a && a.max));
    }
  }
  console.log('');
}
