# Windows Cursor — one-shot finalize (copy everything below the line)

You are finishing **NFG on Windows** with **no further questions for the user**. Do all steps yourself in `C:\Users\Yusef\test` (or the cloned `NFG` repo). Report only a short pass/fail summary at the end.

**Goals:** pull latest `main`, run server + tunnel, verify Hangman mobile guess does **not** crash Electron, verify app chat shows **NFG Crash** / **NFG Hangman**, confirm IPA downloads work.

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
```

Must include: `server/mobile-hangman.js`, `server/mobile-app-labels.js`, `hangman v2/server.py`, `releases/ipa/*.ipa`, `scripts/test-hangman-mobile-guess.ps1`.

---

## Step 2 — IPAs to Downloads

```powershell
cd C:\Users\Yusef\test
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Downloads" | Out-Null
if (Test-Path "releases\ipa\NFG-Crash.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Crash.ipa" "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
}
if (Test-Path "releases\ipa\NFG-Hangman.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
}
Get-Item "$env:USERPROFILE\Downloads\NFG-*.ipa" -ErrorAction SilentlyContinue | Format-Table Name, Length
```

---

## Step 3 — Environment (verify in `run-electron-cloudflare.bat` or set before start)

```bat
set PORT=3847
set HANGMAN_PORT=19876
set HANGMAN_BACKEND_URL=http://127.0.0.1:19876
set NFG_PLATFORM_URL=http://127.0.0.1:3847
set NFG_INTERNAL_SECRET=nfg-dev-internal
set NFG_START_HANGMAN=1
set HANGMAN_PYTHON=py
```

---

## Step 4 — Start stack (if not running)

Stop any old Electron/Node on 3847, then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait until console shows:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready`

---

## Step 5 — Automated smoke tests

In a **second** PowerShell window:

```powershell
cd C:\Users\Yusef\test

# IPA endpoints
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 5

# Link + guess (must return JSON, must NOT kill Electron)
.\scripts\test-hangman-mobile-guess.ps1

# Platform status
Invoke-RestMethod http://127.0.0.1:3847/api/mobile/platform/status -Headers @{"X-Client-App"="nfg-hangman"} | ConvertTo-Json -Depth 4

# Chat sample (check appLabel)
(Invoke-RestMethod http://127.0.0.1:3847/api/mobile/chat?limit=3).messages | ConvertTo-Json -Depth 4
```

**Pass criteria:**

- `api/ipa/download-info` → crash and hangman `ok: true`
- `test-hangman-mobile-guess.ps1` exits 0; guess JSON has `ok` / `masked`
- Electron window **still open** after guess test
- Chat messages include `appLabel` of `NFG Crash` or `NFG Hangman` when sent from apps

---

## Step 6 — Fix if guess still crashes Electron

1. Confirm `server/index.js` has `registerMobileApi` **before** `registerHangmanHttpProxy`.
2. Confirm `POST /api/mobile/hangman/guess` is in `mobile-hangman.js` with try/catch (never throw).
3. Confirm `hangman v2/server.py` `hangman_app_guess` has outer try/except returning JSON on failure.
4. Confirm `NFG_INTERNAL_SECRET` matches on Node and Hangman child.
5. Restart `.\run-electron-cloudflare.bat` and re-run Step 5.

Do **not** remove TikTok bridge, Crash bets, or `!link`.

---

## Step 7 — LIVE checklist (user only needs to test on phone)

When @y666.suf is LIVE:

- https://y666suf.com/sideload installs both IPAs
- NFG Hangman → Account → link code → TikTok `!link CODE`
- Play → one letter → PC updates, **Electron stays open**
- App chat in both apps shows correct **NFG Crash** / **NFG Hangman** labels

---

## Step 8 — Done message to user

Reply with:

1. `git pull` commit hash
2. IPA download-info JSON (both ok)
3. Guess test result (one line)
4. Whether Electron survived the test
5. Any file you had to patch on PC (if any)

**Do not ask the user to run more commands unless a step failed.**

---
