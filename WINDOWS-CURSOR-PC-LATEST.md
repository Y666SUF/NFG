# Windows Cursor — NFG Hangman latest (copy everything below into Cursor on PC)

You are updating the **Windows NFG stack** in `C:\Users\Yusef\test`. **Mac work is complete** — no Mac prompts or builds needed. Do all steps yourself. End with a short pass/fail summary.

## What is on `main` after `git pull`

- **`releases/ipa/NFG-Hangman.ipa`** — word slots, green/red keyboard, crash fix, **2s state polling**
- **`GET /api/mobile/hangman/state`** on **3847** (not 404)
- **`hangman v2/server.py`** — `/api/hangman/app/state` + safe `hangman_app_guess`
- **`server/mobile-hangman.js`** — state route, `sanitizeKeyboard`, guess try/catch
- **`website/sideload.html`** — downloads via `/download/nfg-hangman.ipa` (served from `releases/ipa/`)

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -1 --oneline
```

Expect recent commit like: `Add Hangman state API, iOS polling, and refresh IPA` or `Fix Hangman app crash on keyboard guess`.

Verify IPA exists:

```powershell
Get-Item "releases\ipa\NFG-Hangman.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

---

## Step 2 — Publish IPA for website + local server

The Node server serves IPAs from **`releases\ipa\` first** (then Downloads). After pull, copy to Downloads so both paths match:

```powershell
cd C:\Users\Yusef\test
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
if (Test-Path "releases\ipa\NFG-Crash.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Crash.ipa" "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
}
Get-Item "$env:USERPROFILE\Downloads\NFG-*.ipa" -ErrorAction SilentlyContinue | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

No separate FTP upload — **https://y666suf.com/sideload** uses the running stack on this PC once tunnel is up.

---

## Step 3 — Restart platform (loads new routes + IPA)

Stop old Electron/Node on **3847**, then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for:

- `Listening on: 0.0.0.0:3847`
- `[Hangman] Ready`

---

## Step 4 — Background checks

```powershell
cd C:\Users\Yusef\test

# State route (must NOT be 404)
$r = Invoke-WebRequest -Uri "http://127.0.0.1:3847/api/mobile/hangman/state" -Headers @{"X-Client-App"="nfg-hangman"} -UseBasicParsing
Write-Host "state HTTP" $r.StatusCode
$r.Content | ConvertFrom-Json | Select-Object ok, maskedWord, length, @{N='slots';E={$_.slots.Count}}, keyboard | ConvertTo-Json -Depth 5

# IPA metadata + smoke
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 5
.\scripts\test-hangman-mobile-guess.ps1

# Direct download bytes (local)
$h = Invoke-WebRequest -Uri "http://127.0.0.1:3847/download/nfg-hangman.ipa" -Method Head -UseBasicParsing
Write-Host "hangman.ipa bytes:" $h.Headers["Content-Length"]
```

**Pass:**

- State → **200**, `ok: true`, `maskedWord` or `slots`, `keyboard` object
- `download-info` → hangman `ok: true` with size ~1.7 MB
- Smoke script exit **0**
- **Electron still open** after smoke test
- Head request returns non-zero Content-Length

---

## Step 5 — Public website (tunnel must be running)

```powershell
try {
  Invoke-RestMethod "https://y666suf.com/api/ipa/download-info" | ConvertTo-Json -Depth 4
  $pub = Invoke-WebRequest "https://y666suf.com/download/nfg-hangman.ipa" -Method Head -UseBasicParsing
  Write-Host "Public hangman IPA bytes:" $pub.Headers["Content-Length"]
} catch {
  Write-Host "Public check failed (tunnel down?): $_"
}
```

Open in browser: **https://y666suf.com/sideload** — Hangman download should show current size/date.

---

## Step 6 — Code sanity (fix if missing)

```powershell
Select-String -Path "server\mobile-hangman.js" -Pattern "/api/mobile/hangman/state" | Select-Object -First 1
Select-String -Path "hangman v2\server.py" -Pattern "hangman_app_state" | Select-Object -First 1
Select-String -Path "server\index.js" -Pattern "registerMobileApi|registerHangmanHttpProxy" | Select-Object LineNumber, Line
```

If state is **404**: confirm `registerHangmanMobileRoutes` in `server/mobile-api.js` and restart stack.

---

## Step 7 — User iPhone (tell user, do not run on PC)

- Reinstall **NFG Hangman** from https://y666suf.com/sideload (old IPA has no polling)
- Force-quit app, reopen **Play** while live
- Word fills within ~2s; keyboard green/red updates from stream or app

---

## Done message to user

1. `git log -1` hash  
2. Hangman IPA size in `releases\ipa\`  
3. State endpoint: HTTP + `ok`  
4. `download-info` hangman ok + public sideload ok (yes/no)  
5. Smoke script exit code; Electron survived?  
6. Any PC file patched (if any)

**Do not ask the user to run more commands unless a step failed.**
