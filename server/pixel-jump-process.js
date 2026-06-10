/**
 * Optional Pixel Jump API bootstrap (docker compose on Windows/Linux host).
 * Set NFG_START_PIXEL_JUMP=1 and NFG_PIXEL_JUMP_DIR to the repo with docker-compose.yml.
 */
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const PIXEL_JUMP_DIR =
  process.env.NFG_PIXEL_JUMP_DIR ||
  path.join(__dirname, "..", "..", "NFG-JUMP-MULTIPLAYER");

let composeProcess = null;

function startPixelJumpProcess() {
  if (process.env.NFG_START_PIXEL_JUMP !== "1") {
    console.log("[PixelJump] Auto-start disabled (set NFG_START_PIXEL_JUMP=1 to enable docker compose).");
    return null;
  }
  if (composeProcess && !composeProcess.killed) return composeProcess;

  const composeFile = path.join(PIXEL_JUMP_DIR, "docker-compose.yml");
  if (!fs.existsSync(composeFile)) {
    console.warn(`[PixelJump] docker-compose.yml not found at ${composeFile}`);
    return null;
  }

  const cmd = process.platform === "win32" ? "docker" : "docker";
  const args = ["compose", "up", "-d", "--build"];
  composeProcess = spawn(cmd, args, {
    cwd: PIXEL_JUMP_DIR,
    stdio: "inherit",
    windowsHide: true,
  });

  composeProcess.on("exit", (code) => {
    if (code !== 0 && code !== null) {
      console.warn(`[PixelJump] docker compose exited (code ${code})`);
    }
    composeProcess = null;
  });

  console.log(`[PixelJump] docker compose up in ${PIXEL_JUMP_DIR}`);
  return composeProcess;
}

module.exports = {
  startPixelJumpProcess,
};
