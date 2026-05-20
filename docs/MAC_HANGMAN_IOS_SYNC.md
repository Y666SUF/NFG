# MacBook — NFG Hangman iOS sync (paste into Cursor)

You are on a **MacBook** finishing the **NFG Hangman** iOS app (`com.nfg.hangman`) so it matches the **Windows PC** stack at `https://y666suf.com`. **Do all steps yourself.** End with IPA path, size, and device test pass/fail.

Repo path: `~/Documents/nfg-crash` (GitHub: Y666SUF/NFG)

## Must include

- 2s poll: `GET /api/mobile/hangman/state`
- Green/red keyboard + word slots from poll/WS/guess
- Production `.env`: `VITE_NFG_API_BASE=https://y666suf.com`, `VITE_HANGMAN_WS_PATH=/hangman/ws`
- Source: `hangman v2/iOS/app/` (not `hangman-v2/`)

## Quick build

```bash
cd ~/Documents/nfg-crash
git pull origin main
cd "hangman v2/iOS/app"
npm install && npm run build && npx cap sync ios
# Archive → releases/ipa/NFG-Hangman.ipa → install to iPhone
curl -s -H "X-Client-App: nfg-hangman" https://y666suf.com/api/mobile/hangman/state | head -c 400
```

**Mac work is done when IPA is in `releases/ipa/` and pushed to `main`.** Use `WINDOWS-CURSOR-PC-LATEST.md` on the PC for deploy/sideload.
