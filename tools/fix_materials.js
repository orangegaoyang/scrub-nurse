// Batch-fix extracted glTF materials (.tres) so the Godot editor and the
// running game show the same thing. Run after every glTF re-import:
//   node tools/fix_materials.js [folder]
// Fixes:
//   - metallic = 0            (glTF default 1.0 renders black without sky)
//   - drop metallic_texture   (exporters write a 1x1 white pixel whose blue
//                              channel = metallic 1, overriding the scalar)
//   - specular = 0.5          (KHR_materials_specular [2,2,2] washes out
//                              colours under flat ambient light)
//   - cull_mode = 2           (double-sided, so planes never vanish from
//                              inside)
const fs = require('fs');
const path = require('path');

const dir = process.argv[2] || 'assets/models/corridor/materials';
let count = 0;
if (!fs.existsSync(dir)) {
  console.log('no such folder:', dir, '(open the Godot editor once to re-import and extract materials)');
  process.exit(0);
}
for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith('.tres')) continue;
  const p = path.join(dir, f);
  let s = fs.readFileSync(p, 'utf8');
  let changed = false;
  const sub = (re, rep) => {
    const next = s.replace(re, rep);
    if (next !== s) { s = next; changed = true; }
  };
  sub(/^metallic = .+$/m, 'metallic = 0.0');
  sub(/^metallic_texture = .+\n?/m, '');
  sub(/^specular = .+$/m, 'specular = 0.5');
  sub(/^cull_mode = 0$/m, 'cull_mode = 2');
  if (changed) {
    fs.writeFileSync(p, s);
    console.log('fixed', f);
    count++;
  }
}
console.log('done,', count, 'files changed');
