# Windows Cursor — pull Hangman zoom fix + refresh IPA (copy below the line)

You are updating the **Windows NFG stack** after the Mac pushed a **Hangman zoom/layout fix** and a new **`releases/ipa/NFG-Hangman.ipa`**. Do all steps yourself in `C:\Users\Yusef\test`. Do not ask the user to run extra commands unless something fails.

---

## What changed (Mac)

- Fixed iOS zoom: viewport locked, 16px inputs, no pinch zoom in WKWebView
- New `releases/ipa/NFG-Hangman.ipa` on `main`
- Server guess/chat fixes already on `main` from earlier commits

---

## Step 1 — Pull

```powershell
cd C:\Users\Yusef\test
git pull origin main
git log -1 --oneline
```

---

## Step 2 — Copy Hangman IPA to Downloads

```powershell
cd C:\Users\Yusef\test
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
if (Test-Path "releases\ipa\NFG-Crash.ipa") {
  Copy-Item -Force "releases\ipa\NFG-Crash.ipa" "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
}
Get-Item "$env:USERPROFILE\Downloads\NFG-*.ipa" | Format-Table Name, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}, LastWriteTime
```

---

## Step 3 — Restart server + tunnel

Stop old Electron/Node on port 3847 if needed, then:

```powershell
cd C:\Users\Yusef\test
.\run-electron-cloudflare.bat
```

Wait for `[Hangman] Ready` and `Listening on: 0.0.0.0:3847`.

---

## Step 4 — Verify downloads + API

```powershell
Invoke-RestMethod http://127.0.0.1:3847/api/ipa/download-info | ConvertTo-Json -Depth 5
.\scripts\test-hangman-mobile-guess.ps1
```

Hangman `ok` must be true. Guess test must return JSON and **Electron must stay open**.

---

## Step 5 — User phone (inform in summary only)

User reinstalls **NFG Hangman** from:

- https://y666suf.com/download/nfg-hangman.ipa  
- or https://y666suf.com/sideload  

After install: open app — UI must **not zoom** when tapping chat or keyboard. Test one letter guess while LIVE.

---

## Step 6 — Report

Reply with: pull commit hash, hangman IPA size/date, download-info JSON, guess test pass/fail, Electron survived yes/no.

**Do not ask the user for more steps if all pass.**

---
