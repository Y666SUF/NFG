# NFG Hangman — iOS companion (Capacitor)

Separate App Store app from **NFG Crash** (`com.nfg.hangman`).

## Setup

```bash
cd "hangman v2/iOS/app"
cp .env.example .env   # production URLs only
npm install
npm run build
npx cap add ios        # first time only
npx cap sync ios
npx cap open ios
```

## Production env

```
VITE_NFG_API_BASE=https://y666suf.com
VITE_HANGMAN_WS_PATH=/hangman/ws
```

- Game WebSocket: `wss://y666suf.com/hangman/ws` (`type: "update"`, `"alltime"`)
- Platform WebSocket: `wss://y666suf.com` (`app_chat`, `presence_update`)
- Platform status: `GET /api/mobile/platform/status`

## Xcode / App Store

1. Open `ios/App/App.xcworkspace`
2. Target **NFG Hangman** → Bundle ID **com.nfg.hangman**, Display Name **NFG Hangman**
3. Signing team → Archive → Distribute
4. New app in App Store Connect (not Crash)
5. Privacy URL: https://y666suf.com/privacy
6. Export IPA to `~/Downloads/NFG-Hangman.ipa` for https://y666suf.com/download/nfg-hangman.ipa

## TestFlight checklist

- [ ] `!link` on @y666.suf LIVE
- [ ] Play tab: keyboard guess, 6 wrong = out
- [ ] Board: Hangman leaderboard + online list
- [ ] Chat: shared NFG apps, no `!` commands
- [ ] LIVE dot + in-apps count in top bar

## Server

Windows PC must expose hangman mobile routes and platform status (see `nfg-crash` server docs or sync from Mac).
