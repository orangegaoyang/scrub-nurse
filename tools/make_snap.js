// Generate assets/audio/sfx/snap.wav — the delivery "啪" sound.
// Short click transient + noise body + metallic ring + low thump, ~120 ms.
const fs = 44100, dur = 0.12, n = Math.round(fs * dur);
const data = Buffer.alloc(44 + n * 2);
data.write('RIFF', 0); data.writeUInt32LE(36 + n * 2, 4); data.write('WAVE', 8);
data.write('fmt ', 12); data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20);
data.writeUInt16LE(1, 22); data.writeUInt32LE(fs, 24); data.writeUInt32LE(fs * 2, 28);
data.writeUInt16LE(2, 32); data.writeUInt16LE(16, 34);
data.write('data', 36); data.writeUInt32LE(n * 2, 40);
let seed = 12345;
const rand = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x40000000 - 1;
for (let i = 0; i < n; i++) {
  const t = i / fs;
  let s = 0;
  s += rand() * Math.exp(-t * 260) * 0.8;
  s += Math.sin(2 * Math.PI * 2400 * t) * Math.exp(-t * 90) * 0.35;
  s += Math.sin(2 * Math.PI * 190 * t) * Math.exp(-t * 55) * 0.5;
  if (t < 0.0015) s += rand() * 1.2;
  const v = Math.max(-1, Math.min(1, s)) * 32000 | 0;
  data.writeInt16LE(v, 44 + i * 2);
}
require('fs').writeFileSync(__dirname + '/../assets/audio/sfx/snap.wav', data);
console.log('wrote snap.wav', n, 'frames');
