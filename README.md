# NFG Crash — iOS + shared live server

Your **TikTok live crash game** (`Documents/test`) and this **iOS app** share one account system: the same `points.live.json` on your **Windows PC game server**.

```
TikTok Live ──► PC game server (:3847) ◄── iOS app (same /api/chat)
                      │
                 points.live.json
```

## Quick start

### 1. Windows PC (master data while streaming / 24/7)

Copy your game folder to the PC (or keep developing on Mac and deploy to PC).

```bash
cd path/to/tiktok-live-crash-game
npm install
npm start
```

- Allow port **3847** in Windows Firewall (private network).
- Note your PC LAN IP (`ipconfig` → IPv4, e.g. `192.168.1.50`).
- Data lives in `data/points.live.json` — back this up.

### 2. iOS app (Mac)

```bash
open /Users/y666suf/Documents/nfg-crash/ios/NFGCrash.xcodeproj
```

1. Run on simulator or iPhone (⌘R).
2. **Settings** → Server: `http://<PC_IP>:3847`
3. **TikTok username** — must match live chat (no `@`).
4. **Save & connect**

### 3. Link TikTok (anti-impersonation)

Users **cannot** type a username manually. They must:

1. Open the app → **Get link code** (e.g. `A1B2C3`)
2. Comment on your **live** stream from the real TikTok app: `!link A1B2C3`
3. The PC server sees that comment via TikTok Live (same as game bets) and issues a secure session token
4. The iPhone stores the token; all bets use the verified account only

Copy the updated `server/mobile-auth.js` to your Windows PC with the rest of the game.

### 4. Play

- Bets use the same commands as chat: `!100 2.5`, `!30k 2`, `!all 2`
- Balance, XP, missions, and wins are stored on the **PC server**
- When the PC is offline, actions are **queued** and sent when you reconnect

### TikTok Login Kit (optional later)

For linking **without** going live, you can apply for [TikTok Login Kit](https://developers.tiktok.com/doc/login-kit-overview) (OAuth). That needs a TikTok developer app review. The `!link` flow works today with your existing live setup.

## Mac copy of the game

Your full game source is at:

`/Users/y666suf/Documents/test`

Run locally for testing:

```bash
cd /Users/y666suf/Documents/test
npm start
```

Then point the iOS app at `http://<this-mac-lan-ip>:3847`.

For production, run the server on the **same PC you use for TikTok live** so points stay in one place.

## API used by iOS

| Endpoint | Purpose |
|----------|---------|
| `GET /api/mobile/status` | Server health |
| `GET /api/state` | Live round (WebSocket also pushes `state`) |
| `POST /api/chat` | Bets & commands (`source: "mobile"`) |
| `GET /api/economy/profile/:user` | Balance & level |

WebSocket: `ws://<host>:3847` (root path, same as browser overlay).

## Repo layout

| Path | Purpose |
|------|---------|
| `ios/` | iOS SwiftUI app |
| `../test/` | Full Node + TikTok game (on your Mac) |
| `sync-server/` | Legacy simple bridge (optional; game already serves :3847) |
