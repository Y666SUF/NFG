# Windows Cursor prompt — rewarded ads (+10,000 pts)

Copy everything below the line into **Cursor on your Windows PC** (open your NFG Crash game server project folder).

---

You are editing my **NFG Crash** Windows game server (Node/Express, port **3847**). The iPhone app already shows a real **AdMob rewarded ad** on the **Wallet → “Watch ad for 10,000 pts”** button. After the user finishes the ad, the app calls your server to grant points.

**Do not break:** TikTok bridge, bets, WebSocket, mobile `!link`, `/api/mobile/me`, app chat, leaderboard, Cloudflare tunnel to **https://y666suf.com**.

## Goal

Add server endpoints so rewarded ads work end-to-end:

| Method | Path | Auth |
|--------|------|------|
| `GET` | `/api/mobile/rewarded-ad/status` | Bearer |
| `POST` | `/api/mobile/rewarded-ad/claim` | Bearer |

**Rules:** 10,000 pts per claim, **unlimited** per day (no daily cap, **no cooldown**). Store claims in `data/mobile-ad-claims.json` for stats only. Use `pointStore.credit()` so points match TikTok live.

## Tasks

### 1. CREATE `server/mobile-rewarded-ad.js`

Create this file in the `server/` folder (same level as `mobile-api.js`). Use the Mac reference from the repo if the user has it, or create with this exact logic:

- `REWARD_AMOUNT = 10000`, `COOLDOWN_MS = 0` (unlimited watches)
- `CLAIMS_FILE = path.join(getAppRoot(), "data", "mobile-ad-claims.json")`
- `registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast })`
- `GET /api/mobile/rewarded-ad/status` → `{ ok: true, rewardAmount, claimsToday, maxClaimsPerDay, cooldownSecondsLeft, canClaim, reason, nextClaimAt }`
- `POST /api/mobile/rewarded-ad/claim` → validate `canClaim`, then `pointStore.ensureAccount(user)`, `pointStore.credit(user, REWARD_AMOUNT, { countAsEarned: true })`, record claim, optional `broadcast({ type: "balance_toast", payload: { user, balance, gained, source: "rewarded_ad" } })`, return `{ ok: true, gained, balance, ... }`
- `401` if no Bearer session; `429` if daily limit or cooldown

Requires `const { getAppRoot } = require("./paths");` — if `paths.js` is missing, create it (see task 2).

### 2. ENSURE `server/paths.js` exists

If missing, create:

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

### 3. EDIT `server/mobile-api.js`

At top with other requires:

```javascript
const { registerMobileRewardedAdRoutes } = require("./mobile-rewarded-ad");
```

Inside `registerMobileApi(app, ctx)`, after chat/auth routes (where `pointStore` and `validateBearer` exist):

```javascript
registerMobileRewardedAdRoutes(app, { pointStore, validateBearer, broadcast });
```

### 4. Restart server

After changes: stop and `npm start` (or restart your Electron app).

## Verify on PC

```powershell
curl http://127.0.0.1:3847/api/mobile/status
```

Should still return `"ok": true`.

With a valid mobile Bearer token (from a linked phone):

```powershell
curl -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/status
```

Expect `"ok": true`, `"rewardAmount": 10000`, `"canClaim": true` (or cooldown/daily_limit).

```powershell
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" http://127.0.0.1:3847/api/mobile/rewarded-ad/claim
```

Expect `"ok": true`, `"gained": 10000`, and updated `"balance"`.

Without token → `401`. Claim twice within 15 min → second should be `429`.

## iOS app (already done on Mac — no server change needed)

- **Wallet** icon → **Free points** → button **“Watch ad for 10,000 pts”**
- Flow: tap → **Google AdMob rewarded ad** (unit `ca-app-pub-6359780264957734/1707833917`) → on complete → `POST /api/mobile/rewarded-ad/claim` → +10,000 pts

If claim returns **404**, these server routes are not deployed yet.

## Optional (same session)

If `mobile-presence.js` is not on Windows yet, also add active “in app” user count per `WINDOWS-UPDATE-APP-PRESENCE.md`.

Return a short summary of files created/edited and curl results.
