# Hangman iOS Port Workspace

This folder contains a standalone iOS-ready client for your portrait Hangman UI.

It is intentionally separate from your existing desktop/Electron setup in `app-v2`.

## What this includes

- `app/` - mobile-first React + Vite client
- Capacitor config so the app can be wrapped as a native iOS app
- Environment-based backend websocket URL (no localhost assumptions)

## Architecture

- **NFG platform (port 3847):** shared app chat, `!link`, online presence, live status — same as NFG Crash companion
- **Hangman game (port 19876):** Python `server.py` — board, TikTok, all-time leaderboard (separate from Crash points)
- **Public URL:** one host proxies `/hangman/ws` and `/api/hangman/*` to Hangman when using `run-electron.bat`

## Quick start (Windows/dev check)

From `iOS/app`:

1. Install deps:
   - `npm install`
2. Configure backend:
   - copy `.env.example` to `.env`
   - `VITE_NFG_API_BASE=http://127.0.0.1:3847` (or `https://y666suf.com`)
   - `VITE_HANGMAN_WS_PATH=/hangman/ws` (proxied on the same host)
3. Run:
   - `npm run dev`

## iOS build path (Mac required)

From `iOS/app` on macOS:

1. `npm install`
2. `npm run build`
3. `npx cap add ios`
4. `npm run cap:sync`
5. `npm run cap:open:ios`
6. In Xcode, choose a team/signing profile and run on simulator/device.

## Notes

- If your backend is not public yet, use a tunnel during testing.
- App Store deployment requires Apple Developer Program enrollment.
- Keep TikTok and game orchestration server-side; the iOS app should consume websocket updates only.
