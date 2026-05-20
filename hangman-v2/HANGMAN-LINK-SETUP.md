# Link NFG Hangman app ↔ your PC Hangman game

The phone app does **not** talk to your PC directly. It talks to **https://y666suf.com**, which your **Cloudflare tunnel** sends to the **same Node server** that runs your TikTok Hangman game on the PC.

```text
iPhone (NFG Hangman app)
    → https://y666suf.com / wss://y666suf.com
        → Cloudflare tunnel
            → Windows PC :3847 (your existing game server)
```

If that chain is broken, the app will show errors, empty board, or “offline”.

---

## Part 1 — On your Windows PC (game server)

Your **existing** Hangman project (often `hangman v2` or `tiktok-live-crash-game` on the PC) must expose the routes the app calls. The app **does not** change guess rules — it only calls your server.

### Step 1: Copy shared mobile files from Mac `nfg-crash`

Copy into your PC server `server/` folder (same place as `index.js`):

| From Mac `nfg-crash/server/` | Purpose |
|------------------------------|---------|
| `mobile-auth.js` | TikTok `!link` + Bearer sessions |
| `mobile-chat.js` | App chat (shared with Crash) |
| `mobile-presence.js` | “X in apps” + online list |
| `mobile-player-badges.js` | Super Fan badges in chat |
| `mobile-wallet.js` | Optional; link uses auth |
| `mobile-api.js` | Wires routes (edit — see below) |

Also apply the **Crash** updates you may already have: `mobile-rewarded-ad.js` (only if you use ads in Hangman — optional).

Use the all-in-one Windows prompt:  
`/Users/y666suf/Documents/nfg-crash/WINDOWS-CURSOR-FULL-IOS-SERVER-UPDATE.md`

### Step 2: Add Hangman-only routes (wire to your game)

Your PC codebase already handles letters in **TikTok chat** (6 wrong = out). Add thin **mobile** wrappers that call the **same** functions.

**A. `POST /api/mobile/hangman/guess`**

- Headers: `Authorization: Bearer <token>`, `X-Device-Id`, `X-Client-App: nfg-hangman`
- Body: `{ "letter": "a" }`
- Inside handler: resolve user from `validateBearer(req)` → call existing hangman guess logic (same as chat `!guess` or letter handler)
- Response JSON example:

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

**B. `GET /api/hangman/leaderboard`**

- Return Hangman all-time wins/scores (not Crash crash leaderboard).

**C. WebSocket `wss://y666suf.com/hangman/ws`**

- Broadcast `{ "type": "update", "payload": { masked, wrong, guessed, ... } }` when the round changes (same state TikTok viewers see).
- Broadcast `{ "type": "alltime", "payload": { rows: [...] } }` when leaderboard changes.

**D. `GET /api/mobile/platform/status`**

- Same idea as Crash `/api/mobile/status` but cross-app:
  - `tiktokLive` (from TikTok bridge)
  - `activeAppUsers` + `activeAppUserList` (from `mobile-presence.js`)

**E. Platform WebSocket** (main game WS on port 3847)

- Already used by Crash: broadcast `app_chat` and `presence_update` on the **root** `wss://y666suf.com` connection.

### Step 3: Register mobile API in `server/index.js`

Must match Crash pattern:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
```

`broadcast` is required so chat and presence reach phones.

### Step 4: Cloudflare tunnel

Tunnel must point **y666suf.com** → `http://127.0.0.1:3847` (or whatever port your Hangman server uses). Same tunnel as Crash if both run on one process.

### Step 5: Restart and test on PC

```powershell
curl http://127.0.0.1:3847/api/mobile/platform/status
curl http://127.0.0.1:3847/api/hangman/leaderboard
curl -X POST http://127.0.0.1:3847/api/mobile/presence/heartbeat -H "X-Device-Id: test-hangman-1"
```

Then in browser: `https://y666suf.com/api/mobile/platform/status`

---

## Part 2 — On your Mac (Hangman iOS app)

Project path: **`/Users/y666suf/Documents/hangman v2/iOS/app/`**

### Step 1: Production env (already set)

`.env` should contain only:

```
VITE_NFG_API_BASE=https://y666suf.com
VITE_HANGMAN_WS_PATH=/hangman/ws
```

No `localhost` for real device builds.

### Step 2: Build and run on phone

```bash
cd "/Users/y666suf/Documents/hangman v2/iOS/app"
npm install
npm run build
npx cap sync ios
npx cap open ios
```

Run on a **physical iPhone** (or TestFlight). Simulator works if it can reach `y666suf.com`.

### Step 3: Link TikTok (Account tab)

1. Start **@y666.suf** LIVE on the PC game.
2. On phone: **Account → Link TikTok**.
3. Post the shown command (e.g. `!link …`) from **your** TikTok account on the live stream.
4. When linked, **Play** and **Chat** unlock.

### Step 4: Verify each tab

| Tab | Works when |
|-----|------------|
| Play | `POST /api/mobile/hangman/guess` + WS `update` |
| Board | `/api/hangman/leaderboard` or WS `alltime` |
| Chat | `/api/mobile/chat` + WS `app_chat` |
| Top bar | `/api/mobile/platform/status` + presence |

---

## Part 3 — Keep Mac and PC in sync

| What | Mac | Windows PC |
|------|-----|------------|
| iOS app source | `hangman v2/iOS/app/` | Copy folder or use Git |
| Server mobile modules | `nfg-crash/server/*.js` | Paste into PC `server/` |
| Hangman game logic | — | Stays on PC only |
| Tunnel + domain | — | Cloudflare on PC |

Recommended: one **Git repo** or sync `hangman v2` + `nfg-crash/server` mobile files to the PC after each change.

---

## Common problems

| Symptom | Fix |
|---------|-----|
| App can’t link | PC missing `mobile-auth.js` / link routes; not LIVE |
| Play does nothing | No `POST /api/mobile/hangman/guess` or not linked |
| Board empty | No `/api/hangman/leaderboard` or wrong data shape |
| Chat empty | No `mobile-chat.js` or `broadcast` not passed |
| “0 in apps” | No `mobile-presence.js` on PC / server not restarted |
| Works on PC curl, not on phone | Tunnel or HTTPS; check `https://y666suf.com/...` |

---

## One Windows Cursor prompt

Paste **`WINDOWS-CURSOR-FULL-IOS-SERVER-UPDATE.md`** from `nfg-crash` for shared mobile APIs, then add in the same chat:

> Also wire Hangman mobile: `POST /api/mobile/hangman/guess` (header `X-Client-App: nfg-hangman`) calling existing TikTok letter/guess logic; `GET /api/hangman/leaderboard`; WebSocket `/hangman/ws` with `type: update` and `alltime`; `GET /api/mobile/platform/status`. See `hangman v2/iOS/WINDOWS-HANGMAN-SERVER-NOTES.md`.

---

## Quick checklist

**PC**

- [ ] Mobile server files copied and `registerMobileApi(..., { broadcast })`  
- [ ] Hangman guess route uses **same** logic as live chat  
- [ ] `/hangman/ws` + platform status + leaderboard  
- [ ] Server restarted  
- [ ] `curl` + `https://y666suf.com` tests pass  

**Mac**

- [ ] `.env` → `https://y666suf.com`  
- [ ] `npm run build` + `cap sync ios`  
- [ ] Link on LIVE, test Play / Board / Chat  

When both sides are done, the app is linked to the **same** Hangman round as TikTok viewers on your PC.
