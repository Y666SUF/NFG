# Windows Cursor — FULL PC setup (GitHub + Crash + Hangman + iOS apps)

Copy **PROMPT START** through **PROMPT END** into a **new Cursor Agent chat** on your **Windows PC**.

Public repo: **https://github.com/Y666SUF/NFG**

---

## PROMPT START

You are setting up my **Windows PC** so everything works together:

- **TikTok LIVE** games: **Crash** + **Hangman** (same machine, port **3847**)
- **Cloudflare tunnel** → **https://y666suf.com**
- **NFG Crash** iOS app (`com.nfg.crash`) — native, built on Mac
- **NFG Hangman** iOS app (`com.nfg.hangman`) — Capacitor, built on Mac
- **Shared** app chat, presence (“X in apps”), TikTok `!link`, Super Fan badges
- **Legal website** for App Store: `/privacy`, `/legal`

**Do not break:** existing TikTok bridge, Hangman letter/guess rules (6 wrong = out), Crash bets, `points.live.json`, Electron main window.

---

## Part 0 — Sync code from GitHub (do this first)

### 0A. Clone or pull the public repo

If you do **not** have the repo yet:

```powershell
cd $HOME\Documents
git clone https://github.com/Y666SUF/NFG.git
cd NFG
```

If you already cloned:

```powershell
cd $HOME\Documents\NFG
git pull origin main
```

This repo contains:

| Path | Use on PC |
|------|-----------|
| `server/mobile-*.js` | Copy into your **live game** `server\` folder |
| `server/mobile-api.js` | Register all mobile routes |
| `website/` | Host on y666suf.com |
| `hangman-v2/` | Reference only (app built on Mac) |
| `ios/` | Reference only (Crash built on Mac) |
| `WINDOWS-*.md` | Extra prompts |

### 0B. Find your **live** game project folder

Locate where you currently run `npm start` (Hangman and/or Crash), e.g.:

- `hangman v2\` or `tiktok-live-crash-game\` on the PC

Call this **`GAME_ROOT`**. The repo clone (`Documents\NFG`) is the **sync source**; **`GAME_ROOT`** is what actually runs on port 3847.

### 0C. Copy server mobile files from repo → live game

```powershell
$REPO = "$HOME\Documents\NFG"
$GAME = "C:\path\to\your\GAME_ROOT"   # <-- CHANGE THIS

Copy-Item "$REPO\server\mobile-auth.js"        "$GAME\server\" -Force -ErrorAction SilentlyContinue
Copy-Item "$REPO\server\mobile-chat.js"        "$GAME\server\" -Force
Copy-Item "$REPO\server\mobile-presence.js"    "$GAME\server\" -Force
Copy-Item "$REPO\server\mobile-player-badges.js" "$GAME\server\" -Force
Copy-Item "$REPO\server\mobile-rewarded-ad.js" "$GAME\server\" -Force
Copy-Item "$REPO\server\mobile-wallet.js"     "$GAME\server\" -Force
Copy-Item "$REPO\server\mobile-api.js"        "$GAME\server\" -Force
```

If `mobile-auth.js` or `tiktok-bridge.js` already exist in `GAME_ROOT\server\`, **merge carefully** — do not delete Hangman-specific logic.

After every Mac `git push`, run `git pull` in `Documents\NFG` and re-copy these files (or run the game directly from the repo if layout matches).

---

## Part 1 — Register mobile API in `server/index.js`

In **`GAME_ROOT\server\index.js`** (or main entry):

1. Ensure `broadcast` function exists and is passed to mobile registration (same WebSocket clients as the game UI).

2. Register mobile API:

```javascript
const { registerMobileApi } = require("./mobile-api");

// After express app + pointStore + game exist:
registerMobileApi(app, {
  game,
  pointStore,
  isLocalhost,
  broadcast,   // REQUIRED for app chat + live messages
});
```

3. Confirm **`npm start`** still listens on port **3847**.

---

## Part 2 — Hangman iOS companion (wire to EXISTING game logic)

The Hangman app calls your server — it does **not** change rules. Find how TikTok chat already handles **letter guesses** / hangman (6 wrong = out). The mobile route must call **that same code**.

### 2A. Create `server/mobile-hangman.js` (or equivalent)

Implement:

**`POST /api/mobile/hangman/guess`**

- Headers: `Authorization: Bearer`, `X-Device-Id`, `X-Client-App: nfg-hangman`
- Body: `{ "letter": "a" }` (one letter, lowercase ok)
- `validateBearer(req)` → get `session.userId`
- Call **existing** internal function used when a viewer guesses a letter on TikTok (same outcome as chat)
- Return JSON:

```json
{
  "ok": true,
  "masked": "_ A _ _",
  "wrong": 2,
  "maxWrong": 6,
  "guessed": ["a", "e"],
  "correct": true,
  "eliminated": false,
  "won": false
}
```

**`GET /api/hangman/leaderboard`**

- Return Hangman **all-time** wins/scores (NOT Crash `/api/balances` leaderboard).

Register these routes inside `registerMobileApi` or require `mobile-hangman.js` from `mobile-api.js`.

### 2B. WebSocket ` /hangman/ws `

Path: **`wss://y666suf.com/hangman/ws`** (HTTPS → WSS on same host).

When hangman round state changes (same events TikTok UI sees), broadcast:

```javascript
broadcast({ type: "update", payload: { masked, wrong, maxWrong: 6, guessed, eliminated, won, ... } });
```

When all-time board changes:

```javascript
broadcast({ type: "alltime", payload: { rows: [ { user, displayName, wins }, ... ] } });
```

Use a **dedicated** WebSocketServer on path `/hangman/ws` OR route upgrades in existing HTTP server — match how the project already does WS.

### 2C. Platform status (Crash + Hangman apps)

**`GET /api/mobile/platform/status`**

Return:

```json
{
  "ok": true,
  "tiktokLive": { "enabled": true, "uniqueId": "y666.suf", "state": "live", "isLive": true },
  "activeAppUsers": 2,
  "activeAppUserList": [
    { "userId": "y666.suf", "displayName": "...", "superFan": true, "superFanLevel": 3, "isGuest": false }
  ]
}
```

Use `getTikTokBridgeStatus()` + `getActiveAppUserList(pointStore)` from `mobile-presence.js` (already in repo `server/mobile-api.js` pattern — extend or duplicate for platform route).

### 2D. Platform WebSocket (shared)

On the **main** game WebSocket (`wss://y666suf.com`), also broadcast:

- `{ type: "app_chat", payload: { id, userId, displayName, message, at, superFan, superFanLevel } }` — from `mobile-chat.js`
- `{ type: "presence_update", payload: { activeAppUsers, activeAppUserList } }` — after heartbeats

---

## Part 3 — Crash + shared mobile (from repo — verify)

These files are in **`NFG/server/`** on GitHub. After copy, confirm:

| Feature | Endpoints |
|---------|-----------|
| TikTok link | `POST /api/mobile/link/start`, `GET /api/mobile/link/status/:code` |
| Wallet | `GET /api/mobile/me` |
| Crash status | `GET /api/mobile/status` (+ `activeAppUsers`, `activeAppUserList`) |
| Presence | `POST /api/mobile/presence/heartbeat`, `GET /api/mobile/presence/active` |
| Chat | `GET/POST /api/mobile/chat` (no `!` commands in app) |
| Rewarded ads | `GET/POST /api/mobile/rewarded-ad/*` — **10k pts, unlimited, COOLDOWN_MS = 0** |
| Super Fan in chat | `mobile-player-badges.js` + `pointStore.getUserPresentation` |

**`mobile-api.js` from repo** must include:

```javascript
registerMobileChatRoutes(app, { broadcast, validateBearer, pointStore });
registerMobilePresenceRoutes(app, { validateBearer, pointStore });
```

And in `GET /api/mobile/status`:

```javascript
activeAppUsers: getActiveAppUserCount(),
activeAppUserList: getActiveAppUserList(pointStore),
```

---

## Part 4 — Legal / privacy website (y666suf.com)

From repo **`website/`**:

1. Copy `website\` folder next to your Express app (or into `GAME_ROOT\website`).

2. In main server (port 3847), add:

```javascript
const path = require("path");
const websiteDir = path.join(__dirname, "..", "website");

app.get("/privacy", (req, res) => res.sendFile(path.join(websiteDir, "privacy.html")));
app.get("/legal", (req, res) => res.sendFile(path.join(websiteDir, "legal.html")));
app.get("/", (req, res, next) => {
  if (req.path === "/" || req.path === "/index.html")
    return res.sendFile(path.join(websiteDir, "index.html"));
  next();
});
```

3. Create **`website/index.html`** and **`website/legal.html`** if missing (dark theme, links to privacy, entertainment-only, virtual points, 17+/13+).

4. Verify: `https://y666suf.com/privacy` and `/legal` in browser.

5. Optional: serve **`NFG-Hangman.ipa`** at `/download/nfg-hangman.ipa` for sideload page ` /sideload#hangman `.

---

## Part 5 — Cloudflare tunnel

Confirm tunnel routes **y666suf.com** → `http://127.0.0.1:3847` (this PC).

Restart tunnel after server changes. Test from phone on cellular (not Wi‑Fi only).

---

## Part 6 — Restart & verify (PowerShell)

```powershell
cd $GAME\server   # or GAME_ROOT
# stop old node, then:
npm start
```

```powershell
curl http://127.0.0.1:3847/api/mobile/platform/status
curl http://127.0.0.1:3847/api/mobile/status
curl http://127.0.0.1:3847/api/hangman/leaderboard
curl http://127.0.0.1:3847/api/mobile/presence/active
curl -X POST http://127.0.0.1:3847/api/mobile/presence/heartbeat -H "X-Device-Id: pc-test-1"
curl http://127.0.0.1:3847/privacy
```

Then HTTPS:

```powershell
curl https://y666suf.com/api/mobile/platform/status
```

---

## Part 7 — Test with phones (Mac builds apps)

| App | Bundle ID | Test |
|-----|-----------|------|
| NFG Crash | com.nfg.crash | Link on LIVE, bet, chat, in-app count, watch ad 10k |
| NFG Hangman | com.nfg.hangman | Link, Play keyboard guess, Board, Chat |

TikTok: **@y666.suf** must be LIVE on this PC for linking.

---

## Part 8 — Ongoing sync with MacBook

```powershell
cd $HOME\Documents\NFG
git pull
# Re-copy server\*.js to GAME_ROOT\server\ if needed
# Restart npm start
```

Mac pushes to **https://github.com/Y666SUF/NFG** → PC pulls → copy → restart.

---

## Part 9 — Report back

Reply with:

1. `GAME_ROOT` path you used  
2. List of files created/updated  
3. How Hangman mobile guess connects to existing TikTok logic (function name)  
4. Sample JSON from `/api/mobile/platform/status` and `/api/hangman/leaderboard`  
5. Whether `https://y666suf.com/privacy` works  
6. Any errors on startup  

---

## PROMPT END

After the agent finishes: restart game server + Cloudflare tunnel, then test both iPhone apps against **https://y666suf.com**.
