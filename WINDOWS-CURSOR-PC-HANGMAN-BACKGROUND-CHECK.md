# Windows Cursor — Hangman IPA + background checks (copy everything below into Cursor on PC)

You are finishing the **Windows NFG stack** in `C:\Users\Yusef\test` after Mac pushed a fresh **`releases/ipa/NFG-Hangman.ipa`** plus server fixes. Do **all** steps yourself. Do not ask the user to run extra commands unless something fails. End with a short pass/fail summary.

## What Mac pushed (must be on `main` after pull)

- **`releases/ipa/NFG-Hangman.ipa`** — word slots, green/red keyboard, crash fix (no blank screen on guess)
- **`hangman v2/server.py`** — `hangman_app_guess` returns `slots`, `keyboard`, `length`; outer try/except
- **`server/mobile-hangman.js`** — `sanitizeKeyboard`, guess route try/catch, forwards slots/keyboard
- **`hangman v2/iOS/app/`** — client hardening (only matters for Mac builds; IPA is prebuilt)

Recent commits to expect: `Fix Hangman app crash on keyboard guess` and/or `Fix Hangman iOS word slots and keyboard colors`.

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -3 --oneline
```

Verify these files exist and are recent:

```powershell
@(
  "releases\ipa\NFG-Hangman.ipa",
  "server\mobile-hangman.js",
  "hangman v2\server.py",
  "scripts\test-hangman-mobile-guess.ps1"
) | ForEach-Object {
  if (Test-Path $_) { Get-Item $_ | Select-Object Name, Length, LastWriteTime }
  else { Write-Host "MISSING: $_" }
}
```

---

## Step 2 — Copy IPAs to Downloads

```powershell
cd C:\Users\Yusef\test
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Downloads" | Out-Null
if (Test-Path "releases\ipa\NFG-Hangman.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
}
if (Test-Path "releases\ipa\NFG-Crash.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Crash.ipa" "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
}
Get-Item "$env:USERPROFILE\Downloads\NFG-*.ipa" -ErrorAction SilentlyContinue |
  Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

Hangman IPA should be ~1.7 MB and dated today.

---

## Step 3 — Background code checks (before restart)

Confirm hardened guess path — fix on PC if any check fails:

```powershell
cd C:\Users\Yusef\test

# Node mobile guess: try/catch + sanitizeKeyboard
Select-String -Path "server\mobile-hangman.js" -Pattern "sanitizeKeyboard|hangman/guess|mapHangmanGuessResponse" |
  Select-Object -First 8

# Python app guess: try/except + slots in return
Select-String -Path "hangman v2\server.py" -Pattern "hangman_app_guess|sanitizeKeyboard|slots" |
  Select-Object -First 8

# Server registration order (mobile API before hangman proxy)
Select-String -Path "server\index.js" -Pattern "registerMobileApi|registerHangmanHttpProxy" |
  Select-Object LineNumber, Line
```

**Required:**

- `mobile-hangman.js` has `sanitizeKeyboard` and `POST` `/api/mobile/hangman/guess` wrapped in try/catch
- `server.py` has `hangman_app_guess` with outer `except` returning JSON `{ ok: false }`
- `hangman_app_guess` return includes `"slots"` and `"keyboard"` (search near `snap = session.snapshot()`)

---

## Step 4 — Environment (verify in `run-electron-cloudflare.bat`)

```bat
set PORT=3847
set HANGMAN_PORT=19876
set HANGMAN_BACKEND_URL=http://127.0.0.1:19876
set NFG_PLATFORM_URL=http://127.0.0.1:3847
set NFG_INTERNAL_SECRET=nfg-dev-internal
set NFG_START_HANGMAN=1
set HANGMAN_PYTHON=py
```

`NFG_INTERNAL_SECRET` must match what Hangman Python expects for `X-NFG-Internal`.

---

## Step 5 — Start stack

Stop old Node/Electron on **3847**, then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready`

---

## Step 6 — Automated smoke tests (second PowerShell window)

```powershell
cd C:\Users\Yusef\test

# IPA download endpoints
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 5

# Hangman + platform (JSON only)
.\scripts\test-hangman-mobile-guess.ps1

# Platform status
Invoke-RestMethod http://127.0.0.1:3847/api/mobile/platform/status -Headers @{"X-Client-App"="nfg-hangman"} | ConvertTo-Json -Depth 4

# Hangman backend direct (optional)
try {
  Invoke-RestMethod http://127.0.0.1:19876/api/hangman/status | ConvertTo-Json
} catch { Write-Host "Hangman 19876 not reachable: $_" }

# Ports listening
netstat -ano | findstr ":3847 :19876"
```

**Pass criteria:**

- `api/ipa/download-info` → hangman `ok: true` (and crash if present)
- `test-hangman-mobile-guess.ps1` exits **0**; all responses are JSON
- **Electron window still open** after the script (guess must not kill desktop app)
- Ports **3847** and **19876** in LISTENING state

---

## Step 7 — Fix if tests fail

1. `registerMobileApi` before `registerHangmanHttpProxy` in `server/index.js`
2. `mobile-hangman.js` guess handler never throws (try/catch → 500 JSON)
3. `hangman v2/server.py` `hangman_app_guess` never raises uncaught (returns JSON on error)
4. `NFG_INTERNAL_SECRET` identical on Node + Hangman child
5. Restart `.\run-electron-cloudflare.bat` and re-run Step 6

Do **not** remove TikTok bridge, Crash bets, or `!link`.

---

## Step 8 — Live / iPhone checklist (report to user)

When https://y666suf.com is up and @y666.suf is LIVE:

| Check | Expected |
|--------|----------|
| Sideload | https://y666suf.com/sideload serves both IPAs |
| Link | Hangman Account → code → TikTok `!link CODE` |
| Word length | 7-letter PC word → 7 slots on iPhone (not 5) |
| Reveal | Correct guess fills slot |
| Keyboard | Correct = green, wrong = red, disabled |
| Guess crash | iPhone Play tab stays up (no blank white screen) |
| Electron | PC Hangman still running after app guess |
| Chat labels | `NFG Crash` / `NFG Hangman` in app chat |

---

## Step 9 — Done message

Reply with:

1. `git log -1` hash after pull
2. Hangman IPA size + date in `releases\ipa\`
3. `download-info` JSON (hangman ok)
4. `test-hangman-mobile-guess.ps1` exit code
5. Electron survived? (yes/no)
6. Any file patched on PC (if any)

**Do not ask the user to run more commands unless a step failed.**
