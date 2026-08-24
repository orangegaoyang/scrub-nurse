// Dump materials/textures/images from a GLB's glTF JSON.
const fs = require('fs');
function glbJson(path) {
  const buf = fs.readFileSync(path);
  let off = 12;
  const total = buf.readUInt32LE(8);
  while (off < total) {
    const len = buf.readUInt32LE(off);
    const type = buf.readUInt32LE(off + 4);
    if (type === 0x4e4f534a) return JSON.parse(buf.subarray(off + 8, off + 8 + len).toString('utf8'));
    off += 8 + len;
  }
  return null;
}
const j = glbJson(process.argv[2]);
console.log('materials:', JSON.stringify(j.materials, null, 1));
console.log('textures:', JSON.stringify(j.textures));
console.log('images:', JSON.stringify(j.images));
console.log('extensionsUsed:', JSON.stringify(j.extensionsUsed));
console.log('meshes[0].primitives[0]:', JSON.stringify(j.meshes[0].primitives[0]));
