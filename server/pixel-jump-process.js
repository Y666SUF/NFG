/**
 * Spawn Retro Pixel Jump FastAPI server (uvicorn on PIXEL_JUMP_PORT).
 */
const { spawn } = require("child_process");
const path = require("path");
const http = require("http");
const fs = require("fs");

const PIXEL_JUMP_PORT = Number(process.env.PIXEL_JUMP_PORT) || 8001;
const PIXEL_JUMP_HOST = String(process.env.PIXEL_JUMP_HOST || "127.0.0.1").trim() || "127.0.0.1";
const DEFAULT_PIXEL_JUMP_DIR = path.join(
  process.env.USERPROFILE || "C:\\Users\\Yusef",
  "Documents",
  "NFG-JUMP-MULTIPLAYER"
);
const PIXEL_JUMP_DIR = String(process.env.PIXEL_JUMP_DIR || DEFAULT_PIXEL_JUMP_DIR).trim();

let pixelJumpProcess = null;
let owned = false;

function pixelJumpHealthUrl() {
  return `http://${PIXEL_JUMP_HOST}:${PIXEL_JUMP_PORT}/api/`;
}

function waitForPixelJump(timeoutMs = 45000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function tick() {
      const req = http.get(pixelJumpHealthUrl(), (res) => {
        res.resume();
        if (res.statusCode >= 200 && res.statusCode < 400) return resolve(true);
        if (Date.now() - start > timeoutMs) return reject(new Error("Pixel Jump health check timeout"));
        setTimeout(tick, 400);
      });
      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          return reject(new Error("Timed out waiting for Pixel Jump server"));
        }
        setTimeout(tick, 400);
      });
      req.setTimeout(2000, () => {
        req.destroy();
        if (Date.now() - start > timeoutMs) return reject(new Error("Pixel Jump health check timeout"));
        setTimeout(tick, 400);
      });
    }
    tick();
  });
}

function startPixelJumpProcess() {
  if (process.env.NFG_START_PIXEL_JUMP === "0") {
    console.log("[PixelJump] Auto-start disabled (NFG_START_PIXEL_JUMP=0).");
    return null;
  }
  if (!fs.existsSync(path.join(PIXEL_JUMP_DIR, "server.py"))) {
    console.warn(`[PixelJump] server.py not found in ${PIXEL_JUMP_DIR} — skipping auto-start.`);
    return null;
  }
  if (pixelJumpProcess && !pixelJumpProcess.killed) return pixelJumpProcess;

  const py = process.env.PIXEL_JUMP_PYTHON || process.env.HANGMAN_PYTHON || "py";
  const args = ["-m", "uvicorn", "server:app", "--host", PIXEL_JUMP_HOST, "--port", String(PIXEL_JUMP_PORT)];
  const childEnv = {
    ...process.env,
    PUBLIC_PATH_PREFIX: process.env.PUBLIC_PATH_PREFIX || "/api/pixel-jump",
  };

  pixelJumpProcess = spawn(py, args, {
    cwd: PIXEL_JUMP_DIR,
    env: childEnv,
    stdio: "inherit",
    windowsHide: true,
  });
  owned = true;

  pixelJumpProcess.on("exit", (code) => {
    if (code !== 0 && code !== null) {
      console.warn(`[PixelJump] Python server exited (code ${code})`);
    }
    pixelJumpProcess = null;
  });

  console.log(
    `[PixelJump] Starting on http://${PIXEL_JUMP_HOST}:${PIXEL_JUMP_PORT} (public: https://y666suf.com/api/pixel-jump/*)`
  );
  return pixelJumpProcess;
}

function stopPixelJumpProcess() {
  if (!owned || !pixelJumpProcess || pixelJumpProcess.killed) return;
  try {
    pixelJumpProcess.kill();
  } catch {
    /* ignore */
  }
}

module.exports = {
  PIXEL_JUMP_PORT,
  PIXEL_JUMP_HOST,
  PIXEL_JUMP_DIR,
  pixelJumpHealthUrl,
  waitForPixelJump,
  startPixelJumpProcess,
  stopPixelJumpProcess,
};
