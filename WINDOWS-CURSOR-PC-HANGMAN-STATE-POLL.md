# Windows Cursor — Hangman state route + fresh IPA (copy below into Cursor on PC)

Finish the **Windows NFG stack** in `C:\Users\Yusef\test`. Do all steps yourself. Short pass/fail summary at the end.

## What changed (Mac `main`)

- **`GET /api/mobile/hangman/state`** on port **3847** — JSON with `ok`, `maskedWord`, `slots`, `keyboard` (not 404)
- **`GET /api/hangman/app/state`** on Hangman Python **19876** (proxied by Node)
- **NFG Hangman iOS** polls state every **2s** (works even if WS is flaky)
- New **`releases/ipa/NFG-Hangman.ipa`**

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -1 --oneline
```

---

## Step 2 — Restart platform (required for new route)

Stop Electron / old Node on **3847**, then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for `Listening on: 0.0.0.0:3847` and `[Hangman] Ready`.

---

## Step 3 — State endpoint check (must not be 404)

```powershell
$r = Invoke-WebRequest -Uri "http://127.0.0.1:3847/api/mobile/hangman/state" -Headers @{"X-Client-App"="nfg-hangman"} -UseBasicParsing
$r.StatusCode
$r.Content | ConvertFrom-Json | ConvertTo-Json -Depth 6
```

**Pass:** HTTP **200**, JSON `ok: true`, and `maskedWord` or `slots` plus `keyboard.correct` / `keyboard.wrong` arrays.

**Fail 404:** `server/mobile-hangman.js` missing `GET /api/mobile/hangman/state` — pull again or patch route, restart.

**Fail 502:** Hangman Python not on **19876** — check `hangman v2/server.py` has `hangman_app_state` at `/api/hangman/app/state`.

---

## Step 4 — Full smoke tests

```powershell
cd C:\Users\Yusef\test
.\scripts\test-hangman-mobile-guess.ps1
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 4
```

Electron must **stay open** after tests.

---

## Step 5 — Copy IPAs

```powershell
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
Get-Item "$env:USERPROFILE\Downloads\NFG-Hangman.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

User reinstalls Hangman from https://y666suf.com/sideload (old IPA has no polling).

---

## Step 6 — Live checklist

| Check | Expected |
|--------|----------|
| State API | `GET /api/mobile/hangman/state` → 200 JSON |
| Play tab | Word fills within ~2s while live |
| Keyboard | Stream/app guesses → green/red keys |
| Guess | App keyboard does not blank/crash |
| Electron | Survives app guess |

---

## Done message

1. `git log -1` hash  
2. State endpoint: status + `ok`  
3. Smoke script exit code  
4. Electron survived? (yes/no)
