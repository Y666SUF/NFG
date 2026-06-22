const fs = require("fs");
const path = require("path");

const indexPath = path.join(__dirname, "..", "public", "play", "index.html");
let html = fs.readFileSync(indexPath, "utf8");
html = html.replace("styles.css?v=5", "styles.css?v=6");
if (!html.includes("is-logged-out")) {
  html = html.replace('<div id="app" class="app">', '<div id="app" class="app is-logged-out">');
}
fs.writeFileSync(indexPath, html);
console.log("index.html patched");
