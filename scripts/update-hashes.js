const fs = require("fs");
const crypto = require("crypto");

function fileHash(path) {
  const data = fs.readFileSync(path);
  return crypto.createHash("sha256").update(data).digest("hex").slice(0, 8);
}

const jsHash = fileHash("priv/app.js");
const cssHash = fileHash("priv/main.css");

const layoutPath = "src/frontend/layout.gleam";
let layout = fs.readFileSync(layoutPath, "utf8");
layout = layout.replace(/const js_hash = "[a-f0-9]+"/, `const js_hash = "${jsHash}"`);
layout = layout.replace(/const css_hash = "[a-f0-9]+"/, `const css_hash = "${cssHash}"`);
fs.writeFileSync(layoutPath, layout);

console.log(`Updated hashes: js=${jsHash} css=${cssHash}`);
