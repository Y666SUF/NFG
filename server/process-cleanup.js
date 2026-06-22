/**
 * Kill stale NFG platform listeners (Node 3847, Hangman 19876) before auto-restart.
 * Windows-first; safe no-op elsewhere.
 */
const { execSync } = require("child_process");

const DEFAULT_PORTS = [
  Number(process.env.PORT) || 3847,
  Number(process.env.HANGMAN_PORT) || 19876,
];

function isWindows() {
  return process.platform === "win32";
}

function killPortWindows(port, excludePid) {
  if (!isWindows() || !port) return 0;
  const exclude = Number(excludePid) || 0;
  let killed = 0;
  try {
    const out = execSync(`netstat -ano -p tcp | findstr :${port}`, {
      encoding: "utf8",
      windowsHide: true,
      stdio: ["pipe", "pipe", "ignore"],
    });
    const pids = new Set();
    for (const line of out.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed.toUpperCase().includes("LISTENING")) continue;
      const parts = trimmed.split(/\s+/);
      const pid = Number(parts[parts.length - 1]);
      if (!pid || pid === exclude) continue;
      pids.add(pid);
    }
    for (const pid of pids) {
      try {
        execSync(`taskkill /PID ${pid} /F /T`, { windowsHide: true, stdio: "ignore" });
        killed += 1;
      } catch {
        /* already gone */
      }
    }
  } catch {
    /* no listeners */
  }
  return killed;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function killNfgProcesses(opts = {}) {
  const ports = opts.ports || DEFAULT_PORTS;
  const excludePid = opts.excludePid != null ? opts.excludePid : process.pid;
  let killed = 0;
  for (const port of ports) {
    killed += killPortWindows(Number(port), excludePid);
  }
  if (opts.waitMs) await sleep(opts.waitMs);
  return { killed, ports: ports.map(Number) };
}

module.exports = {
  DEFAULT_PORTS,
  killPortWindows,
  killNfgProcesses,
};
