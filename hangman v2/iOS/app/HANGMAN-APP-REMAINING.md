# NFG Hangman — what’s left to be fully functional

## Already in the repo (Mac)

- React companion UI (`hangman v2/iOS/app`) — Play, Board, Chat, Account
- Production API base + `X-Client-App: nfg-hangman` in `src/lib/nfgApi.js`
- Hangman WebSocket + guess API wired in the client
- Shared mobile stack on PC: presence, chat, Super Fan, platform status, `mobile-hangman.js`
- Brand assets: `public/nfg-hangman-logo.svg`, `public/nfg-hangman-app-icon.svg`

## Mac — required before testers can use it

1. **Environment** — copy `.env.example` → `.env` with production only:
   - `VITE_NFG_API_BASE=https://y666suf.com`
   - `VITE_HANGMAN_WS_PATH=/hangman/ws`
2. **Build web bundle** — from `hangman v2/iOS/app`:
   - `npm install`
   - `npm run build`
3. **Capacitor iOS** (not in repo yet until you run):
   - `npx cap add ios` (first time)
   - `npx cap sync ios`
4. **App icon in Xcode** — export 1024×1024 PNG from `public/nfg-hangman-app-icon.svg` (Preview → Export, or `scripts/export-hangman-icon.sh` if `qlmanage` is available), set **App Icon** in `ios/App/App/Assets.xcassets`.
5. **Archive & IPA** — Xcode → Product → Archive → Distribute → copy to `~/Downloads/NFG-Hangman.ipa`.
6. **Git** — commit logo + UI changes, `git push origin main` so PC can `git pull`.

## PC — required for live play

1. `git pull origin main` after Mac push.
2. Game root running: `.\run-electron-cloudflare.bat` (port **3847**, tunnel **https://y666suf.com**).
3. Confirm routes:
   - `GET /api/mobile/platform/status`
   - `POST /api/mobile/hangman/guess` (6 wrong = out, same as desktop)
   - `wss://y666suf.com/hangman/ws` (`update`, `alltime`)
4. Drop IPAs for sideload (if using website downloads):
   - `C:\Users\Yusef\Downloads\NFG-Hangman.ipa` → served as `/download/nfg-hangman.ipa`
5. **TikTok LIVE** on @y666.suf — Hangman round active on PC; apps show LIVE + word state over WS.

## User flow to verify end-to-end

| Step | Crash | Hangman |
|------|-------|---------|
| Install IPA | NFG-Crash.ipa | NFG-Hangman.ipa |
| Open on cellular (not only Wi‑Fi) | ✓ | ✓ |
| Top bar LIVE when stream live | ✓ | ✓ |
| `!link` in TikTok chat | links account | links account |
| Game action | bet / cashout / ads | letter guess → PC chain |
| App chat + online list | ✓ | ✓ |

## Optional polish (not blocking)

- TestFlight for both apps
- Push notification when new Hangman word starts
- Use `GET /api/hangman/leaderboard` for a richer Board tab (WS `alltime` already feeds top 15)
