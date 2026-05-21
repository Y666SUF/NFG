# Windows Cursor — Hangman sync with iOS app (copy everything below into Cursor on PC)

You are updating the **Windows NFG repo** at `C:\Users\Yusef\test` (or the cloned `Y666SUF/NFG` folder) so **desktop Hangman**, **Node platform (3847)**, **Python Hangman (19876)**, **Cloudflare tunnel**, and the **NFG Hangman iOS app** stay in sync. **Mac work is done** — do not ask for Mac builds. Do all steps yourself. End with a short pass/fail summary.

---

## What must work after this update

| Feature | Endpoint / path |
|--------|------------------|
| iOS polls game every 2s | `GET /api/mobile/hangman/state` on **3847** (not 404) |
| Python snapshot | `GET /api/hangman/app/state` on **19876** |
| App guesses | `POST /api/mobile/hangman/guess` → `POST /api/hangman/app/guess` |
| Live updates | `push_state()` after TikTok + app guesses |
| Word on phone | `maskedWord` like `_ _ _ _ S _ _` with letters when guessed |
| Keyboard on phone | `keyboard.correct` green, `keyboard.wrong` red |
| Public sideload | `https://y666suf.com/sideload` + `/download/nfg-hangman.ipa` |
| Desktop UI | `hangman v2/static/app.js` `renderState()` — slots + keyboard (unchanged) |

**Source folder:** `hangman v2/` (with space) — **not** `hangman-v2/`

---

## Step 1 — Pull latest `main`

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -5 --oneline
```

Must include commits mentioning: **Hangman state API**, **word display / mask**, **mobile-hangman**, **NFG-Hangman.ipa**.

---

## Step 2 — Verify critical files exist

```powershell
cd C:\Users\Yusef\test
@(
  "hangman v2\server.py",
  "server\mobile-hangman.js",
  "server\mobile-api.js",
  "server\index.js",
  "server\hangman-proxy.js",
  "server\ipa-downloads.js",
  "scripts\test-hangman-mobile-guess.ps1",
  "releases\ipa\NFG-Hangman.ipa",
  "run-electron-cloudflare.bat"
) | ForEach-Object {
  if (Test-Path $_) { Get-Item $_ | Select-Object Name, Length, LastWriteTime }
  else { Write-Host "MISSING: $_" -ForegroundColor Red }
}
```

**Code checks:**

```powershell
Select-String -Path "server\mobile-hangman.js" -Pattern "api/mobile/hangman/state|sanitizeKeyboard|api/mobile/hangman/guess"
Select-String -Path "hangman v2\server.py" -Pattern "hangman_app_state|hangman_app_guess|push_state"
Select-String -Path "server\index.js" -Pattern "registerMobileApi|registerHangmanHttpProxy" | Select-Object LineNumber, Line
```

**Required:**

- `hangman_app_state` at `/api/hangman/app/state` returns `mask`, `slots`, `keyboard`
- `hangman_app_guess` returns `slots`, `keyboard`, `maskedWord` and calls `push_state` when lines change
- `registerHangmanMobileRoutes` registered from `mobile-api.js` **before** hangman HTTP proxy swallows routes

---

## Step 3 — Update `run-electron-cloudflare.bat` (pull should already have this)

Confirm the bat file sets and documents:

```bat
set PORT=3847
set HANGMAN_PORT=19876
set HANGMAN_BACKEND_URL=http://127.0.0.1:19876
set NFG_INTERNAL_SECRET=nfg-dev-internal
set NFG_START_HANGMAN=1
```

And echoes:

- `GET https://y666suf.com/api/mobile/hangman/state`
- `POST /api/mobile/hangman/guess`
- `wss://y666suf.com/hangman/ws`
- IPA from `releases\ipa\NFG-Hangman.ipa` then Downloads

If the pulled `run-electron-cloudflare.bat` is older, merge in the latest version from `main` (do not remove Cloudflare tunnel logic).

---

## Step 4 — Publish IPAs for website + Downloads

```powershell
cd C:\Users\Yusef\test
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Downloads" | Out-Null
if (Test-Path "releases\ipa\NFG-Hangman.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
}
if (Test-Path "releases\ipa\NFG-Crash.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Crash.ipa" "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
}
Get-ChildItem "$env:USERPROFILE\Downloads\NFG-*.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

Node serves IPAs from `releases\ipa\` first (`server/ipa-downloads.js`).

---

## Step 5 — Stop old processes and restart stack

Kill anything on **3847** / **19876** (old Electron/Node/Python), then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for console:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready` or Hangman backend on 19876
- Cloudflare tunnel up
- Electron: Crash + Hangman windows

---

## Step 6 — Automated smoke tests (second PowerShell window)

```powershell
cd C:\Users\Yusef\test

# State (must be 200, not 404)
$r = Invoke-WebRequest -Uri "http://127.0.0.1:3847/api/mobile/hangman/state" -Headers @{"X-Client-App"="nfg-hangman"} -UseBasicParsing
Write-Host "state HTTP" $r.StatusCode
$st = $r.Content | ConvertFrom-Json
$st | Select-Object ok, maskedWord, length, @{N='correct';E={$_.keyboard.correct -join ','}}, @{N='wrong';E={$_.keyboard.wrong -join ','}} | Format-List

# Full mobile smoke
.\scripts\test-hangman-mobile-guess.ps1

# IPA + public
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 4
try {
  Invoke-RestMethod "https://y666suf.com/api/ipa/download-info" | ConvertTo-Json -Depth 3
} catch { Write-Host "Public tunnel check failed: $_" }
```

**Pass criteria:**

- State → **200**, `ok: true`, `maskedWord` present (underscores at minimum)
- During an active round with guesses, `maskedWord` must include **letters** (e.g. `_ _ _ _ S _ _`) and `keyboard.correct` non-empty
- Smoke script exit **0**
- Electron **still open** after guess test
- `download-info` hangman `ok: true`

---

## Step 7 — Live sync test (with iPhone on LIVE)

1. Open desktop **Hangman** window — confirm word + “Letters guessed” keyboard match.
2. On iPhone (latest IPA from https://y666suf.com/sideload): **Play** tab within ~2s shows same mask; green/red keys match desktop.
3. Guess one letter on **TikTok chat** — within 2s iPhone word + keyboard update.
4. Guess one letter from **app** — desktop + iPhone update; Electron must not crash.

If iPhone keyboard updates but **word stays all underscores**, check state JSON:

```powershell
(Invoke-RestMethod "http://127.0.0.1:3847/api/mobile/hangman/state" -Headers @{"X-Client-App"="nfg-hangman"}).maskedWord
```

If `maskedWord` has no letters while `keyboard.correct` has letters, fix Python `session.mask()` / `push_state` on PC (same snapshot must drive both).

---

## Step 8 — Fix checklist (only if tests fail)

| Symptom | Fix |
|--------|-----|
| State 404 | `server/mobile-hangman.js` missing route; restart Node |
| State 502 | Python not on 19876; `NFG_START_HANGMAN=1`, check `hangman v2\server.py` |
| Guess kills Electron | Outer try/catch in `mobile-hangman.js` + `hangman_app_guess`; matching `NFG_INTERNAL_SECRET` |
| iPhone word blank | Ensure `maskedWord` in state API includes revealed letters; user reinstalls IPA from sideload |
| Desktop out of sync | Confirm TikTok bridge still calls `process_chat_message` + `push_state` |

Do **not** remove Crash bets, `!link`, or 6-wrong-out rule.

---

## Done message to user

1. `git log -1` hash  
2. State endpoint: HTTP + sample `maskedWord` + `keyboard.correct`  
3. Smoke script exit code; Electron survived?  
4. Public sideload / download-info ok?  
5. Live iPhone word + keyboard sync yes/no  
6. Any files patched on PC (list paths)

**Do not ask the user to run extra commands unless a step failed.**
