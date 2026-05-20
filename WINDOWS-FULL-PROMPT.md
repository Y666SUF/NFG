# One-shot Cursor prompt for Windows PC (copy everything below)

Open your **tiktok-live-crash-game** folder in Cursor (must contain `server/index.js`, `package.json`). Start a **new Agent chat**, paste **from the line "PROMPT START" through "PROMPT END"**, and let it implement everything. No manual file copying from Mac.

---

## PROMPT START

You are editing my **NFG Crash** TikTok live game on **Windows** (Node.js + Express, port **3847**). Implement **full iOS companion support** in this repo only. Do **not** create a second server on another port. Do **not** change game rules, gift logic, or WebSocket message shapes except where noted.

My TikTok account: **@y666.suf**  
My iPhone app connects to: `http://<THIS_PC_LAN_IP>:3847` (same Wi‑Fi).

### Deliverables (do all in one pass)

1. **CREATE** `server/mobile-auth.js` — full file (source below)
2. **CREATE** `server/mobile-api.js` — full file (source below)
3. **EDIT** `server/index.js` — requires, mobile API registration, `/api/chat` auth + `!link` handling, listen on `0.0.0.0`, print LAN URLs for iPhone
4. **EDIT** `server/tiktok-bridge.js` — log when a chat message looks like `!link`
5. **CREATE** `scripts/test-link-on-pc.ps1` — PowerShell test script (source below)
6. **CREATE** `scripts/windows-firewall-3847.bat` — allow inbound TCP 3847 (run as admin)
7. Run a quick sanity check (describe commands; do not require TikTok live for basic API test)

### Rules

- **Mobile bets**: `POST /api/chat` with `"source": "mobile"` requires `Authorization: Bearer <token>`; **overwrite** `userId`/`user` from session — never trust client username.
- **!link**: Only completes when TikTok live forwards chat (non-mobile). Message format: `!link CODE` (6 hex chars). iOS polls `GET /api/mobile/link/status/:code`.
- **Do NOT** accept `!link` completion from `source: "mobile"`.
- `isLocalhost(req)` must be passed into `registerMobileApi` for debug route. If `isLocalhost` is defined later in `index.js`, either move it above `registerMobileApi` or rely on function hoisting — prefer moving it **before** `registerMobileApi` for clarity.

---

### FILE: `server/mobile-auth.js` (create or replace entire file)

```javascript
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { getAppRoot } = require("./paths");
const { normalizeUser } = require("./store");

const SESSIONS_FILE = path.join(getAppRoot(), "data", "mobile-sessions.json");
const LINK_TTL_MS = 10 * 60 * 1000;
const SESSION_TTL_MS = 90 * 24 * 60 * 60 * 1000;

/** @type {Map<string, { code: string, deviceId: string, createdAt: number, expiresAt: number }>} */
const pendingByCode = new Map();
/** @type {Map<string, { token: string, userId: string, displayName: string, deviceId: string, createdAt: number, expiresAt: number }>} */
const sessionsByToken = new Map();
/** @type {Map<string, { token: string, userId: string, displayName: string, expiresAt: number }>} */
const linkedByCode = new Map();

function ensureDataDir() {
  const dir = path.dirname(SESSIONS_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function loadSessions() {
  ensureDataDir();
  if (!fs.existsSync(SESSIONS_FILE)) return;
  try {
    const raw = JSON.parse(fs.readFileSync(SESSIONS_FILE, "utf8"));
    const now = Date.now();
    for (const row of raw.sessions || []) {
      if (!row.token || !row.userId || row.expiresAt <= now) continue;
      sessionsByToken.set(row.token, row);
    }
  } catch {
    /* ignore */
  }
}

function saveSessions() {
  ensureDataDir();
  fs.writeFileSync(
    SESSIONS_FILE,
    JSON.stringify({ sessions: Array.from(sessionsByToken.values()), savedAt: Date.now() }, null, 2),
    "utf8"
  );
}

function randomCode() {
  return crypto.randomBytes(3).toString("hex").toUpperCase();
}

/** Parse !link CODE from live chat (tolerates minor TikTok formatting). */
function parseLinkCode(message) {
  const text = String(message || "")
    .trim()
    .replace(/\uFF01/g, "!")
    .replace(/\u00A0/g, " ");
  const m = text.match(/^@?\s*!link\s+([A-Za-z0-9]{4,12})\s*[.!?…]*\s*$/i);
  return m ? m[1].toUpperCase() : null;
}

function randomToken() {
  return crypto.randomBytes(32).toString("hex");
}

function pruneExpired() {
  const now = Date.now();
  for (const [code, row] of pendingByCode) {
    if (row.expiresAt <= now) pendingByCode.delete(code);
  }
  for (const [token, row] of sessionsByToken) {
    if (row.expiresAt <= now) sessionsByToken.delete(token);
  }
  for (const [code, row] of linkedByCode) {
    if (row.expiresAt <= now) linkedByCode.delete(code);
  }
}

function startLink(deviceId) {
  pruneExpired();
  const device = String(deviceId || "unknown").slice(0, 80);
  let code = randomCode();
  while (pendingByCode.has(code)) code = randomCode();
  const now = Date.now();
  pendingByCode.set(code, { code, deviceId: device, createdAt: now, expiresAt: now + LINK_TTL_MS });
  return {
    ok: true,
    code,
    expiresInSeconds: Math.floor(LINK_TTL_MS / 1000),
    instructions: `Comment on the LIVE stream from your TikTok account: !link ${code}`,
    tiktokCommand: `!link ${code}`,
  };
}

function getLinkStatus(code) {
  pruneExpired();
  const key = String(code || "").trim().toUpperCase();
  const linked = linkedByCode.get(key);
  if (linked) {
    return {
      status: "linked",
      code: key,
      userId: linked.userId,
      displayName: linked.displayName,
      token: linked.token,
      expiresAt: linked.expiresAt,
    };
  }
  const pending = pendingByCode.get(key);
  if (pending) {
    return {
      status: "pending",
      code: key,
      secondsLeft: Math.max(0, Math.ceil((pending.expiresAt - Date.now()) / 1000)),
      tiktokCommand: `!link ${key}`,
    };
  }
  return { status: "expired_or_unknown", code: key };
}

function completeLinkFromTikTok(tiktokUserId, displayName, message) {
  pruneExpired();
  const code = parseLinkCode(message);
  if (!code) return { handled: false };

  const pending = pendingByCode.get(code);
  if (!pending || pending.expiresAt <= Date.now()) {
    pendingByCode.delete(code);
    console.warn(
      `[Mobile link] FAILED @${normalizeUser(tiktokUserId) || "?"} code=${code} reason=invalid_or_expired`
    );
    return { handled: true, ok: false, reason: "invalid_or_expired_code", code };
  }

  const userId = normalizeUser(tiktokUserId);
  if (!userId) {
    console.warn(`[Mobile link] FAILED code=${code} reason=invalid_user raw=${tiktokUserId}`);
    return { handled: true, ok: false, reason: "invalid_user" };
  }

  pendingByCode.delete(code);
  const token = randomToken();
  const now = Date.now();
  const session = {
    token,
    userId,
    displayName: String(displayName || userId).slice(0, 60),
    deviceId: pending.deviceId,
    createdAt: now,
    expiresAt: now + SESSION_TTL_MS,
    linkedVia: "tiktok_live",
  };
  sessionsByToken.set(token, session);
  saveSessions();

  linkedByCode.set(code, {
    token,
    userId,
    displayName: session.displayName,
    expiresAt: now + 5 * 60 * 1000,
  });

  console.log(`[Mobile link] OK @${userId} linked via TikTok live code=${code}`);

  return { handled: true, ok: true, code, userId, displayName: session.displayName, token };
}

function getLinkDebug() {
  pruneExpired();
  const now = Date.now();
  return {
    ok: true,
    pending: [...pendingByCode.entries()].map(([code, row]) => ({
      code,
      secondsLeft: Math.max(0, Math.ceil((row.expiresAt - now) / 1000)),
    })),
    pendingCount: pendingByCode.size,
    activeSessions: sessionsByToken.size,
    tip: "Generate code in iPhone app, comment !link CODE on @y666.suf live.",
  };
}

function validateBearer(req) {
  const header = String(req.headers.authorization || "");
  const m = header.match(/^Bearer\s+(.+)$/i);
  const token = m ? m[1].trim() : "";
  if (!token) return null;
  pruneExpired();
  const session = sessionsByToken.get(token);
  if (!session || session.expiresAt <= Date.now()) return null;
  return session;
}

function registerMobileAuthRoutes(app, opts = {}) {
  const isLocalhost = opts.isLocalhost || (() => false);

  app.post("/api/mobile/link/start", (req, res) => {
    const deviceId = String(req.body?.deviceId || req.headers["x-device-id"] || "ios").slice(0, 80);
    const out = startLink(deviceId);
    console.log(`[Mobile link] Code ${out.code} created (expires ${out.expiresInSeconds}s)`);
    res.json(out);
  });

  app.get("/api/mobile/link/debug", (req, res) => {
    if (!isLocalhost(req)) return res.status(403).json({ ok: false, error: "local_pc_only" });
    res.json(getLinkDebug());
  });

  app.get("/api/mobile/link/status/:code", (req, res) => {
    res.json(getLinkStatus(req.params.code));
  });

  app.get("/api/mobile/session", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "invalid_session" });
    res.json({
      ok: true,
      userId: session.userId,
      displayName: session.displayName,
      expiresAt: session.expiresAt,
    });
  });

  app.post("/api/mobile/session/logout", (req, res) => {
    const session = validateBearer(req);
    if (session) {
      sessionsByToken.delete(session.token);
      saveSessions();
    }
    res.json({ ok: true });
  });
}

loadSessions();

module.exports = {
  startLink,
  parseLinkCode,
  completeLinkFromTikTok,
  getLinkStatus,
  getLinkDebug,
  validateBearer,
  registerMobileAuthRoutes,
};
```

---

### FILE: `server/mobile-api.js` (create or replace entire file)

```javascript
const { registerMobileAuthRoutes } = require("./mobile-auth");

function registerMobileApi(app, ctx) {
  const { game, pointStore, isLocalhost } = ctx;

  registerMobileAuthRoutes(app, { isLocalhost });

  app.get("/api/mobile/status", (_req, res) => {
    const state = game.getState();
    res.json({
      ok: true,
      service: "nfg-crash",
      version: "1.0.0",
      phase: state.phase,
      roundId: state.roundId,
      multiplier: state.multiplier,
      playerCount: pointStore.getBalances ? pointStore.getBalances().length : 0,
      sharedData: true,
      message: "iOS uses same points file as TikTok live.",
    });
  });
}

module.exports = { registerMobileApi };
```

---

### EDIT: `server/index.js`

**A) Add requires** (near other requires):

```javascript
const os = require("os");
const { registerMobileApi } = require("./mobile-api");
const { completeLinkFromTikTok, validateBearer } = require("./mobile-auth");
```

**B) Add `isLocalhost` helper** (before `registerMobileApi` call):

```javascript
function isLocalhost(req) {
  const ip = req.socket.remoteAddress || "";
  return ip === "127.0.0.1" || ip === "::1" || ip === "::ffff:127.0.0.1";
}
```

If `isLocalhost` already exists later in the file, **remove the duplicate** and keep one definition above `registerMobileApi`.

**C) After** `const game = new CrashGame(...)` and `app.get("/api/state", ...)`, add:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost });
```

**D) At the start of `app.post("/api/chat", ...)`** (before existing game command logic):

```javascript
const { message, displayName, superFan, superFanLevel, source } = req.body || {};
const isMobile = source === "mobile";

if (isMobile) {
  const session = validateBearer(req);
  if (!session) {
    return res.status(401).json({
      ok: false,
      error: "auth_required",
      message: "Link your TikTok on live first (!link code), or session expired.",
    });
  }
  req.body = {
    ...req.body,
    userId: session.userId,
    user: session.userId,
    displayName: session.displayName || displayName,
  };
}

const user = userKeyFrom(req.body || {});

if (!isMobile && user && message) {
  const link = completeLinkFromTikTok(user, displayName, message);
  if (link.handled) {
    if (!link.ok) {
      console.warn(`[Mobile link] TikTok @${user}: "${String(message).trim()}" → ${link.reason || "failed"}`);
    }
    return res.json({
      ok: link.ok,
      link,
      tiktokChatReply: link.ok
        ? `@${user} — TikTok linked to the mobile app. Open the app to play.`
        : `@${user} — Link code invalid or expired. Generate a new code in the app.`,
    });
  }
}
```

Merge carefully with existing `app.post("/api/chat")` — do not duplicate variable declarations; integrate with existing destructuring if present.

**E) Listen on all interfaces** — change `server.listen(PORT, ...)` to:

```javascript
function lanIPv4Addresses() {
  const out = [];
  for (const ifaces of Object.values(os.networkInterfaces())) {
    for (const net of ifaces || []) {
      if (net.family === "IPv4" && !net.internal) out.push(net.address);
    }
  }
  return [...new Set(out)];
}

const HOST = process.env.HOST || "0.0.0.0";
server.listen(PORT, HOST, () => {
  // ... existing startup logs ...
  const lan = lanIPv4Addresses();
  if (lan.length) {
    console.log("");
    console.log("  iPhone app (same Wi‑Fi) — server URL:");
    for (const ip of lan) console.log(`       http://${ip}:${PORT}`);
  }
  console.log(`Listening on ${HOST}:${PORT}`);
  // ... rest unchanged including startTikTokBridge ...
});
```

---

### EDIT: `server/tiktok-bridge.js`

In the `connection.on(evChat, (data) => {` handler, after `const message = String(data.comment || "").trim();` and before `postChat(...)`:

```javascript
if (/^@?\s*!link\b/i.test(message)) {
  console.log(`[TikTok] !link chat from @${userId}: "${message}"`);
}
```

Ensure `tiktok.config.json` default `uniqueId` is **y666.suf** (or leave as-is if already correct).

---

### FILE: `scripts/test-link-on-pc.ps1`

```powershell
param(
  [Parameter(Mandatory = $true)][string]$Code,
  [string]$User = "y666.suf",
  [string]$BaseUrl = "http://127.0.0.1:3847"
)
Write-Host "=== Pending codes ===" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$BaseUrl/api/mobile/link/debug" | ConvertTo-Json -Depth 5
Write-Host "`n=== Simulate TikTok: !link $Code ===" -ForegroundColor Cyan
$body = @{ userId = $User; displayName = $User; message = "!link $Code" } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$BaseUrl/api/chat" -Method POST -Body $body -ContentType "application/json; charset=utf-8" | ConvertTo-Json -Depth 5
Write-Host "`n=== Status ===" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$BaseUrl/api/mobile/link/status/$Code" | ConvertTo-Json -Depth 5
```

---

### FILE: `scripts/windows-firewall-3847.bat`

```bat
@echo off
netsh advfirewall firewall delete rule name="NFG Crash 3847" >nul 2>&1
netsh advfirewall firewall add rule name="NFG Crash 3847" dir=in action=allow protocol=TCP localport=3847
echo Done. Allow port 3847 inbound.
pause
```

---

### After implementing — verify (print these steps for the user)

1. Run `scripts\windows-firewall-3847.bat` as Administrator (once).
2. `npm start` — console must show `[TikTok] Bridge on — @y666.suf` and **iPhone app** LAN URL(s).
3. `curl http://127.0.0.1:3847/api/mobile/status` → `"ok":true`
4. `curl -X POST http://127.0.0.1:3847/api/mobile/link/start -H "Content-Type: application/json" -d "{\"deviceId\":\"test\"}"` → returns `code` and `tiktokCommand`
5. `.\scripts\test-link-on-pc.ps1 -Code YOURCODE` → `status: linked`
6. On iPhone (same Wi‑Fi): Settings → `http://<PC_IP>:3847` → Get link code → go **live** → comment exact `!link CODE` → app links.

### Do NOT

- Add a separate sync server on 3847
- Let mobile clients set `userId` without Bearer token
- Accept `!link` from `source: "mobile"`

When finished, list every file created/changed and the PC's LAN IP from `ipconfig` for the iPhone Settings URL.

## PROMPT END

---

## After Cursor finishes on Windows

1. Run **`scripts\windows-firewall-3847.bat`** as Admin (once).
2. **`npm start`** — note the **iPhone app** URL printed (e.g. `http://192.168.0.101:3847`).
3. On iPhone: **gear** → paste that URL → **Test connection** → **Get link code**.
4. Go **live** on @y666.suf → comment the exact `!link …` from the app.
5. PC console should show `[TikTok] !link chat` and `[Mobile link] OK`.
