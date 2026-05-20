# iOS release IPAs (local only)

Place Mac-built IPAs here (not committed — `*.ipa` is gitignored):

| File | Sideload URL |
|------|----------------|
| `NFG-Crash.ipa` | `https://y666suf.com/download/nfg-crash.ipa` |
| `NFG-Hangman.ipa` | `https://y666suf.com/download/nfg-hangman.ipa` |

After copying from Mac (Archive → Export, or AirDrop):

```powershell
cd C:\Users\Yusef\test
Copy-Item -Force "releases\ipa\NFG-Crash.ipa"    "$env:USERPROFILE\Downloads\NFG-Crash.ipa"
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa"
```

Then restart `run-electron-cloudflare.bat`. The server scans `%USERPROFILE%\Downloads\` for `.ipa` files.

Or run: `.\scripts\sync-ipa-to-downloads.ps1`
