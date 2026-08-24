// Dump printable ASCII runs from a binary file, with offsets.
const fs = require('fs');
const buf = fs.readFileSync(process.argv[2]);
let run = [];
for (let i = 0; i < buf.length; i++) {
  const b = buf[i];
  if (b >= 32 && b < 127) run.push(String.fromCharCode(b));
  else if (run.length) {
    if (run.length >= 3) console.log(i - run.length, JSON.stringify(run.join('')));
    run = [];
  }
}
if (run.length >= 3) console.log(buf.length - run.length, JSON.stringify(run.join('')));
