# Windows Cursor prompt — fix Hangman app guess crash + finalize shared chat labels

**Copy everything below the line into Cursor on your Windows PC** (game root e.g. `C:\Users\Yusef\test` or your cloned `NFG` repo).

---

You are fixing the **NFG Windows stack**: Electron + Node (**port 3847**, public **https://y666suf.com**) + Python Hangman (**port 19876**, proxied at `/hangman/ws` and `/api/hangman/*`).

**Symptom:** When a player taps a letter in the **NFG Hangman** iOS app, the **entire Electron app exits** (Crash overlay + Hangman both die).

**Also finish:** Shared **app chat** should show clean names: player display name from `pointStore`, plus app badge **NFG Crash** or **NFG Hangman** (not raw `nfg-crash` / `nfg-hangman`).

**Do not break:** TikTok bridge, Crash bets/WebSocket, `!link`, presence, Super Fan badges, Cloudflare tunnel, IPA downloads.

---

## Part 0 — Sync repo

```powershell
cd C:\Users\Yusef\test
git pull origin main
```

Confirm Mac pushed latest `main` (includes `server/mobile-hangman.js`, `server/mobile-app-labels.js`, CORS for Capacitor, Hangman iOS fixes).

---

## Part 1 — Root cause (guess crash)

Mobile guess path:

1. iPhone → `POST https://y666suf.com/api/mobile/hangman/guess` (Bearer + `X-Client-App: nfg-hangman`)
2. Node `server/mobile-hangman.js` → internal `POST http://127.0.0.1:19876/api/hangman/app/guess` with headers:
   - `X-NFG-Internal: <NFG_INTERNAL_SECRET>`
   - `X-NFG-User-Id`, `X-NFG-Display-Name`
3. Python `hangman v2/server.py` → `process_chat_message()` (same as TikTok chat)

**Electron quits** when the **Node child** spawned by `electron/main.js` exits with **code ≠ 0** (see `serverProcess.on("exit")`). So any **unhandled exception** in the guess route or a **fatal Node crash** kills both games.

**Fix strategy:**

- Wrap the mobile guess handler in **try/catch** (never throw to Express).
- Add **HTTP timeout** on the internal guess call (fail with JSON, don’t hang).
- Wrap Python `hangman_app_guess` in **try/except** (return 500 JSON, don’t kill uvicorn).
- Add Node **process-level** handlers that log errors instead of exiting (optional but recommended).
- Verify **`NFG_INTERNAL_SECRET`** is identical in Node env and Hangman Python env (default `nfg-dev-internal`).

---

## Part 2 — Files to verify / merge

| File | Action |
|------|--------|
| `server/mobile-hangman.js` | Hardened guess route + timeout |
| `server/mobile-app-labels.js` | **NEW** — `formatAppLabel()`, `resolveChatDisplayName()` |
| `server/mobile-chat.js` | Adds `appLabel`, normalized `displayName` |
| `server/mobile-presence.js` | Adds `appLabel` on online list |
| `server/index.js` | CORS: `capacitor://`, `X-Device-Id`, `X-Client-App` |
| `hangman v2/server.py` | `hangman_app_guess` try/except |
| `server/mobile-api.js` | Registers hangman mobile routes (must exist) |
| `electron/main.js` | Only quits on Node exit — Hangman Python death alone must not kill Node |

**Route order in `server/index.js` (critical):**

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
registerHangmanHttpProxy(app);  // only /api/hangman/* — NOT /api/mobile/*
```

Mobile guess must stay at **`/api/mobile/hangman/guess`** (not proxied to Python directly from the phone).

---

## Part 3 — Environment (Windows)

In `run-electron-cloudflare.bat` or system env (same values everywhere):

```bat
set PORT=3847
set HANGMAN_PORT=19876
set HANGMAN_HOST=127.0.0.1
set HANGMAN_BACKEND_URL=http://127.0.0.1:19876
set NFG_PLATFORM_URL=http://127.0.0.1:3847
set NFG_INTERNAL_SECRET=nfg-dev-internal
set NFG_START_HANGMAN=1
set HANGMAN_PYTHON=py
```

If you change `NFG_INTERNAL_SECRET`, set the **same** value for the Hangman child (Node passes it in `server/hangman-process.js` → Python `os.environ`).

---

## Part 4 — App chat display names (server)

After edits, each chat row should look like:

- `displayName`: TikTok nickname from `pointStore.getDisplayName(userId)` (fallback session / userId)
- `clientApp`: `nfg-crash` | `nfg-hangman` (raw, for logic)
- `appLabel`: **`NFG Crash`** | **`NFG Hangman`** (for UI)

`POST /api/mobile/chat` and WebSocket `app_chat` broadcasts must include **`appLabel`**.

Presence `activeAppUserList` entries should include **`appLabel`** too.

Clients:

- **NFG Crash** (Swift): show `displayName` + optional subtitle with `appLabel` if not self
- **NFG Hangman** (React): prefer `row.appLabel` over raw `clientApp`

Both apps must send on every mobile request:

- `X-Client-App: nfg-crash` or `nfg-hangman`
- `X-Device-Id: <stable device id>`

---

## Part 5 — Implement / confirm code (if missing after pull)

### 5A. `server/mobile-hangman.js`

- `POST /api/mobile/hangman/guess` wrapped in **try/catch**
- `hangmanGuessRequest` uses **request timeout** (~12s)
- On error: `res.status(502).json({ ok: false, error: 'hangman_guess_failed', message })` — **never throw**
- Log: `[Mobile hangman guess] @user letter=X status=...`

### 5B. `hangman v2/server.py` — `hangman_app_guess`

Wrap `process_chat_message` in:

```python
try:
    ...
except Exception as e:
    log.exception("hangman_app_guess failed")
    raise HTTPException(status_code=500, detail="Guess failed safely")
```

### 5C. `server/index.js` — optional safety net

At top of server startup:

```javascript
process.on("uncaughtException", (err) => console.error("[fatal]", err));
process.on("unhandledRejection", (err) => console.error("[reject]", err));
```

(Do **not** call `process.exit(1)` — keep Crash running.)

---

## Part 6 — Test on PC (before iPhone)

PowerShell:

```powershell
$Base = "http://127.0.0.1:3847"
$H = @{ "Content-Type" = "application/json"; "X-Client-App" = "nfg-hangman"; "X-Device-Id" = "pc-test" }

# 1) Link code
$start = Invoke-RestMethod -Uri "$Base/api/mobile/link/start" -Method POST -Headers $H -Body '{"deviceId":"pc-test"}'
$start | ConvertTo-Json

# 2) Simulate TikTok link (while testing)
$chat = @{ userId = "y666.suf"; displayName = "Yusuf"; message = "!link $($start.code)" } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$Base/api/chat" -Method POST -Body $chat -ContentType "application/json"

# 3) Poll link
Invoke-RestMethod -Uri "$Base/api/mobile/link/status/$($start.code)" | ConvertTo-Json

# 4) Guess (use token from step 3 if linked)
$token = "<paste token>"
$GH = @{ "Authorization" = "Bearer $token"; "X-Client-App" = "nfg-hangman"; "Content-Type" = "application/json" }
Invoke-RestMethod -Uri "$Base/api/mobile/hangman/guess" -Method POST -Headers $GH -Body '{"letter":"e"}' | ConvertTo-Json

# 5) App chat labels
Invoke-RestMethod -Uri "$Base/api/mobile/chat?limit=5" | ConvertTo-Json -Depth 6
```

**Pass criteria:**

- Step 4 returns JSON (`ok`, `masked`, `wrong`, …) — **Electron stays open**
- PC console shows `[Mobile hangman guess]` not a stack trace + process exit
- Step 5 messages include `appLabel` and readable `displayName`

---

## Part 7 — Restart production stack

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready (proxied through this server).`
- Cloudflare tunnel healthy → **https://y666suf.com**

---

## Part 8 — Live test with iPhones

1. **NFG Hangman** + **NFG Crash** on cellular
2. @y666.suf **LIVE** — Hangman round active on PC
3. Account → **Generate link code** → TikTok `!link CODE`
4. Hangman **Play** → tap **one letter** → PC updates word; **Electron must not close**
5. **App chat** in both apps: same thread; names show **NFG Crash** / **NFG Hangman** badges
6. Presence: “X in apps” lists both with correct labels

---

## Part 9 — Final deliverables checklist

- [ ] Guess from iOS no longer kills Electron
- [ ] `git add` / `git commit` / `git push origin main` with server + Python fixes
- [ ] IPAs in `Downloads`: `NFG-Crash.ipa`, `NFG-Hangman.ipa` (sideload page works)
- [ ] `GET /api/mobile/platform/status` shows LIVE when streaming
- [ ] TikTok `!link` works on Hangman LIVE and Crash LIVE

**Report back:** Paste PC console lines from one mobile guess + one app chat message JSON (redact tokens).

---
