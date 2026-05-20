const path = require("path");

function getAppRoot() {
  if (process.pkg) {
    return path.dirname(process.execPath);
  }
  return path.join(__dirname, "..");
}

module.exports = { getAppRoot };
