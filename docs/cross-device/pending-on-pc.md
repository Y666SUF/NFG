---
cross_device_status: pending
from_device: mac
target_device: pc
created_at: 2026-05-26T16:05:00Z
title: Fix display names + Vault Arcade mobile endpoints
related_paths:
 - server/mobile-api.js
 - server/index.js
 - server/store.js
 - server/game.js
 - server/mobile-store.js
 - server/mobile-cosmetics.js
 - server/mobile-wallet.js
 - server/mobile-auth.js
 - server/mobile-chat.js
 - server/mobile-presence.js
 - server/mobile-platform.js
---

# PC companion task: Fix display names + Vault Arcade endpoints

The latest iOS app expects these **mobile endpoints** on the Windows game server:

- **Display name settings**: `POST /api/mobile/profile/display-name`
- **Vault Arcade**:
  - `GET /api/mobile/arcade/catalog`
  - `POST /api/mobile/arcade/play`

Right now the iOS app shows errors like:
- “Display name settings are not on the game server yet. Copy mobile-profile.js to your PC and restart Node.”
- “Vault Arcade is not on the game server yet. Copy arcade files to your PC and restart Node.”

This is a **Windows server mismatch**, not an iOS issue.

## Do on Windows PC

### 1) Pull the correct branch in the *actual runtime folder*

Find the folder that the live process really runs from (the one with `server/index.js` it uses), then:

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
npm install
```

Or manually:

```powershell
git fetch origin
git checkout main
git pull origin main
npm install
```

### 2) Add missing server modules (if not already present after pull)

Check if these files exist on the PC in `server/`:

- `server/mobile-profile.js`
- `server/mobile-arcade.js`

If they’re missing, create them exactly as below.

#### Create `server/mobile-profile.js`

```js
const { buildWalletPayload } = require("./mobile-wallet");

function registerMobileProfileRoutes(app, ctx) {
  const { validateBearer, pointStore, game } = ctx;

  app.post("/api/mobile/profile/display-name", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const displayName = String((req.body && req.body.displayName) || "").trim();
    if (!displayName) return res.status(400).json({ ok: false, reason: "invalid_display_name", message: "Enter a display name." });

    // Server-side storage. store.js implements setDisplayName().
    try {
      pointStore.setDisplayName(session.userId, displayName);
    } catch (e) {
      return res.status(400).json({ ok: false, reason: "invalid_display_name", message: "This display name is not allowed." });
    }

    return res.json({ ok: true, wallet: buildWalletPayload(session.userId, pointStore, game) });
  });
}

module.exports = { registerMobileProfileRoutes };
```

#### Create `server/mobile-arcade.js` (minimal endpoints so iOS works)

```js
function registerMobileArcadeRoutes(app, ctx) {
  const { validateBearer, pointStore } = ctx;

  app.get("/api/mobile/arcade/catalog", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    // iOS merges server games with a bundled catalog, so games can be empty.
    const balance = pointStore.getBalance(session.userId);
    return res.json({
      ok: true,
      earnedToday: 0,
      earnCap: 150000,
      earnLeft: 150000,
      liveBonusMultiplier: 1.25,
      isLive: false,
      funPoints: 0,
      balance,
      games: [],
      missions: [],
      season: { weekKey: "", points: 0, rank: 0, totalPlayers: 0 },
    });
  });

  app.post("/api/mobile/arcade/play", (req, res) => {
    const session = validateBearer(req);
    if (!session) return res.status(401).json({ ok: false, error: "auth_required" });

    const body = req.body && typeof req.body === "object" ? req.body : {};
    const gameId = String(body.gameId || "").trim();
    const action = String(body.action || "status").trim();
    if (!gameId) return res.status(400).json({ ok: false, reason: "invalid_game", message: "Missing gameId." });

    // Minimal response: acknowledges play but does not award points yet.
    const balance = pointStore.getBalance(session.userId);
    return res.json({
      ok: true,
      game: gameId,
      gained: 0,
      balance,
      playsPerDay: 5,
      playsLeft: 5,
      skillLevel: 1,
      maxSkillLevel: 10,
      message: action === "status" ? "OK" : "OK",
    });
  });
}

module.exports = { registerMobileArcadeRoutes };
```

### 3) Wire these routes into `server/mobile-api.js`

Open `server/mobile-api.js` and add:

```js
const { registerMobileProfileRoutes } = require("./mobile-profile");
const { registerMobileArcadeRoutes } = require("./mobile-arcade");
```

Then inside `registerMobileApi(app, ctx)` add:

```js
registerMobileProfileRoutes(app, { validateBearer, pointStore, game });
registerMobileArcadeRoutes(app, { validateBearer, pointStore, game, broadcast });
registerTikTokAvatarRoutes(app, { validateBearer });
```

(`tiktok-profile-avatar.js` should already exist; wire it if Jump profile pics fail.)

### 4) Restart the live server process

Restart the real production runner (pm2 / node / `run-electron-cloudflare.bat` / your launcher). Do **not** start a second copy.

### 5) Verify from production

```powershell
curl https://y666suf.com/api/mobile/me
curl https://y666suf.com/api/mobile/arcade/catalog
```

From iOS:
- Change display name → should save and reflect in wallet/profile and show in chat/entries.
- Open Vault Arcade → should load without the “copy arcade files” error.

## When done

1) Set frontmatter `cross_device_status: done`  
2) Push via your usual Windows sync script (`scripts/sync-push.ps1`) with a short message like:
   - “Server: add mobile profile + arcade endpoints”

