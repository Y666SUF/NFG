# MacBook prompt — build NFG Hangman iOS app (copy everything below the line)

---

You are building the **NFG Hangman** iOS companion app for App Store / TestFlight. Match the **NFG Crash companion** layout and shared platform features, but the main game is Hangman (not crash betting).

## Repo context (sync this folder from Windows first)

Project root contains:

- `hangman v2/iOS/app/` — Capacitor + React companion (START HERE)
- `hangman v2/iOS/app/src/lib/nfgApi.js` — API client (already written)
- `hangman v2/iOS/app/src/App.jsx` — tabs: Play, Board, Chat, Account (already written; polish to match Crash)
- `server/` on Windows — Node platform **port 3847** (chat, link, presence, proxies Hangman)
- Hangman Python — **port 19876**, proxied at `/hangman/ws` and `/api/hangman/*` on the same public host

**Production API base:** `https://y666suf.com`  
**Hangman WebSocket:** `wss://y666suf.com/hangman/ws`  
**Never hardcode localhost in production builds.**

## App Store — separate app required

| | NFG Crash | NFG Hangman |
|---|-----------|-------------|
| Bundle ID | `com.nfg.crash` (or existing) | **`com.nfg.hangman`** |
| App Store listing | Its own | **Must be a second listing** |
| .ipa download | `/download/nfg-crash.ipa` | `/download/nfg-hangman.ipa` |
| Leaderboard | Crash `/api/leaderboard` | Hangman `/api/hangman/leaderboard` |
| Points | Crash `pointStore` | Hangman all-time JSON (separate) |

You **cannot** reuse one App Store app / one binary for both games. Shared: **app chat**, **online presence**, **!link** auth, **privacy/legal URLs**.

## UI requirements (match NFG Crash companion)

Dark cosmic theme: `#0b1020` background, cyan `#67e8f9` + purple `#a78bfa` accents, Segoe/Inter, pill LIVE dot (green when live).

### Top bar (all tabs)

- App name: **NFG Hangman**
- **LIVE** dot + label from `GET /api/mobile/platform/status` → `tiktokLive.isLive`
- **`{activeAppUsers} in apps`** from same endpoint (cross-app count)

### Bottom tabs (same order as Crash where possible)

1. **Play** — masked word, wrong count X/6, guessed letters, theme line, streamer @handle  
   - WebSocket `wss://…/hangman/ws` messages `type: "update"`  
   - **A–Z keyboard** → `POST /api/mobile/hangman/guess` with Bearer token (requires linked account)  
   - Same elimination rule: 6 wrong guesses = out for current word (server enforces; do not change rules)

2. **Board** — Hangman all-time top 15 from WS `alltime` or `GET /api/hangman/leaderboard`  
   - Subtitle: “Separate from NFG Crash”  
   - **Online now** list from presence heartbeat response / `presence_update` WS

3. **Chat** — identical UX to Crash companion  
   - `GET/POST /api/mobile/chat`  
   - WS on platform host: `type: "app_chat"`  
   - Header: “Shared across all NFG apps”  
   - No `!` commands in app chat

4. **Account** — `!link` flow  
   - `POST /api/mobile/link/start` → show `!link XXXXXX`  
   - Poll `GET /api/mobile/link/status/:code`  
   - Store token in localStorage key `nfg_session_token`  
   - Links (open in SFSafariView or external):  
     - https://y666suf.com/privacy  
     - https://y666suf.com/legal  
     - https://y666suf.com/sideload#hangman  

### Headers on every API call

```
Authorization: Bearer <token>   (when linked)
X-Device-Id: <stable uuid>
X-Client-App: nfg-hangman
```

Heartbeat every 20s: `POST /api/mobile/presence/heartbeat`

## Capacitor / Xcode steps

```bash
cd "hangman v2/iOS/app"
cp .env.example .env
# Edit .env:
#   VITE_NFG_API_BASE=https://y666suf.com
#   VITE_HANGMAN_WS_PATH=/hangman/ws

npm install
npm run build
npx cap add ios   # once
npx cap sync ios
npx cap open ios
```

In Xcode:

- **Bundle Identifier:** `com.nfg.hangman`
- **Display Name:** NFG Hangman
- **Version:** 1.0.0 (increment per upload)
- Enable **Privacy Manifest** / required usage strings if you add AdMob later
- **App Transport Security:** production uses HTTPS only (already in capacitor config)
- Archive → Distribute → App Store Connect **new app** record “NFG Hangman”

## App Store compliance checklist

- [ ] Privacy Policy URL in App Store Connect: `https://y666suf.com/privacy` (covers both apps; mentions Hangman)
- [ ] Support URL: `https://y666suf.com` or contact email support@y666suf.com
- [ ] Age rating: Hangman word game ~13+ (Crash is 17+ if simulated gambling)
- [ ] Screenshots: Play, Board, Chat, Account tabs
- [ ] Description states: virtual points only, no cash-out, optional TikTok link on live
- [ ] If using AdMob: ATT prompt, SKAdNetwork, privacy nutrition labels
- [ ] Export .ipa to `~/Downloads/NFG-Hangman.ipa` for website sideload

## Polish tasks for you on Mac

1. Refine `App.jsx` spacing/typography to pixel-match Crash companion if you have Crash Xcode project side-by-side.
2. Add safe-area padding for iPhone notch; test on physical device.
3. Haptic on keyboard tap (optional `Capacitor Haptics`).
4. Error states: platform down, Hangman WS down, not linked.
5. `Info.plist` human-readable permission strings if adding camera/mic (not required now).
6. App icon + launch screen assets in `ios/App/App/Assets.xcassets`.

## Verify before submit

```bash
curl -s https://y666suf.com/api/mobile/platform/status | head
curl -s https://y666suf.com/api/hangman/leaderboard | head
curl -I https://y666suf.com/download/nfg-hangman.ipa
```

On device: link on TikTok LIVE with `!link CODE`, send chat, guess letter, see LIVE dot when stream is live.

## Do NOT

- Point production build at `localhost`
- Merge Crash and Hangman into one bundle ID
- Send Crash `!b` or bet amounts to Hangman guess API
- Change 6-wrong-guess elimination logic

Deliver: working Xcode archive, TestFlight build, and `NFG-Hangman.ipa` in Downloads for the website download endpoint.
