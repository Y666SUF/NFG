/**
 * Spawn NFG Word Games Python server as a child process (non-blocking).
 */
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const http = require("http");

const WORD_GAMES_PORT = Number(process.env.WORD_GAMES_PORT) || 19877;
const WORD_GAMES_HOST = String(process.env.WORD_GAMES_HOST || "127.0.0.1").trim() || "127.0.0.1";
const WORD_GAMES_DIR =
  process.env.NFG_WORD_GAMES_DIR || path.join(__dirname, "..", "..", "nfg-word-games");

let wordGamesProcess = null;
let owned = false;

function resolveWordGamesPython() {
  if (process.env.WORD_GAMES_PYTHON) return process.env.WORD_GAMES_PYTHON;
  if (process.env.HANGMAN_PYTHON) return process.env.HANGMAN_PYTHON;

  const macVenv = path.join(WORD_GAMES_DIR, ".venv", "bin", "python3");
  const winVenv = path.join(WORD_GAMES_DIR, ".venv", "Scripts", "python.exe");
  if (fs.existsSync(macVenv)) return macVenv;
  if (fs.existsSync(winVenv)) return winVenv;
  return process.platform === "win32" ? "py" : "python3";
}

function wordGamesHealthUrl() {
  return `http://${WORD_GAMES_HOST}:${WORD_GAMES_PORT}/api/word-games/health`;
}

function waitForWordGames(timeoutMs = 45000) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function tick() {
      const req = http.get(wordGamesHealthUrl(), (res) => {
        res.resume();
        if (res.statusCode >= 200 && res.statusCode < 400) return resolve(true);
        if (Date.now() - start > timeoutMs) return reject(new Error("Word Games health check timeout"));
        setTimeout(tick, 400);
      });
      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          return reject(new Error("Timed out waiting for Word Games server"));
        }
        setTimeout(tick, 400);
      });
      req.setTimeout(2000, () => {
        req.destroy();
        if (Date.now() - start > timeoutMs) return reject(new Error("Word Games health check timeout"));
        setTimeout(tick, 400);
      });
    }
    tick();
  });
}

function startWordGamesProcess() {
  if (process.env.NFG_START_WORD_GAMES === "0") {
    console.log("[WordGames] Auto-start disabled (NFG_START_WORD_GAMES=0).");
    return null;
  }
  if (wordGamesProcess && !wordGamesProcess.killed) return wordGamesProcess;

  const py = resolveWordGamesPython();
  const args = ["-m", "uvicorn", "server:app", "--host", WORD_GAMES_HOST, "--port", String(WORD_GAMES_PORT)];
  const childEnv = {
    ...process.env,
    WORD_GAMES_PORT: String(WORD_GAMES_PORT),
    PYTHONUTF8: "1",
    PYTHONIOENCODING: "utf-8",
  };

  wordGamesProcess = spawn(py, args, {
    cwd: WORD_GAMES_DIR,
    env: childEnv,
    stdio: "inherit",
    windowsHide: true,
  });
  owned = true;

  wordGamesProcess.on("exit", (code) => {
    if (code !== 0 && code !== null) {
      console.warn(`[WordGames] Python server exited (code ${code})`);
    }
    wordGamesProcess = null;
  });

  console.log(
    `[WordGames] Starting on http://${WORD_GAMES_HOST}:${WORD_GAMES_PORT} (proxied at /api/word-games/*)`
  );
  return wordGamesProcess;
}

function stopWordGamesProcess() {
  if (!owned || !wordGamesProcess || wordGamesProcess.killed) return;
  try {
    wordGamesProcess.kill();
  } catch {
    /* ignore */
  }
}

module.exports = {
  WORD_GAMES_PORT,
  WORD_GAMES_HOST,
  wordGamesHealthUrl,
  waitForWordGames,
  startWordGamesProcess,
  stopWordGamesProcess,
};
