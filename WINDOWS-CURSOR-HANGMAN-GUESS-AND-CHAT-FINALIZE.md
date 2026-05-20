# Windows Cursor — Hangman guess crash + app chat labels

Open this file and **copy everything below the line** into Cursor on Windows.

---

## Quick reference (PC)

```powershell
cd C:\Users\Yusef\test
git pull origin main
Copy-Item -Force "releases\ipa\NFG-Crash.ipa"    "$env:USERPROFILE\Downloads\NFG-Crash.ipa"    -ErrorAction SilentlyContinue
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa" -ErrorAction SilentlyContinue
# Or: .\scripts\sync-ipa-to-downloads.ps1
.\scripts\test-hangman-mobile-guess.ps1
.\run-electron-cloudflare.bat
```

| Step | Purpose |
|------|---------|
| `git pull` | Server fixes: guess hardening, `appLabel` chat, CORS, Electron Hangman window |
| Copy IPAs | Mac builds → `releases\ipa\` → Downloads → `https://y666suf.com/download/nfg-*.ipa` |
| Smoke test | Guess endpoints return JSON; Node stays up |
| Launcher | Crash + Hangman + tunnel from **one** `.bat` |

IPAs are gitignored. Drop Mac exports into `releases\ipa\` (see `releases\ipa\README.md`).

---

You are fixing / verifying the **NFG platform** on Windows (`GAME_ROOT`, port **3847**). Mobile Hangman letter guesses must **never** kill the Node server or Electron. App chat must show clean names: **NFG Crash** / **NFG Hangman** plus `displayName` from `pointStore`.

## Context

| Piece | Path |
|-------|------|
| GAME_ROOT | `C:\Users\Yusef\test` |
| Hangman guess | `POST /api/mobile/hangman/guess` → Python `/api/hangman/app/guess` → `process_chat_message` |
| Chat labels | `server/mobile-app-labels.js` + `server/mobile-chat.js` |
| Launcher | `run-electron-cloudflare.bat` |
| IPA staging | `releases\ipa\` → `%USERPROFILE%\Downloads\` |

**Likely crash (fixed on `main`):** unhandled error in Node → Python guess → Node child exits → Electron “server stopped”.

## Part 1 — Verify fixes exist

### `server/mobile-app-labels.js`

- `appLabelFromClientApp("nfg-crash")` → `"NFG Crash"`
- `appLabelFromClientApp("nfg-hangman")` → `"NFG Hangman"`
- `enrichChatMessage(row, pointStore)` — `displayName` from `pointStore.getUserPresentation`

### `server/mobile-chat.js`

- Uses `enrichChatMessage` on GET/POST
- Log: `[App chat] [NFG Hangman] DisplayName …`

### `server/mobile-hangman.js`

- Guess HTTP **timeout** (12s), always JSON
- `POST /api/mobile/hangman/guess`: **try/catch**

### `hangman v2/server.py`

- `hangman_app_guess`: **try/except** → `{"ok": false, "error": "guess_failed"}`

### `server/index.js`

- CORS: `capacitor://`, `ionic://`, mobile headers
- `uncaughtException` / `unhandledRejection` — log only, no `process.exit`

### UI

- `public/app-chat.html` — `appLabel`
- Hangman Capacitor `ChatPanel.jsx` — `appLabel` (rebuild on Mac for phone)

## Part 2 — Do not break

- Crash bets, TikTok bridge, `points.live.json`
- Hangman 6-wrong via `process_chat_message`
- One launcher opens Crash + Hangman Electron windows

## Part 3 — Test

```powershell
.\scripts\test-hangman-mobile-guess.ps1
```

**Pass:** `PASS`; then `.\run-electron-cloudflare.bat`.

On iPhone (LIVE + linked): one letter guess → JSON; **Electron stays open**.

## Part 4 — Report

1. Smoke test PASS/FAIL
2. Electron survived linked guess?
3. Sample chat JSON with `appLabel` + `displayName`
4. `curl -I https://y666suf.com/download/nfg-hangman.ipa` after IPA copy

## Do NOT

- `process.exit` on uncaughtException
- Throw from guess route without try/catch
- Show raw `nfg-hangman` when `appLabel` exists
