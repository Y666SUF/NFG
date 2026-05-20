# Windows Cursor — Hangman guess crash + app chat labels

Copy everything below the line into **Cursor on Windows** after `git pull origin main`.

---

You are fixing the **NFG platform** on Windows (`GAME_ROOT`, port **3847**). Mobile Hangman letter guesses must **never** kill the Node server or Electron. App chat must show clean names: **NFG Crash** / **NFG Hangman** plus `displayName` from `pointStore`.

## Context

| Piece | Path |
|-------|------|
| GAME_ROOT | `C:\Users\Yusef\test` (or your clone) |
| Hangman guess API | `POST /api/mobile/hangman/guess` → Python `POST /api/hangman/app/guess` → `process_chat_message` |
| Chat | `server/mobile-chat.js` + `server/mobile-app-labels.js` |
| Launcher | `run-electron-cloudflare.bat` |

**Likely crash:** unhandled error in Node → Python guess chain → Node child exits → Electron shows “server stopped”.

## Part 1 — Verify / apply server fixes

Confirm these exist (implement if missing):

### `server/mobile-app-labels.js`

- `appLabelFromClientApp("nfg-crash")` → `"NFG Crash"`
- `appLabelFromClientApp("nfg-hangman")` → `"NFG Hangman"`
- `enrichChatMessage(row, pointStore)` — `displayName` from `pointStore.getUserPresentation`, adds `appLabel`

### `server/mobile-chat.js`

- Uses `enrichChatMessage` on GET list and POST new messages
- Console log: `[App chat] [NFG Hangman] DisplayName …`

### `server/mobile-hangman.js`

- `hangmanGuessRequest`: **timeout** (12s), always resolves JSON (never throws)
- `POST /api/mobile/hangman/guess`: outer **try/catch**, returns `{ ok: false, error }` on failure

### `hangman v2/server.py`

- `hangman_app_guess`: whole body in **try/except**; generic errors return `{"ok": false, "error": "guess_failed"}`

### `server/index.js`

- CORS: allow `capacitor://` and `ionic://` origins
- CORS headers: `X-Device-Id`, `X-Client-App`, `Authorization`, etc.
- `process.on("uncaughtException")` / `unhandledRejection` — **log only**, do not `process.exit`

### UI (optional on PC)

- `public/app-chat.html` — show `appLabel`
- `hangman v2/iOS/app/src/components/ChatPanel.jsx` — show `appLabel` (phone rebuild on Mac)

## Part 2 — Do not break

- Crash bets, TikTok bridge, `points.live.json`
- Hangman 6-wrong rule via `process_chat_message`
- Electron Crash + Hangman windows from one bat file

## Part 3 — Test on PC

```powershell
cd C:\Users\Yusef\test
git pull origin main
.\scripts\test-hangman-mobile-guess.ps1
```

**Pass:** script prints `PASS`; `/api/mobile/status` still returns JSON after guess attempts.

Then restart:

```powershell
.\run-electron-cloudflare.bat
```

On iPhone (linked on LIVE): one letter guess → JSON in app, **Electron stays open**.

## Part 4 — Report

1. `test-hangman-mobile-guess.ps1` output (PASS/FAIL)
2. Whether Electron survived a real linked guess
3. Sample `POST /api/mobile/chat` message showing `appLabel` + `displayName`

## Do NOT

- `process.exit(1)` on uncaughtException in production server
- Let guess route throw without try/catch
- Show raw `nfg-hangman` in chat UI when `appLabel` exists
