# Windows Cursor prompt — unlimited rewarded ads (NO cooldown)

Copy **everything below the line** into Cursor on your **Windows PC** (NFG Crash game server folder).

---

You are editing my **NFG Crash** Windows game server (Node/Express, port **3847**, public URL **https://y666suf.com** via Cloudflare tunnel).

The iPhone app uses **Wallet → “Watch ad for 10,000 pts”** (AdMob rewarded ad). After the user finishes the ad, the app calls:

- `GET /api/mobile/rewarded-ad/status`
- `POST /api/mobile/rewarded-ad/claim`

**Problem to fix:** Users see “Ad reward is on cooldown” or `canClaim: false` because the PC still runs an **old** `mobile-rewarded-ad.js` with **15-minute cooldown** and/or **5 ads per day**.

**Do not break:** TikTok bridge, bets, WebSocket, `!link`, `/api/mobile/me`, app chat, leaderboard, store routes if present.

---

## Required behaviour (new rules)

| Setting | Value |
|---------|--------|
| Points per ad | **10,000** |
| Daily limit | **None** (unlimited) |
| Cooldown | **None** (`COOLDOWN_MS = 0`) |
| Status JSON must include | `"unlimited": true`, `"maxClaimsPerDay": null`, `"canClaim": true`, `"cooldownSecondsLeft": 0` |

---

## Task 1 — REPLACE `server/mobile-rewarded-ad.js` entirely

Delete the old file content and use this **exact** file (or copy from Mac `nfg-crash/server/mobile-rewarded-ad.js`):

```javascript
/**
 * Rewarded video claims from the iOS app (watch ad → points on server).
 */
const fs = require("fs");
const path = require("path");
const { getAppRoot } = require("./paths");

const REWARD_AMOUNT = 10_000;
/** No cooldown between ad rewards — unlimited watches. */
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

**Confirm the file contains `COOLDOWN_MS = 0` and NOT `15 * 60 * 1000` or `MAX_CLAIMS_PER_DAY = 5`.**

---

## Task 2 — ENSURE `server/paths.js` exists

```javascript
const path = require("path");

function getAppRoot() {
  if (process.pkg) {
    return path.dirname(process.execPath);
  }
  return path.join(__dirname, "..");
}

module.exports = { getAppRoot };
```

---

## Task 3 — EDIT `server/mobile-api.js`

**Top of file:**

```javascript
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");
```

**Inside `registerMobileApi(app, ctx)`** (after auth/chat routes):

```javascript
registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
```

Remove any **duplicate** old rewarded-ad route handlers if they exist elsewhere.

---

## Task 4 — Restart the game server

Stop Node/Electron completely, then `npm start` (or restart the Electron app). A running process keeps the **old** code in memory.

---

## Task 5 — Verify (must pass)

```powershell
curl http://127.0.0.1:3847/api/mobile/status
```

With a real mobile Bearer token:

```powershell
curl -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/status
```

**PASS example:**

```json
{
  "ok": true,
  "rewardAmount": 10000,
  "unlimited": true,
  "maxClaimsPerDay": null,
  "canClaim": true,
  "cooldownSecondsLeft": 0,
  "reason": null
}
```

**FAIL (old code still running):**

- `"maxClaimsPerDay": 5`
- `"cooldownSecondsLeft": 450` (or any number > 0 right after a claim)
- `"reason": "daily_limit"` or `"cooldown"` when user should be allowed

**Claim test:**

```powershell
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/claim
```

Expect `"ok": true`, `"gained": 10000`. Run **twice in a row** — both should succeed (no 429 wait message).

---

## How to tell old vs new file is loaded

Search the running project for these strings:

| String | Meaning |
|--------|---------|
| `COOLDOWN_MS = 0` | ✅ New unlimited |
| `15 * 60 * 1000` | ❌ Old 15-min cooldown |
| `MAX_CLAIMS_PER_DAY = 5` | ❌ Old daily cap |

---

Return: files changed, whether old constants were found, and paste the JSON from the status curl.
