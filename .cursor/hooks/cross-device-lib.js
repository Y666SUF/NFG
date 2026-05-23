const fs = require("fs");
const path = require("path");

const ROOT = process.env.CURSOR_PROJECT_DIR || process.cwd();
const CROSS_DIR = path.join(ROOT, "docs", "cross-device");

function pendingPathForPlatform(platform = process.platform) {
  const file = platform === "darwin" ? "pending-on-mac.md" : "pending-on-pc.md";
  return path.join(CROSS_DIR, file);
}

function otherPendingPathForPlatform(platform = process.platform) {
  const file = platform === "darwin" ? "pending-on-pc.md" : "pending-on-mac.md";
  return path.join(CROSS_DIR, file);
}

function readPendingMeta(filePath) {
  if (!fs.existsSync(filePath)) return null;
  const raw = fs.readFileSync(filePath, "utf8");
  const statusMatch = raw.match(/cross_device_status:\s*(\w+)/i);
  const titleMatch = raw.match(/title:\s*(.+)/i);
  const fromMatch = raw.match(/from_device:\s*(\w+)/i);
  const status = statusMatch ? String(statusMatch[1]).toLowerCase() : "none";
  return {
    raw,
    status,
    title: titleMatch ? titleMatch[1].trim().replace(/^["']|["']$/g, "") : "",
    fromDevice: fromMatch ? fromMatch[1].toLowerCase() : "",
    filePath,
  };
}

function isPending(meta) {
  return meta && meta.status === "pending";
}

function agentPromptFor(meta) {
  const rel = path.relative(ROOT, meta.filePath).split(path.sep).join("/");
  return `Run the pending cross-device task in @${rel}`;
}

function deviceLabel(platform = process.platform) {
  return platform === "darwin" ? "Mac" : "PC";
}

function otherDeviceLabel(platform = process.platform) {
  return platform === "darwin" ? "PC" : "Mac";
}

module.exports = {
  ROOT,
  CROSS_DIR,
  pendingPathForPlatform,
  otherPendingPathForPlatform,
  readPendingMeta,
  isPending,
  agentPromptFor,
  deviceLabel,
  otherDeviceLabel,
};
