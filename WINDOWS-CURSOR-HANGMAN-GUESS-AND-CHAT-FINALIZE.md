# Windows Cursor prompt — finalize server, IPAs, Hangman guess fix, app chat labels

**Copy everything below the line into Cursor on your Windows PC** (game root e.g. `C:\Users\Yusef\test`).

---

You are finishing the **NFG Windows stack**: Electron + Node (**port 3847**, **https://y666suf.com**) + Python Hangman (**port 19876**).

**Goals:**

1. **Fix:** iOS Hangman letter guess must **not** crash Electron (Crash + Hangman).
2. **App chat:** show **NFG Crash** / **NFG Hangman** labels + clean TikTok display names.
3. **IPAs:** use the `.ipa` files committed in **`releases/ipa/`** (also copy to PC Downloads for sideload).
4. **Restart** tunnel + verify LIVE on @y666.suf.

**Do not break:** TikTok bridge, Crash bets/WebSocket, `!link`, presence, Super Fan, Cloudflare tunnel.

---

## Part 0 — Sync repo (includes IPAs + server fixes)

```powershell
cd C:\Users\Yusef\test
git pull origin main
```

Confirm these exist after pull:

| Path | Purpose |
|------|---------|
| `releases/ipa/NFG-Crash.ipa` | Crash companion (~7 MB) |
| `releases/ipa/NFG-Hangman.ipa` | Hangman companion (~2 MB) |
| `server/mobile-hangman.js` | Safe mobile guess API |
| `server/mobile-app-labels.js` | `appLabel` for chat/presence |
| `server/index.js` | CORS + crash handlers |
| `hangman v2/server.py` | Safe `hangman_app_guess` |
| `scripts/test-hangman-mobile-guess.ps1` | API smoke test |
| `WINDOWS-CURSOR-HANGMAN-GUESS-AND-CHAT-FINALIZE.md` | This file |

---

## Part 1 — Copy IPAs for sideload (PC Downloads)

Node serves IPAs from **`releases/ipa/`** first, then `Downloads`. Copy both so Windows tools and old docs still work:

```powershell
cd C:\Users\Yusef\test
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Downloads" | Out-Null
Copy-Item -Force "releases\ipa\NFG-Crash.ipa"    "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
Get-Item "$env:USERPROFILE\Downloads\NFG-*.ipa" | Format-Table Name, Length, LastWriteTime
```

Website routes (after server start):

- https://y666suf.com/download/nfg-crash.ipa
- https://y666suf.com/download/nfg-hangman.ipa
- https://y666suf.com/sideload

Check metadata:

```powershell
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 5
```

Both apps should show `"ok": true`.

---

## Part 2 — Environment (Windows)

Set in `run-electron-cloudflare.bat` or system env:

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

Optional explicit IPA paths (normally not needed if `releases/ipa/` exists):

```bat
set NFG_IPA_FILE=%CD%\releases\ipa\NFG-Crash.ipa
set NFG_HANGMAN_IPA_FILE=%CD%\releases\ipa\NFG-Hangman.ipa
```

---

## Part 3 — Hangman guess crash fix (verify code)

Mobile guess chain:

`POST /api/mobile/hangman/guess` → Node → `POST http://127.0.0.1:19876/api/hangman/app/guess` → Python `process_chat_message`.

**Must be true:**

- `registerMobileApi` runs **before** `registerHangmanHttpProxy` in `server/index.js`
- Guess handler has **try/catch** and **timeout** (never throws to crash Node)
- Python `hangman_app_guess` has **try/except**
- `NFG_INTERNAL_SECRET` matches on Node + Hangman child

---

## Part 4 — App chat display names

Server adds per message / presence row:

- `displayName` — from `pointStore` (TikTok nickname)
- `clientApp` — `nfg-crash` | `nfg-hangman`
- `appLabel` — **`NFG Crash`** | **`NFG Hangman`**

No code change needed on PC if `mobile-app-labels.js` is present after pull.

---

## Part 5 — Smoke test (before LIVE)

Start server only if not already running, or run tests against existing instance:

```powershell
cd C:\Users\Yusef\test
.\scripts\test-hangman-mobile-guess.ps1
```

**Pass:** link + guess return JSON; **Electron still open** if it was running.

---

## Part 6 — Start production stack

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for console:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready (proxied through this server).`
- iOS download lines pointing at `releases/ipa/...` or Downloads

---

## Part 7 — Install IPAs on iPhone (testers)

1. AirDrop / USB / link: `https://y666suf.com/sideload`
2. Install **NFG Crash** and **NFG Hangman** (separate apps)
3. **Settings → General → VPN & Device Management** → trust developer cert
4. Open on **cellular** (not only Wi‑Fi) → `https://y666suf.com` must load

---

## Part 8 — LIVE end-to-end test (@y666.suf)

| Step | Crash | Hangman |
|------|-------|---------|
| Top bar LIVE | ✓ | ✓ |
| Account → link code → TikTok `!link CODE` | ✓ | ✓ |
| Game action | bet / ads | letter guess |
| App chat | send message | same thread, **NFG Crash** / **NFG Hangman** tags |
| Guess does not kill PC | — | **Electron must stay open** |

---

## Part 9 — If guess still crashes Electron

1. Read Node console for `[Mobile hangman guess]` or `[NFG] uncaughtException`
2. Read Hangman Python console for `[hangman_app_guess] failed`
3. Confirm `git log -1` includes commit with mobile-hangman + server.py fixes
4. Re-run: `.\scripts\test-hangman-mobile-guess.ps1`

---

## Part 10 — Commit on PC (only if you changed files locally)

```powershell
git add server releases scripts hangman v2/server.py
git commit -m "Apply Windows-side config for NFG finalize"
git push origin main
```

---

## Part 11 — Final checklist

- [ ] `git pull` — has `releases/ipa/*.ipa`
- [ ] IPAs copied to `%USERPROFILE%\Downloads\`
- [ ] `/api/ipa/download-info` — both `ok: true`
- [ ] `.\run-electron-cloudflare.bat` running
- [ ] Mobile guess does **not** quit Electron
- [ ] App chat shows **NFG Crash** / **NFG Hangman**
- [ ] TikTok LIVE @y666.suf — link + guess + chat work on cellular

**Report:** Paste `Invoke-RestMethod .../api/ipa/download-info` JSON + one line from a successful mobile guess test.

---
