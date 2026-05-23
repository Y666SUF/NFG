/**
 * Spawn Hangman Python server as a child process (non-blocking).
 */
const { spawn } = require("child_process");
const path = require("path");
const http = require("http");

const HANGMAN_PORT = Number(process.env.HANGMAN_PORT) || 19876;
const HANGMAN_HOST = String(process.env.HANGMAN_HOST || "127.0.0.1").trim() || "127.0.0.1";
const HANGMAN_DIR = path.join(__dirname, "..", "hangman v2");

let hangmanProcess = null;
let owned = false;

function hangmanHealthUrl() {
  return `http://${HANGMAN_HOST}:${HANGMAN_PORT}/api/hangman/status`;
}

function waitForHangman(timeoutMs = 45000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function tick() {
      const req = http.get(hangmanHealthUrl(), (res) => {
        res.resume();
        if (res.statusCode >= 200 && res.statusCode < 400) return resolve(true);
        if (Date.now() - start > timeoutMs) return reject(new Error("Hangman health check timeout"));
        setTimeout(tick, 400);
      });
      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          return reject(new Error("Timed out waiting for Hangman server"));
        }
        setTimeout(tick, 400);
      });
      req.setTimeout(2000, () => {
        req.destroy();
        if (Date.now() - start > timeoutMs) return reject(new Error("Hangman health check timeout"));
        setTimeout(tick, 400);
      });
    }
    tick();
  });
}

function startHangmanProcess() {
  if (process.env.NFG_START_HANGMAN === "0") {
    console.log("[Hangman] Auto-start disabled (NFG_START_HANGMAN=0).");
    return null;
  }
  if (hangmanProcess && !hangmanProcess.killed) return hangmanProcess;

  const py = process.env.HANGMAN_PYTHON || "py";
  const args = ["-m", "uvicorn", "server:app", "--host", HANGMAN_HOST, "--port", String(HANGMAN_PORT)];
  const childEnv = {
    ...process.env,
    HANGMAN_WEB_PORT: String(HANGMAN_PORT),
    NFG_PLATFORM_URL: process.env.NFG_PLATFORM_URL || `http://127.0.0.1:${process.env.PORT || 3847}`,
    NFG_INTERNAL_SECRET: process.env.NFG_INTERNAL_SECRET || "nfg-dev-internal",
    HANGMAN_TIKTOK_COMMENTS_VIA_PLATFORM:
      process.env.HANGMAN_TIKTOK_COMMENTS_VIA_PLATFORM != null
        ? String(process.env.HANGMAN_TIKTOK_COMMENTS_VIA_PLATFORM)
        : "1",
    PYTHONUTF8: "1",
    PYTHONIOENCODING: "utf-8",
  };

  hangmanProcess = spawn(py, args, {
    cwd: HANGMAN_DIR,
    env: childEnv,
    stdio: "inherit",
    windowsHide: true,
  });
  owned = true;

  hangmanProcess.on("exit", (code) => {
    if (code !== 0 && code !== null) {
      console.warn(`[Hangman] Python server exited (code ${code})`);
    }
    hangmanProcess = null;
  });

  console.log(`[Hangman] Starting on http://${HANGMAN_HOST}:${HANGMAN_PORT} (proxied at /hangman/ws, /api/hangman/*)`);
  return hangmanProcess;
}

function stopHangmanProcess() {
  if (!owned || !hangmanProcess || hangmanProcess.killed) return;
  try {
    hangmanProcess.kill();
  } catch {
    /* ignore */
  }
}

module.exports = {
  HANGMAN_PORT,
  HANGMAN_HOST,
  hangmanHealthUrl,
  waitForHangman,
  startHangmanProcess,
  stopHangmanProcess,
};
