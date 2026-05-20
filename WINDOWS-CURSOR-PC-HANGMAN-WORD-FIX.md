# Windows Cursor — Hangman word + keyboard fix (copy below the line)

Update the **Windows NFG stack** after Mac pushed the **Hangman Play tab fix** (correct letter count, reveal on guess, red/green keyboard) and a new **`releases/ipa/NFG-Hangman.ipa`**.

---

## What changed

- iOS app uses `slots` from Hangman WS (same as desktop) — no more hardcoded 5-letter `_ _ _ _ _`
- Correct guesses show green keys; wrong guesses (anyone this round) show **red** keys
- Guess API returns `slots` + `keyboard` immediately; Python `server.py` includes full snapshot on `/api/hangman/app/guess`

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -1 --oneline
```

---

## Step 2 — Copy IPA

```powershell
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
Get-Item "$env:USERPROFILE\Downloads\NFG-Hangman.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

---

## Step 3 — Restart stack

Restart Electron/Node on **3847** and ensure Hangman Python on **19876** is running (`hangman v2/server.py`).

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

---

## Step 4 — Verify

1. Start a 7-letter word on desktop Hangman — iPhone Play tab shows **7 slots** (not 5).
2. Guess a correct letter — slot fills in; key turns **green**.
3. Guess a wrong letter (or after someone else guessed wrong) — key turns **red** and stays disabled.
4. `POST /api/mobile/hangman/guess` must not crash Electron.

Reinstall on iPhone from `Downloads\NFG-Hangman.ipa` (AltStore/Xcode) after Mac push.
