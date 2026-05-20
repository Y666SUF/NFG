const path = require("path");
const { spawn } = require("child_process");
const http = require("http");
const https = require("https");
const { app, BrowserWindow, dialog } = require("electron");

const {
  waitForHangman,
  startHangmanProcess,
  stopHangmanProcess,
  HANGMAN_PORT,
  HANGMAN_HOST,
} = require("../server/hangman-process");

const PORT = Number(process.env.PORT) || 3847;
const ROOT_URL = `http://127.0.0.1:${PORT}/`;
const HANGMAN_PORT_NUM = Number(process.env.HANGMAN_PORT) || HANGMAN_PORT;
const HANGMAN_HOST_STR = String(process.env.HANGMAN_HOST || HANGMAN_HOST || "127.0.0.1").trim() || "127.0.0.1";
const HANGMAN_URL =
  String(process.env.NFG_HANGMAN_UI_URL || "").trim() ||
  `http://${HANGMAN_HOST_STR}:${HANGMAN_PORT_NUM}/`;
const START_HANGMAN = String(process.env.NFG_START_HANGMAN || "1").trim() !== "0";
const OPEN_HANGMAN_WINDOW = String(process.env.NFG_OPEN_HANGMAN_WINDOW || "1").trim() !== "0";
const IS_PORTRAIT_MODE = process.env.NFG_PORTRAIT === "1";
const SERVER_URL = IS_PORTRAIT_MODE ? `${ROOT_URL}portrait.html` : ROOT_URL;
const ENABLE_CF_TUNNEL = process.env.NFG_CF_TUNNEL === "1";
const CF_TUNNEL_NAME = String(process.env.NFG_CF_TUNNEL_NAME || "nfg-crash").trim();
const CF_TUNNEL_TOKEN = String(process.env.NFG_CF_TUNNEL_TOKEN || "").trim();
let serverProcess = null;
let serverOwnedByElectron = false;
let cloudflaredProcess = null;
let cloudflaredOwnedByElectron = false;
let mainWindow = null;
let lookupWindow = null;
let chatWindow = null;
let hangmanWindow = null;

function waitForServer(url, timeoutMs = 20000) {
  const start = Date.now();

  return new Promise((resolve, reject) => {
    function tryOnce() {
      const req = http.get(url, (res) => {
        res.resume();
        resolve();
      });

      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          reject(new Error("Timed out waiting for local game server."));
          return;
        }
        setTimeout(tryOnce, 300);
      });
    }

    tryOnce();
  });
}

function waitForEndpoint(pathname, timeoutMs = 12000) {
  const start = Date.now();
  const target = `${ROOT_URL.replace(/\/$/, "")}${pathname}`;
  return new Promise((resolve, reject) => {
    function tryOnce() {
      const req = http.get(target, (res) => {
        const ok = Number(res.statusCode || 0) >= 200 && Number(res.statusCode || 0) < 400;
        res.resume();
        if (ok) return resolve();
        if (Date.now() - start > timeoutMs) {
          return reject(new Error(`Endpoint check failed: ${pathname} (${res.statusCode})`));
        }
        setTimeout(tryOnce, 350);
      });
      req.on("error", () => {
        if (Date.now() - start > timeoutMs) {
          reject(new Error(`Timed out waiting for endpoint: ${pathname}`));
          return;
        }
        setTimeout(tryOnce, 350);
      });
    }
    tryOnce();
  });
}

function getLanUrls(port) {
  const out = [];
  const interfaces = require("os").networkInterfaces();
  for (const rows of Object.values(interfaces)) {
    if (!Array.isArray(rows)) continue;
    for (const row of rows) {
      if (!row || row.family !== "IPv4" || row.internal) continue;
      out.push(`http://${row.address}:${port}/`);
    }
  }
  return [...new Set(out)];
}

function getPublicIpv4(timeoutMs = 4500) {
  const override = String(process.env.NFG_PUBLIC_IP || "").trim();
  if (override) return Promise.resolve(override);
  return new Promise((resolve) => {
    const req = https.get("https://api.ipify.org?format=json", (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        try {
          const parsed = JSON.parse(Buffer.concat(chunks).toString("utf8"));
          const ip = String(parsed && parsed.ip ? parsed.ip : "").trim();
          resolve(ip || null);
        } catch {
          resolve(null);
        }
      });
    });
    req.on("error", () => resolve(null));
    req.setTimeout(timeoutMs, () => {
      try {
        req.destroy();
      } catch (_err) {
        // ignore timeout cleanup errors
      }
      resolve(null);
    });
  });
}

function startServer() {
  const serverEntry = path.join(__dirname, "..", "server", "index.js");
  const nodeExe = process.env.NFG_NODE_EXE || process.execPath;
  serverProcess = spawn(nodeExe, [serverEntry], {
    cwd: path.join(__dirname, ".."),
    env: {
      ...process.env,
      NO_BROWSER: "1",
      HOST: process.env.HOST || "0.0.0.0",
      PORT: String(process.env.PORT || PORT),
      HANGMAN_PORT: process.env.HANGMAN_PORT || "19876",
      HANGMAN_HOST: process.env.HANGMAN_HOST || "127.0.0.1",
      HANGMAN_PYTHON: process.env.HANGMAN_PYTHON || "py",
      HANGMAN_BACKEND_URL:
        process.env.HANGMAN_BACKEND_URL ||
        `http://${process.env.HANGMAN_HOST || "127.0.0.1"}:${process.env.HANGMAN_PORT || 19876}`,
      NFG_PLATFORM_URL: process.env.NFG_PLATFORM_URL || `http://127.0.0.1:${PORT}`,
      NFG_INTERNAL_SECRET: process.env.NFG_INTERNAL_SECRET || "nfg-dev-internal",
      NFG_START_HANGMAN: process.env.NFG_START_HANGMAN || "1",
      // Safe fallback if node exe is unavailable and process.execPath is Electron.
      ELECTRON_RUN_AS_NODE: "1",
    },
    stdio: "inherit",
    windowsHide: true,
  });
  serverOwnedByElectron = true;

  serverProcess.on("exit", (code) => {
    if (!app.isQuiting && code !== 0) {
      dialog.showErrorBox(
        "NFG Crash server stopped",
        `The game server exited unexpectedly (code ${code}).`
      );
      app.quit();
    }
  });
}

function stopServer() {
  if (!serverOwnedByElectron) return;
  if (!serverProcess || serverProcess.killed) return;
  try {
    serverProcess.kill();
  } catch (_err) {
    // Ignore process-kill errors during app shutdown.
  }
}

function startCloudflareTunnel() {
  if (!ENABLE_CF_TUNNEL) return;
  const usingToken = !!CF_TUNNEL_TOKEN;
  if (!usingToken && !CF_TUNNEL_NAME) {
    console.warn("[Electron] Cloudflare tunnel name is empty. Skipping tunnel start.");
    return;
  }
  if (cloudflaredProcess && !cloudflaredProcess.killed) return;

  const cloudflaredExe = String(process.env.NFG_CLOUDFLARED_EXE || "cloudflared").trim();
  const userHome = String(process.env.USERPROFILE || process.env.HOME || "").trim();
  const defaultOriginCert = userHome ? path.join(userHome, ".cloudflared", "cert.pem") : "";
  const originCertPath = String(process.env.TUNNEL_ORIGIN_CERT || defaultOriginCert).trim();
  const cloudflaredArgs = usingToken
    ? ["tunnel", "run", "--token", CF_TUNNEL_TOKEN]
    : ["tunnel", "run", CF_TUNNEL_NAME];
  const tunnelEnv = { ...process.env };
  // Prevent cloudflared from echoing token-like env vars in startup logs.
  delete tunnelEnv.NFG_CF_TUNNEL_TOKEN;
  const projectRoot = path.join(__dirname, "..");
  console.log(
    usingToken
      ? `[Electron] Starting Cloudflare Tunnel via token (${cloudflaredExe}) for localhost:${PORT}`
      : `[Electron] Starting Cloudflare Tunnel "${CF_TUNNEL_NAME}" (${cloudflaredExe}) for localhost:${PORT}`
  );
  cloudflaredProcess = spawn(cloudflaredExe, cloudflaredArgs, {
    cwd: projectRoot,
    env: {
      ...tunnelEnv,
      ...(usingToken || !originCertPath ? {} : { TUNNEL_ORIGIN_CERT: originCertPath }),
    },
    stdio: "inherit",
    windowsHide: true,
  });
  cloudflaredOwnedByElectron = true;

  cloudflaredProcess.on("error", (err) => {
    console.warn("[Electron] Failed to start cloudflared:", err.message);
  });

  cloudflaredProcess.on("exit", (code) => {
    cloudflaredProcess = null;
    if (!app.isQuiting && code !== 0) {
      if (usingToken) {
        console.warn(
          `[Electron] Cloudflare tunnel exited unexpectedly (code ${code}). Check NFG_CF_TUNNEL_TOKEN.`
        );
      } else {
        console.warn(
          `[Electron] Cloudflare tunnel exited unexpectedly (code ${code}). Run 'cloudflared tunnel login' once or set NFG_CF_TUNNEL_TOKEN.`
        );
      }
    }
  });
}

function stopCloudflareTunnel() {
  if (!cloudflaredOwnedByElectron) return;
  if (!cloudflaredProcess || cloudflaredProcess.killed) return;
  try {
    cloudflaredProcess.kill();
  } catch (_err) {
    // Ignore tunnel process-kill errors during app shutdown.
  }
}

async function ensureServerReady() {
  // Reuse an already running local server to avoid EADDRINUSE.
  try {
    await waitForServer(ROOT_URL, 1200);
    serverOwnedByElectron = false;
    return;
  } catch (_err) {
    // No local server reachable yet; start one.
  }

  startServer();
  await waitForServer(ROOT_URL, 20000);
}

async function ensureHangmanReady() {
  if (!START_HANGMAN) {
    console.log("[Electron] Hangman auto-start disabled (NFG_START_HANGMAN=0).");
    return false;
  }
  const firstTimeoutMs = serverOwnedByElectron ? 30000 : 6000;
  try {
    await waitForHangman(firstTimeoutMs);
    return true;
  } catch (_firstErr) {
    if (serverOwnedByElectron) {
      console.warn("[Electron] Hangman did not become ready while Node server was starting.");
      return false;
    }
    // Reused platform on 3847 without Hangman — spawn Python from Electron.
    console.log("[Electron] Hangman not up yet; starting Python backend...");
    startHangmanProcess();
    try {
      await waitForHangman(45000);
      return true;
    } catch (err) {
      console.warn("[Electron] Hangman backend failed:", err.message);
      return false;
    }
  }
}

async function createWindows() {
  await ensureServerReady();
  startCloudflareTunnel();
  // Ensure mobile companion endpoints are available when launching via Electron.
  await waitForEndpoint("/api/mobile/status");
  await waitForEndpoint("/api/mobile/chat");
  const hangmanOk = await ensureHangmanReady();
  if (START_HANGMAN) {
    try {
      await waitForEndpoint("/api/hangman/status", 12000);
    } catch (_err) {
      console.warn("[Electron] Hangman API proxy not ready on port", PORT);
    }
  }
  const lanUrls = getLanUrls(PORT);
  if (lanUrls.length) {
    console.log("[Electron] LAN URLs for iPhone/Mac:");
    for (const url of lanUrls) console.log(" ", url);
  }
  getPublicIpv4().then((ip) => {
    if (!ip) return;
    console.log(`[Electron] Public IP URL candidate: http://${ip}:${PORT}/`);
    console.log("[Electron] Mobile data access requires router TCP port-forward 3847 -> this PC.");
  });

  mainWindow = new BrowserWindow({
    width: IS_PORTRAIT_MODE ? 540 : 1600,
    height: IS_PORTRAIT_MODE ? 980 : 900,
    minWidth: IS_PORTRAIT_MODE ? 420 : 1280,
    minHeight: IS_PORTRAIT_MODE ? 760 : 720,
    title: IS_PORTRAIT_MODE ? "NFG Crash - Portrait" : "NFG Crash",
    backgroundColor: "#0b0f19",
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  await mainWindow.loadURL(SERVER_URL);

  lookupWindow = new BrowserWindow({
    width: 560,
    height: 900,
    minWidth: 460,
    minHeight: 640,
    title: "NFG Crash - Player Lookup",
    autoHideMenuBar: true,
    backgroundColor: "#100a1e",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  await lookupWindow.loadURL(`${ROOT_URL}player-lookup.html`);
  lookupWindow.on("closed", () => {
    lookupWindow = null;
  });

  chatWindow = new BrowserWindow({
    width: 420,
    height: 560,
    minWidth: 360,
    minHeight: 420,
    title: "NFG Crash - App Chat",
    autoHideMenuBar: true,
    backgroundColor: "#0b1020",
    webPreferences: { contextIsolation: true, nodeIntegration: false },
  });
  await chatWindow.loadURL(`${ROOT_URL}app-chat.html`);
  chatWindow.on("closed", () => {
    chatWindow = null;
  });

  if (OPEN_HANGMAN_WINDOW && START_HANGMAN) {
    hangmanWindow = new BrowserWindow({
      width: 1480,
      height: 920,
      minWidth: 1080,
      minHeight: 700,
      title: "NFG Hangman",
      autoHideMenuBar: true,
      backgroundColor: "#090d1c",
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
      },
    });
    if (hangmanOk) {
      await hangmanWindow.loadURL(HANGMAN_URL);
      console.log("[Electron] Hangman UI:", HANGMAN_URL);
    } else {
      await hangmanWindow.loadURL(
        `data:text/html,<body style="font-family:system-ui;background:#090d1c;color:#e2e8f0;padding:24px"><h2>NFG Hangman</h2><p>Python backend did not start. Install Python 3 and run <code>py -m pip install uvicorn fastapi</code>, then restart <code>run-electron-cloudflare.bat</code>.</p><p>Expected URL: ${HANGMAN_URL}</p></body>`
      );
    }
    hangmanWindow.on("closed", () => {
      hangmanWindow = null;
    });
  }

  // Place utility windows next to main game when possible.
  try {
    const mainBounds = mainWindow.getBounds();
    const sideX = mainBounds.x + mainBounds.width + 16;
    const sideH = Math.max(640, Math.floor(mainBounds.height * 0.75));
    if (lookupWindow) {
      lookupWindow.setBounds({ x: sideX, y: mainBounds.y, width: 520, height: sideH });
    }
    if (chatWindow) {
      chatWindow.setBounds({
        x: sideX + (lookupWindow ? 532 : 0),
        y: mainBounds.y,
        width: 400,
        height: sideH,
      });
    }
    if (hangmanWindow) {
      const hangmanY = mainBounds.y + mainBounds.height + 12;
      hangmanWindow.setBounds({
        x: mainBounds.x,
        y: hangmanY,
        width: Math.max(1080, mainBounds.width),
        height: Math.min(920, Math.max(640, Math.floor(mainBounds.height * 0.85))),
      });
    }
  } catch (_err) {
    // Keep default sizes/positions if bounds placement fails.
  }

  mainWindow.on("closed", () => {
    mainWindow = null;
    if (lookupWindow && !lookupWindow.isDestroyed()) {
      lookupWindow.close();
    }
    if (chatWindow && !chatWindow.isDestroyed()) {
      chatWindow.close();
    }
    if (hangmanWindow && !hangmanWindow.isDestroyed()) {
      hangmanWindow.close();
    }
  });
}

app.whenReady().then(async () => {
  try {
    await createWindows();
  } catch (err) {
    dialog.showErrorBox("Failed to start NFG Crash", err.message);
    stopServer();
    app.quit();
  }
});

app.on("before-quit", () => {
  app.isQuiting = true;
  stopCloudflareTunnel();
  stopHangmanProcess();
  stopServer();
});

app.on("window-all-closed", () => {
  app.quit();
});
