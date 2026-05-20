# Windows Cursor prompt — wallet + app chat (copy below)

Open your **tiktok-live-crash-game** folder in Cursor → **new Agent chat** → paste **PROMPT START** through **PROMPT END**.

The iPhone app now has **My Wallet** (balance + inventory) and **App Chat**. Your PC server must expose these APIs or the app will show errors.

---

## PROMPT START

You are editing my **NFG Crash** Windows game server (Node.js, port **3847**). The **iOS app** already calls these endpoints — add them without breaking TikTok bridge, bets, WebSocket, mobile link (`!link`), LIVE status, or full leaderboard.

TikTok account: **@y666.suf**

### 1. CREATE `server/mobile-wallet.js`

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

### 2. CREATE `server/mobile-chat.js`

```javascript
/**
 * In-app chat between mobile players (separate from TikTok !commands).
 * Messages broadcast over WebSocket and logged to the server console (Electron inherits stdio).
 */
const crypto = require("crypto");

const MAX_MESSAGES = 120;
const MAX_MESSAGE_LEN = 240;
const RATE_LIMIT_MS = 1200;

/** @type {Array<{ id: string, userId: string, displayName: string, message: string, at: number }>} */
const messages = [];
/** @type {Map<string, number>} */
const lastSentAt = new Map();

function listMessages(limit = 50) {
  const n = Math.min(MAX_MESSAGES, Math.max(1, Math.floor(Number(limit) || 50)));
  return messages.slice(-n);
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

    const line = `[App chat] ${row.displayName} (@${row.userId}): ${row.message}`;
    console.log(line);

    broadcast({ type: "app_chat", payload: row });
    res.json({ ok: true, message: row });
  });
}

module.exports = { registerMobileChatRoutes, listMessages };
```

When you run the game via **Electron**, `server/index.js` uses `stdio: "inherit"` — these `console.log` lines appear in the **same terminal/console window** as the Electron app.

### 3. EDIT `server/mobile-api.js`

At the top, add requires:

```javascript
const { registerMobileAuthRoutes, validateBearer } = require("./mobile-auth");
const { registerMobileChatRoutes } = require("./mobile-chat");
const { buildWalletPayload } = require("./mobile-wallet");
```

(Keep existing `getTikTokBridgeStatus` require.)

In `registerMobileApi(app, ctx)`:

- Destructure `broadcast` from `ctx`: `const { game, pointStore, isLocalhost, broadcast } = ctx;`
- Right after `registerMobileAuthRoutes`, add:

```javascript
  if (typeof broadcast === "function") {
    registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
  }
```

Before the closing `}` of `registerMobileApi`, add:

```javascript
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
```

Export: `module.exports = { registerMobileApi, buildWalletPayload };`

### 4. EDIT `server/index.js`

Find:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost });
```

Change to:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
```

(`broadcast` is the existing WebSocket broadcast function defined above in the same file.)

### 5. Verify

After `npm start` (or opening Electron):

```powershell
curl http://127.0.0.1:3847/api/mobile/status
curl http://127.0.0.1:3847/api/mobile/chat
```

Second call should return `{ "ok": true, "messages": [] }`.

Send a test chat from the iPhone app — the PC console should show:

`[App chat] DisplayName (@username): hello`

Do **not** remove or rename existing mobile link routes.

## PROMPT END

---

## What the iPhone app uses

| Feature | API | Notes |
|--------|-----|--------|
| Wallet | `GET /api/mobile/me` | Bearer token — balance, shield, jet lock, inventory |
| Chat history | `GET /api/mobile/chat?limit=60` | No auth required |
| Send chat | `POST /api/mobile/chat` | Bearer — broadcasts `app_chat` on WebSocket |
| PC console | `console.log` in `mobile-chat.js` | Shows in Electron terminal |

Toolbar: **wallet icon** and **chat bubbles** in the top bar when linked.
