# Windows Cursor prompt — LIVE badge + full leaderboard (copy below)

Open your **tiktok-live-crash-game** folder in Cursor → **new Agent chat** → paste **PROMPT START** through **PROMPT END**.

---

## PROMPT START

You are editing my **NFG Crash** Windows game server (Node.js, port **3847**). The **iOS app** already works — apply **only** these server updates so the phone can show:

1. **TikTok LIVE / NOT LIVE** in the app (from `/api/mobile/status`)
2. **Full leaderboard** with total player count (`/api/balances?limit=all`)

Do **not** break existing TikTok bridge, bets, WebSocket, or mobile link (`!link`) features.

TikTok account: **@y666.suf**

---

### 1. EDIT `server/tiktok-bridge.js`

**A)** Add **before** `function loadTikTokConfig()`:

```javascript
/** Exposed to mobile app via /api/mobile/status */
let bridgeStatus = {
  enabled: false,
  uniqueId: "y666.suf",
  state: "disabled", // disabled | waiting | live | offline
  roomId: null,
  updatedAt: 0,
};

function setBridgeStatus(patch) {
  Object.assign(bridgeStatus, patch, { updatedAt: Date.now() });
}

function getTikTokBridgeStatus() {
  return { ...bridgeStatus };
}
```

**B)** In `startTikTokBridge`, when bridge is off:

```javascript
if (process.env.TIKTOK_BRIDGE === "0") {
  console.log("[TikTok] Bridge off (TIKTOK_BRIDGE=0).");
  setBridgeStatus({ enabled: false, state: "disabled", roomId: null });
  return;
}
```

And when `cfg.enabled === false`:

```javascript
setBridgeStatus({ enabled: false, state: "disabled", roomId: null });
return;
```

**C)** After `uniqueId` is set (trimmed), add:

```javascript
setBridgeStatus({ enabled: true, uniqueId, state: "waiting", roomId: null });
```

**D)** Inside the connection loop `try` block, around connect:

```javascript
setBridgeStatus({ state: "waiting", roomId: null });
console.log(`[TikTok] Waiting until @${uniqueId} is LIVE...`);
await connection.waitUntilLive();
setBridgeStatus({ state: "live" });
console.log("[TikTok] Live — connecting...");
const state = await connection.connect();
const roomId = state && state.roomId ? String(state.roomId) : null;
setBridgeStatus({ state: "live", roomId });
console.log("[TikTok] Connected.", roomId ? `roomId=${roomId}` : "");
```

**E)** In `catch`:

```javascript
setBridgeStatus({ state: "offline", roomId: null });
```

**F)** In `finally` (before disconnect):

```javascript
setBridgeStatus({ state: "waiting", roomId: null });
```

**G)** Update exports:

```javascript
module.exports = { startTikTokBridge, loadTikTokConfig, getTikTokBridgeStatus };
```

---

### 2. EDIT `server/mobile-api.js`

**A)** Add require at top:

```javascript
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
```

**B)** Replace `GET /api/mobile/status` handler body to include TikTok live + correct player count:

```javascript
app.get("/api/mobile/status", (_req, res) => {
  const state = game.getState();
  const tiktok = getTikTokBridgeStatus();
  const playerCount = pointStore.listBalances ? pointStore.listBalances(999999).length : 0;
  res.json({
    ok: true,
    service: "nfg-crash",
    version: "1.0.0",
    phase: state.phase,
    roundId: state.roundId,
    multiplier: state.multiplier,
    playerCount,
    sharedData: true,
    tiktokLive: {
      ...tiktok,
      isLive: tiktok.state === "live",
    },
    message:
      "Connect iOS to this server. Bets and balances use the same points file as TikTok live.",
  });
});
```

Remove any broken `pointStore.getBalances` call if present — use `listBalances(999999).length` only.

---

### 3. EDIT `server/index.js`

Replace `GET /api/balances` with:

```javascript
app.get("/api/balances", (req, res) => {
  const total = pointStore.listBalances(999999).length;
  const rawLimit = String(req.query.limit || "50").trim().toLowerCase();
  let limit = 50;
  if (rawLimit === "all" || rawLimit === "0") limit = 999999;
  else {
    const n = parseInt(rawLimit, 10);
    if (Number.isFinite(n) && n > 0) limit = Math.min(999999, n);
  }
  const rows = pointStore.listBalances(limit).map((row) => {
    const lock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(row.user) : null;
    return {
      ...row,
      jetLockActive: !!(lock && lock.active),
      jetLockMsLeft: lock ? Number(lock.msLeft || 0) : 0,
      jetLockSecondsLeft: lock ? Number(lock.secondsLeft || 0) : 0,
      jetLockUntil: lock ? Number(lock.blockedUntil || 0) : 0,
    };
  });
  res.json({ balances: rows, total, shown: rows.length });
});
```

Keep the existing `jetLock` mapping logic from the old handler — only add `limit` / `total` / `shown`.

---

### 4. Verify after `npm start`

```powershell
curl http://127.0.0.1:3847/api/mobile/status
```

Expect JSON with `"tiktokLive": { "state": "waiting" or "live", "isLive": true/false, "uniqueId": "y666.suf" }`.

```powershell
curl "http://127.0.0.1:3847/api/balances?limit=all"
```

Expect `"total": <number>`, `"shown": <same or less>`, and `"balances": [ ... ]` with more than 50 entries if you have that many players.

When you go **live** on TikTok, console should show `[TikTok] Connected` and `tiktokLive.state` should become `"live"`.

---

### Do NOT

- Change port 3847
- Remove mobile-auth / !link flow
- Break WebSocket state broadcasts

List files changed when done.

## PROMPT END
