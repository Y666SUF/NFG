# Windows Cursor — Hangman word + keyboard fix (copy everything below into Cursor on PC)

You are updating the **Windows NFG stack** in `C:\Users\Yusef\test` after Mac pushed commit with **Hangman Play tab fix** and new **`releases/ipa/NFG-Hangman.ipa`**. Do all steps yourself. Do not ask the user to run extra commands unless something fails.

## What Mac pushed

- iOS app uses `slots` from Hangman WebSocket (same as desktop) — no more hardcoded 5-letter `_ _ _ _ _`
- Correct guesses: green keyboard keys; wrong guesses (anyone this round): **red** keys, disabled
- Python `hangman v2/server.py` guess API returns `slots` + `keyboard` + `length` immediately
- Node `server/mobile-hangman.js` forwards those fields to the app

## Step 1 — Pull latest

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -1 --oneline
```

Expect a commit message like: `Fix Hangman iOS word slots and keyboard colors.`

## Step 2 — Copy Hangman IPA to Downloads

```powershell
cd C:\Users\Yusef\test
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
Get-Item "$env:USERPROFILE\Downloads\NFG-Hangman.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

## Step 3 — Restart server + tunnel

Stop any old Node/Electron on port **3847**. Ensure Hangman Python on **19876** is available (`hangman v2\server.py`).

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for `[Hangman] Ready` and `Listening on: 0.0.0.0:3847`.

Confirm mobile guess route exists:

```powershell
Select-String -Path "server\mobile-hangman.js" -Pattern "hangman/guess" | Select-Object -First 2
```

## Step 4 — Verify live (with iPhone already updated on Mac)

1. Start a **7-letter** word on desktop Hangman — iPhone **Play** tab shows **7 slots** (not 5).
2. Guess a **correct** letter — slot reveals; key turns **green**.
3. Guess a **wrong** letter (or after chat guessed wrong) — key turns **red** and stays disabled.
4. `POST /api/mobile/hangman/guess` must **not** crash Electron.

## Step 5 — If iPhone still shows old UI

Mac already installed `NFG-Hangman.ipa` to the phone. If Play tab still wrong, reinstall from PC Downloads via AltStore/Xcode, or tell user to trust developer cert in Settings → General → VPN & Device Management.

## Done when

- `git pull` shows the word/keyboard fix commit
- Server running on 3847, tunnel up, Hangman WS live
- iPhone Play tab matches desktop word length and keyboard colors
