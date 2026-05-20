# Windows Cursor prompt — full iOS sync + Electron (copy below)

Open **tiktok-live-crash-game** in Cursor → **new Agent chat** → paste **PROMPT START** through **PROMPT END**.

The iPhone app is **hardcoded** to: **`http://86.22.165.214:3847`** (no server URL in the app UI). If sync fails, the Windows server is missing mobile API files, not listening on `0.0.0.0`, or port **3847** is blocked.

TikTok: **@y666.suf**

---

## PROMPT START

You are editing my **NFG Crash** Windows game (Node.js **3847**, Electron in `electron/main.js`). The **iPhone app** must sync with the **same** `data/points.live.json`, WebSocket state, bets, wallet, and app chat as this PC.

**Do not** create a second server on another port. **Do not** break TikTok bridge, crash game, gifts, or existing web UI.

### iPhone expects these endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /api/state` | Game snapshot |
| WebSocket `/` | Live `state`, `app_chat`, `chat_result` |
| `GET /api/mobile/status` | Connection + `tiktokLive` |
| `POST /api/mobile/link/start` | Link code |
| `GET /api/mobile/link/status/:code` | Poll link |
| `POST /api/chat` + `source:"mobile"` + Bearer | Bets / commands |
| `GET /api/mobile/me` | Wallet + inventory |
| `GET /api/mobile/chat` | App chat history |
| `POST /api/mobile/chat` | Send app chat |
| `GET /api/economy/profile/:user` | Profile |
| `GET /api/balances?limit=all` | Full leaderboard |
| `GET /api/economy/lookup/:user` | (optional; wallet uses `/mobile/me`) |

---

## PART 1 — Server files (create if missing)

### 1A. `server/mobile-auth.js`

Create full mobile auth module with:
- `POST /api/mobile/link/start`, `GET /api/mobile/link/status/:code`, `GET /api/mobile/session`, `POST /api/mobile/session/logout`
- `GET /api/mobile/link/debug` (localhost only)
- `completeLinkFromTikTok(userId, displayName, message)` — parse `!link CODE`, create session token
- `validateBearer(req)` — return session from `Authorization: Bearer`
- Persist sessions in `data/mobile-sessions.json`

If this file is missing, implement it matching standard NFG mobile-auth (link TTL 10 min, session TTL 90 days, 6-char hex codes).

### 1B. `server/mobile-wallet.js`

```javascript
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
    level: view.level,
    rank: view.rank,
    balance: pointStore.getBalance(user),
    allTime: pointStore.getAllTime(user),
    shieldActive: shield.active,
    shieldMsLeft: shield.msLeft || 0,
    jetLockActive: !!(jetLock && jetLock.active),
    jetLockSecondsLeft: jetLock ? Number(jetLock.secondsLeft || 0) : 0,
    inventory,
  };
}
module.exports = { buildWalletPayload };
```

### 1C. `server/mobile-chat.js`

Create with:
- `GET /api/mobile/chat?limit=N` → `{ ok, messages }`
- `POST /api/mobile/chat` (Bearer) — no `!` commands, rate limit ~1.2s
- `console.log('[App chat] Name (@user): message')`
- `broadcast({ type: 'app_chat', payload: { id, userId, displayName, message, at } })`

### 1D. `server/mobile-api.js`

- Require `./mobile-auth`, `./mobile-chat`, `./mobile-wallet`, `./tiktok-bridge`
- `registerMobileApi(app, { game, pointStore, isLocalhost, broadcast })`
- Call `registerMobileAuthRoutes`, `registerMobileChatRoutes` when `broadcast` is a function
- `GET /api/mobile/status` — include `tiktokLive` from `getTikTokBridgeStatus()` with `isLive: state === 'live'`
- `GET /api/mobile/me` — Bearer → `buildWalletPayload(session.userId, ...)`

### 1E. EDIT `server/index.js`

**Requires (top):**
```javascript
const { registerMobileApi } = require("./mobile-api");
const { completeLinkFromTikTok, validateBearer } = require("./mobile-auth");
```

**After `broadcast` function exists, register mobile API:**
```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
```

**In `POST /api/chat`**, at the start (after parsing body):
```javascript
const isMobile = source === "mobile";
if (isMobile) {
  const session = validateBearer(req);
  if (!session) {
    return res.status(401).json({
      ok: false,
      error: "auth_required",
      message: "Link your TikTok account on live first (!link code), or session expired.",
    });
  }
  req.body = {
    ...req.body,
    userId: session.userId,
    user: session.userId,
    displayName: session.displayName || displayName,
  };
}
```

**Before `game.parseChatMessage`**, for non-mobile only:
```javascript
if (!isMobile && user && message) {
  const link = completeLinkFromTikTok(user, displayName, message);
  if (link.handled) {
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

**`GET /api/balances`** — support `?limit=all`:
```javascript
if (rawLimit === "all" || rawLimit === "0") limit = 999999;
// response: { balances: rows, total, shown: rows.length }
```

**Listen on all interfaces** — end of file:
```javascript
const HOST = process.env.HOST || "0.0.0.0";
server.listen(PORT, HOST, () => {
  // print 127.0.0.1, LAN IPs, and fetch https://api.ipify.org to print public URL for iPhone
  // remind: router must forward TCP 3847 to this PC
  // iPhone app uses http://86.22.165.214:3847
});
```

Move `isLocalhost` function **above** `registerMobileApi` if needed.

### 1F. EDIT `server/tiktok-bridge.js`

Expose bridge status for mobile (if not already):
- `bridgeStatus` object, `setBridgeStatus()`, `getTikTokBridgeStatus()`
- Set `state` to `live` / `waiting` / `offline` / `disabled` when bridge connects/disconnects

---

## PART 2 — Electron + App Chat window

### 2A. CREATE `public/app-chat.html`

Page that:
- `fetch('/api/mobile/chat?limit=80')` on load
- WebSocket to `ws://` + `location.host`, handle `{ type: 'app_chat', payload }`
- Dark UI, show displayName, @userId, message, time

### 2B. EDIT `electron/main.js`

On startup, open **3 windows**:
1. Main game (`/` or `portrait.html`)
2. Player Lookup (`player-lookup.html`) — if you already have this
3. **App Chat** (`app-chat.html`) — title `"NFG Crash - App Chat"`

Add `let chatWindow = null`, create BrowserWindow after lookup window, `loadURL(\`${ROOT_URL}app-chat.html\`)`, position beside lookup, close when main closes.

Server must use `stdio: "inherit"` when spawning `server/index.js` so `[App chat]` lines appear in the Electron console.

---

## PART 3 — Windows network (critical for iPhone)

Create **`scripts/windows-firewall-3847.bat`**:
```bat
@echo off
netsh advfirewall firewall add rule name="NFG Crash 3847" dir=in action=allow protocol=TCP localport=3847
echo Done. Port 3847 allowed inbound.
pause
```
(Run as Administrator)

**Router:** Forward external **TCP 3847** → this PC's LAN IP (from `ipconfig`).

**Public IP** must be **86.22.165.214** (verify at https://api.ipify.org on the PC). If different, tell the user to update the iPhone build — app is hardcoded to `.214`.

---

## PART 4 — Verify (run after changes)

Restart game/Electron, then PowerShell:

```powershell
curl http://127.0.0.1:3847/api/mobile/status
curl http://127.0.0.1:3847/api/mobile/chat
curl -X POST http://127.0.0.1:3847/api/mobile/link/start -H "Content-Type: application/json" -d "{\"deviceId\":\"test\"}"
curl "http://127.0.0.1:3847/api/balances?limit=all"
```

From another device on the internet (or phone on 4G), if port forward works:
```powershell
curl http://86.22.165.214:3847/api/mobile/status
```
Must return JSON with `"ok":true` — not timeout.

**Electron:** Three windows open; App Chat shows green "Live" when WebSocket connects.

---

## PART 5 — Do NOT

- Remove or rename existing TikTok bridge hooks
- Accept `!link` from `source: "mobile"`
- Listen only on `127.0.0.1` (must be `0.0.0.0` for remote iPhone)
- Change WebSocket `state` payload shape

## PROMPT END

---

## After Cursor finishes

1. Run **`scripts\windows-firewall-3847.bat`** as Admin  
2. Confirm router port forward **3847** → PC  
3. Start **Electron** (or `npm start`) — leave running while streaming  
4. On iPhone: force-quit **NFG Crash**, reopen, link TikTok on live if needed  
5. If still offline: on PC run `curl http://86.22.165.214:3847/api/mobile/status` from phone hotspot browser or ask someone external to test
