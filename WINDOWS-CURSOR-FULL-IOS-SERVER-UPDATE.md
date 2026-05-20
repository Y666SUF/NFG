# Windows Cursor — FULL iOS companion server update (copy below the line)

Copy **everything from "PROMPT START" through "PROMPT END"** into a **new Cursor Agent chat** on your **Windows PC** in the **tiktok-live-crash-game** (NFG Crash) project folder.

---

## PROMPT START

You are updating my **NFG Crash** Windows game server so the **iOS companion app** (`com.nfg.crash`) works fully.

### Environment (do not break)

| Item | Value |
|------|--------|
| Port | **3847** |
| Public URL | **https://y666suf.com** (Cloudflare tunnel → this PC) |
| TikTok | **@y666.suf** |
| Points | Same `pointStore` / data file as TikTok LIVE |

**Do not break:** TikTok bridge, crash game loop, bets, WebSocket, `!link` / mobile auth, `/api/state`, leaderboard, Electron main game window.

---

### What the iPhone app needs (all of this)

1. **Active players in app** — count + **who is online** (names list, Super Fan badges)
2. **App chat** — messages with **Super Fan ★** badges from game data
3. **Rewarded ads** — **10,000 pts**, **no cooldown**, **unlimited** per day
4. **Wallet** — `GET /api/mobile/me` full balance/inventory/superFan
5. **Legal website** — `https://y666suf.com/privacy` and `/legal` for App Store
6. **LIVE status** — `GET /api/mobile/status` with `tiktokLive`, `activeAppUsers`, `activeAppUserList`

---

### Fastest path: copy from Mac

If the user synced the Mac folder **`nfg-crash`**, copy these into Windows **`server/`** (overwrite):

- `mobile-api.js`
- `mobile-presence.js`
- `mobile-chat.js`
- `mobile-player-badges.js`
- `mobile-rewarded-ad.js`
- `mobile-wallet.js` (create if missing — see below)

Copy **`website/privacy.html`** to Windows **`website/privacy.html`**, then create `website/index.html` and `website/legal.html` (Part G).

Still do **Part F** (`index.js` / main server) and **Part G** (Express routes + website pages) even when copying files.

---

### Part A — `server/mobile-api.js` (REPLACE ENTIRE FILE)

```javascript
/**
 * Mobile / iOS companion endpoints.
 */
const { registerMobileAuthRoutes, validateBearer } = require("./mobile-auth");
const { getTikTokBridgeStatus } = require("./tiktok-bridge");
const { registerMobileChatRoutes } = require("./mobile-chat");
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");
const { registerMobileStoreRoutes } = require("./mobile-store");
const {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
} = require("./mobile-presence");
const { buildWalletPayload } = require("./mobile-wallet");

function registerMobileApi(app, ctx) {
  const { game, pointStore, isLocalhost, broadcast } = ctx;

  registerMobileAuthRoutes(app, { isLocalhost });
  if (typeof broadcast === "function") {
    registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
  }
  registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobileStoreRoutes(app, { pointStore, validateBearer, broadcast });
  registerMobilePresenceRoutes(app, { validateBearer, pointStore });

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
      activeAppUsers: getActiveAppUserCount(),
      activeAppUserList: getActiveAppUserList(pointStore),
      sharedData: true,
      tiktokLive: {
        ...tiktok,
        isLive: tiktok.state === "live",
      },
      message:
        "Connect iOS to this server. Bets and balances use the same points file as TikTok live.",
    });
  });

  app.get("/api/mobile/me", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    res.json(buildWalletPayload(session.userId, pointStore, game));
  });
}

module.exports = { registerMobileApi, buildWalletPayload };
```

---

### Part B — `server/mobile-player-badges.js` (CREATE)

```javascript
/**
 * Super Fan / name badges from the same pointStore data as TikTok live + wallet.
 */
function playerBadgesFromStore(pointStore, userId) {
  if (!pointStore || !userId) {
    return {
      superFan: false,
      superFanLevel: 0,
      nameStyle: "none",
      nameBadge: "none",
    };
  }
  try {
    pointStore.ensureAccount(userId);
    const view = pointStore.getUserPresentation(userId);
    return {
      superFan: !!view.superFan,
      superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
      nameStyle: view.nameStyle || "none",
      nameBadge: view.nameBadge || "none",
    };
  } catch {
    return {
      superFan: false,
      superFanLevel: 0,
      nameStyle: "none",
      nameBadge: "none",
    };
  }
}

module.exports = { playerBadgesFromStore };
```

---

### Part C — `server/mobile-presence.js` (REPLACE ENTIRE FILE)

```javascript
/**
 * Tracks iOS app users currently active (heartbeat within TTL).
 */
const { playerBadgesFromStore } = require("./mobile-player-badges");

const PRESENCE_TTL_MS = 90_000;
const presenceByKey = new Map();

function presenceKey(userId, deviceId) {
  if (userId) return `user:${String(userId).toLowerCase()}`;
  if (deviceId) return `device:${String(deviceId).trim()}`;
  return null;
}

function guestDisplayName(deviceId) {
  const id = String(deviceId || "").trim();
  if (!id) return "Guest (not linked)";
  return `Guest ···${id.slice(-4)}`;
}

function pruneStale() {
  const cutoff = Date.now() - PRESENCE_TTL_MS;
  for (const [key, row] of presenceByKey) {
    if (!row.lastSeen || row.lastSeen < cutoff) presenceByKey.delete(key);
  }
}

function touchPresence(key, meta = {}) {
  if (!key) return;
  const prev = presenceByKey.get(key) || {};
  presenceByKey.set(key, {
    userId: meta.userId || prev.userId || null,
    displayName: meta.displayName || prev.displayName || null,
    deviceId: meta.deviceId || prev.deviceId || null,
    lastSeen: Date.now(),
  });
  pruneStale();
}

function getActiveAppUserCount() {
  pruneStale();
  return presenceByKey.size;
}

function getActiveAppUserList(pointStore) {
  pruneStale();
  const rows = [];
  for (const [key, row] of presenceByKey) {
    const linked = !!row.userId;
    const deviceId = row.deviceId || (key.startsWith("device:") ? key.slice(7) : null);
    const userId = linked
      ? String(row.userId).toLowerCase()
      : `guest:${deviceId || key}`;
    const displayName = linked
      ? row.displayName || row.userId
      : guestDisplayName(deviceId);
    const entry = {
      userId,
      displayName,
      username: linked ? String(row.userId).toLowerCase() : null,
      isGuest: !linked,
    };
    if (linked) {
      Object.assign(entry, playerBadgesFromStore(pointStore, row.userId));
    } else {
      Object.assign(entry, {
        superFan: false,
        superFanLevel: 0,
        nameStyle: "none",
        nameBadge: "none",
      });
    }
    rows.push(entry);
  }
  rows.sort((a, b) =>
    String(a.displayName || "").localeCompare(String(b.displayName || ""), undefined, {
      sensitivity: "base",
    })
  );
  return rows;
}

function presencePayload(pointStore) {
  const users = getActiveAppUserList(pointStore);
  return {
    activeAppUsers: users.length,
    activeAppUserList: users,
  };
}

function registerMobilePresenceRoutes(app, ctx) {
  const { validateBearer, pointStore } = ctx;

  app.get("/api/mobile/presence/active", (_req, res) => {
    res.json({ ok: true, ...presencePayload(pointStore) });
  });

  app.post("/api/mobile/presence/heartbeat", (req, res) => {
    const session = typeof validateBearer === "function" ? validateBearer(req) : null;
    const deviceId = String(
      req.headers["x-device-id"] || req.body?.deviceId || ""
    ).trim();
    const key = presenceKey(session?.userId, deviceId);
    if (!key) {
      return res.status(400).json({
        ok: false,
        error: "device_required",
        message: "Send X-Device-Id header or deviceId in body.",
      });
    }
    touchPresence(key, {
      userId: session?.userId || null,
      displayName: session?.displayName || session?.userId || null,
      deviceId: deviceId || null,
    });
    res.json({ ok: true, ...presencePayload(pointStore) });
  });
}

module.exports = {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
  presencePayload,
};
```

---

### Part D — `server/mobile-chat.js` (CREATE OR REPLACE)

```javascript
/**
 * In-app chat between mobile players (separate from TikTok !commands).
 */
const crypto = require("crypto");
const { playerBadgesFromStore } = require("./mobile-player-badges");

const MAX_MESSAGES = 120;
const MAX_MESSAGE_LEN = 240;
const RATE_LIMIT_MS = 1200;

const messages = [];
const lastSentAt = new Map();

function enrichChatRow(row, pointStore) {
  if (!row || !row.userId) return row;
  return { ...row, ...playerBadgesFromStore(pointStore, row.userId) };
}

function listMessages(limit = 50, pointStore) {
  const n = Math.min(MAX_MESSAGES, Math.max(1, Math.floor(Number(limit) || 50)));
  return messages.slice(-n).map((row) => enrichChatRow(row, pointStore));
}

function appendMessage(row) {
  messages.push(row);
  while (messages.length > MAX_MESSAGES) messages.shift();
}

function registerMobileChatRoutes(app, ctx) {
  const { broadcast, validateBearer, pointStore } = ctx;

  app.get("/api/mobile/chat", (req, res) => {
    const limit = Number(req.query.limit) || 50;
    res.json({ ok: true, messages: listMessages(limit, pointStore) });
  });

  app.post("/api/mobile/chat", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const raw = String(req.body?.message || "").trim();
    if (!raw) {
      return res.status(400).json({ ok: false, error: "empty_message" });
    }
    if (raw.length > MAX_MESSAGE_LEN) {
      return res.status(400).json({ ok: false, error: "message_too_long", max: MAX_MESSAGE_LEN });
    }
    if (raw.startsWith("!")) {
      return res.status(400).json({
        ok: false,
        error: "commands_not_allowed",
        message: "Use the bet box for !commands. App chat is for messages only.",
      });
    }

    const now = Date.now();
    const last = lastSentAt.get(session.userId) || 0;
    if (now - last < RATE_LIMIT_MS) {
      const wait = Math.ceil((RATE_LIMIT_MS - (now - last)) / 1000);
      return res.status(429).json({ ok: false, error: "rate_limited", secondsLeft: wait });
    }
    lastSentAt.set(session.userId, now);

    const row = enrichChatRow(
      {
        id: crypto.randomBytes(8).toString("hex"),
        userId: session.userId,
        displayName: session.displayName || session.userId,
        message: raw,
        at: now,
      },
      pointStore
    );
    appendMessage(row);

    const badge = row.superFan ? " ★" : "";
    console.log(`[App chat] ${row.displayName}${badge} (@${row.userId}): ${row.message}`);

    if (typeof broadcast === "function") {
      broadcast({ type: "app_chat", payload: row });
    }
    res.json({ ok: true, message: row });
  });
}

module.exports = { registerMobileChatRoutes, listMessages };
```

---

### Part E — `server/mobile-rewarded-ad.js` (REPLACE — unlimited ads)

```javascript
/**
 * Rewarded video claims from the iOS app (watch ad → points on server).
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const REWARD_AMOUNT = 10_000;
const COOLDOWN_MS = 0;

const CLAIMS_FILE = path.join(getAppRoot(), "data", "mobile-ad-claims.json");

function loadClaims() {
  try {
    const raw = fs.readFileSync(CLAIMS_FILE, "utf8");
    const data = JSON.parse(raw);
    return data && typeof data === "object" ? data : {};
  } catch {
    return {};
  }
}

function saveClaims(data) {
  fs.mkdirSync(path.dirname(CLAIMS_FILE), { recursive: true });
  fs.writeFileSync(CLAIMS_FILE, JSON.stringify(data, null, 2));
}

function dayKey(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function userRecord(all, userId) {
  if (!all[userId]) {
    all[userId] = { lastClaimAt: 0, byDay: {} };
  }
  return all[userId];
}

function claimsToday(rec) {
  return Math.floor(Number(rec.byDay[dayKey()]) || 0);
}

function getStatus(userId) {
  const all = loadClaims();
  const rec = userRecord(all, userId);
  const today = claimsToday(rec);
  const now = Date.now();
  const last = Math.max(0, Number(rec.lastClaimAt) || 0);
  const cooldownLeftMs = Math.max(0, COOLDOWN_MS - (now - last));
  const canClaim = cooldownLeftMs === 0;

  return {
    rewardAmount: REWARD_AMOUNT,
    claimsToday: today,
    maxClaimsPerDay: null,
    unlimited: true,
    cooldownSecondsLeft: Math.ceil(cooldownLeftMs / 1000),
    canClaim,
    reason: cooldownLeftMs > 0 ? "cooldown" : null,
    nextClaimAt: canClaim ? null : last + COOLDOWN_MS,
  };
}

function recordClaim(userId) {
  const all = loadClaims();
  const rec = userRecord(all, userId);
  const dk = dayKey();
  rec.lastClaimAt = Date.now();
  rec.byDay[dk] = claimsToday(rec) + 1;
  saveClaims(all);
}

function registerMobileRewardedAdRoutes(app, ctx) {
  const { pointStore, validateBearer, broadcast } = ctx;

  app.get("/api/mobile/rewarded-ad/status", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }
    res.json({ ok: true, ...getStatus(session.userId) });
  });

  app.post("/api/mobile/rewarded-ad/claim", (req, res) => {
    const session = validateBearer(req);
    if (!session) {
      return res.status(401).json({
        ok: false,
        error: "auth_required",
        message: "Link your TikTok account on live first.",
      });
    }

    const user = session.userId;
    const status = getStatus(user);
    if (!status.canClaim) {
      return res.status(429).json({
        ok: false,
        error: status.reason,
        message: `Wait ${status.cooldownSecondsLeft}s before the next ad reward.`,
        ...status,
      });
    }

    pointStore.ensureAccount(user);
    pointStore.credit(user, REWARD_AMOUNT, { countAsEarned: true });
    recordClaim(user);

    const balance = pointStore.getBalance(user);
    if (typeof broadcast === "function") {
      broadcast({
        type: "balance_toast",
        payload: {
          user,
          balance,
          gained: REWARD_AMOUNT,
          source: "rewarded_ad",
        },
      });
    }

    const after = getStatus(user);
    res.json({
      ok: true,
      gained: REWARD_AMOUNT,
      balance,
      claimsToday: after.claimsToday,
      maxClaimsPerDay: null,
      unlimited: true,
      cooldownSecondsLeft: after.cooldownSecondsLeft,
      canClaim: after.canClaim,
    });
  });
}

module.exports = { registerMobileRewardedAdRoutes, REWARD_AMOUNT };
```

---

### Part F — `server/mobile-wallet.js` (CREATE if missing)

```javascript
/**
 * Full wallet payload for mobile (balance + inventory from same data as !balance).
 */
function buildWalletPayload(user, pointStore, game) {
  pointStore.ensureAccount(user);
  const view = pointStore.getUserPresentation(user);
  const economy = pointStore.getEconomyProfile(user);
  const shield = pointStore.getShieldStatus(user);
  const inventory =
    typeof pointStore.getPowerupInventory === "function"
      ? pointStore.getPowerupInventory(user)
      : { stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0 };
  const reset = pointStore.getMissionResetInfo();
  const jetLock = typeof game.getJetLockStatus === "function" ? game.getJetLockStatus(user) : null;

  return {
    ok: true,
    user: view.user,
    displayName: view.displayName,
    nameStyle: view.nameStyle,
    nameBadge: view.nameBadge || "none",
    ownedBadges: Array.isArray(view.ownedBadges) ? view.ownedBadges : [],
    superFan: !!view.superFan,
    superFanLevel: Math.max(0, Math.floor(Number(view.superFanLevel) || 0)),
    level: view.level,
    rank: view.rank,
    balance: pointStore.getBalance(user),
    allTime: pointStore.getAllTime(user),
    xp: economy ? economy.xp : 0,
    dailyStreak: economy ? economy.dailyStreak : 0,
    missions: economy ? economy.missions : [],
    missionResetAtMs: reset.resetAtMs,
    missionResetSeconds: reset.secondsUntilReset,
    missionResetTimezone: reset.timezone,
    shieldActive: shield.active,
    shieldMsLeft: shield.msLeft || 0,
    shieldUntil: shield.shieldUntil || 0,
    jetLockActive: !!(jetLock && jetLock.active),
    jetLockMsLeft: jetLock ? Number(jetLock.msLeft || 0) : 0,
    jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
    jetLockUntil: jetLock ? Number(jetLock.blockedUntil || 0) : 0,
    inventory,
  };
}

module.exports = { buildWalletPayload };
```

---

### Part G — Wire `registerMobileApi` in main server

Find where mobile API is registered (e.g. `server/index.js`). It **must** pass **`broadcast`** so app chat WebSocket works:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
```

If `registerMobileApi` is called **without** `broadcast`, app chat will not push live messages to phones.

Ensure these already exist (do not remove): `mobile-auth.js`, `tiktok-bridge.js`, `mobile-store.js` (optional).

---

### Part H — Legal / privacy website on y666suf.com

Create folder **`website/`** next to the server (or project root — match path in routes below).

1. **`website/privacy.html`** — full privacy policy (copy from Mac `nfg-crash/website/privacy.html` if available). Contact: `privacy@y666suf.com`. Last updated: 20 May 2026. Dark theme.

2. **`website/legal.html`** — Legal & compliance page:
   - Entertainment only — virtual points, no cash-out, no real-money gambling
   - Points & purchases — Apple IAP only if paid packs added later
   - Advertising — optional AdMob rewarded ads
   - TikTok — verify via live comment
   - Age 17+
   - Link to `/privacy`

3. **`website/index.html`** — short landing for NFG Crash companion app + links to Privacy and Legal.

In the **main Express app** (port 3847), add routes **without breaking `/api/*`**:

```javascript
const path = require("path");
const websiteDir = path.join(__dirname, "website"); // adjust path if website/ lives elsewhere

app.get("/privacy", (req, res) => res.sendFile(path.join(websiteDir, "privacy.html")));
app.get("/legal", (req, res) => res.sendFile(path.join(websiteDir, "legal.html")));
app.get("/", (req, res, next) => {
  if (req.path === "/" || req.path === "/index.html") {
    return res.sendFile(path.join(websiteDir, "index.html"));
  }
  next();
});
```

App Store Connect Privacy Policy URL: **https://y666suf.com/privacy**

---

### Part I — Restart and verify (PowerShell)

```powershell
# Restart your server (npm start or your usual command)

curl http://127.0.0.1:3847/api/mobile/status
curl http://127.0.0.1:3847/api/mobile/presence/active
curl -X POST http://127.0.0.1:3847/api/mobile/presence/heartbeat -H "X-Device-Id: test-device-1"
curl http://127.0.0.1:3847/api/mobile/chat?limit=5
curl http://127.0.0.1:3847/privacy
curl http://127.0.0.1:3847/legal
```

**Expect:**

| Check | Expected |
|-------|----------|
| `activeAppUsers` | number (≥ 0) |
| `activeAppUserList` | array with `userId`, `displayName`, `superFan` |
| `rewarded-ad/status` (with Bearer) | `"unlimited": true`, `"canClaim": true`, `"cooldownSecondsLeft": 0` |
| Chat POST | message object includes `superFan`, `superFanLevel` when user is Super Fan in game |
| `/privacy` | HTML page |

Then test in browser: `https://y666suf.com/privacy`

---

### Part J — Report back

Reply with:

1. List of files created/updated
2. Whether `registerMobileApi` passes `broadcast`
3. Sample JSON from `/api/mobile/status` (redact tokens)
4. Result of heartbeat + presence/active curl
5. Whether `/privacy` works locally and via `https://y666suf.com/privacy`
6. Any errors on server startup

---

## PROMPT END

---

After the agent finishes: **restart the game server** and test the iPhone app (App Chat online button, Super Fan badges, Watch ad for 10,000 pts).
