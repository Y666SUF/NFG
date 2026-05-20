# MacBook prompt — finalize NFG Crash + NFG Hangman iOS apps

**Copy everything below the line into Cursor on your MacBook.**

---

You are finishing **two separate App Store apps** that talk to the **Windows gaming PC** (already running). The PC repo is the source of truth for APIs and the Hangman companion UI.

| | NFG Crash | NFG Hangman |
|---|-----------|-------------|
| **Bundle ID** | `com.nfg.crash` | `com.nfg.hangman` |
| **Built on Mac** | Native Swift/Xcode (your existing project — **not** in this repo) | Capacitor in repo: `hangman v2/iOS/app/` |
| **Production API** | `https://y666suf.com` | Same |
| **Game WebSocket** | `wss://y666suf.com/` (Crash round state + `app_chat` + `presence_update`) | `wss://y666suf.com/hangman/ws` |
| **Leaderboard** | Crash balances / game leaderboard endpoints you already use | `GET /api/hangman/leaderboard` |
| **Points** | Crash `pointStore` / live points | Hangman all-time JSON (separate) |

**Do not** merge into one App Store listing or one bundle ID. **Do** share: app chat, presence (“X in apps”), `!link`, Super Fan badges, privacy/legal URLs.

**PC must be LIVE** on TikTok **@y666.suf** for `!link` testing.

---

## Part 0 — Sync repo on Mac

```bash
cd ~/Documents   # or your dev folder
git clone https://github.com/Y666SUF/NFG.git
cd NFG
git pull origin main
```

Confirm PC has pushed latest `main` (Hangman companion + `server/mobile-hangman.js` + platform status).

**Repo paths (note space in folder name):**

- `hangman v2/iOS/app/` — Hangman companion (Capacitor + React)
- `server/` — reference for mobile API contracts (PC runs this)
- `docs/MAC_IOS_NFG_HANGMAN_BUILD_PROMPT.md` — Hangman UI detail
- `_import_Y666SUF_website/frontend/` — marketing site (optional local build)

There is **no** Crash Swift project in the repo — use your existing **NFG Crash** Xcode project on the Mac.

---

## Part 1 — NFG Hangman (Capacitor) — build & ship

### 1A. Environment (production only)

```bash
cd "hangman v2/iOS/app"
cp .env.example .env
```

Edit `.env`:

```env
VITE_NFG_API_BASE=https://y666suf.com
VITE_HANGMAN_WS_PATH=/hangman/ws
```

Never ship TestFlight/App Store with `localhost` in `.env`.

### 1B. Build & open Xcode

```bash
npm install
npm run build
npx cap sync ios
npx cap open ios
```

First time only: `npx cap add ios` before sync.

### 1C. Xcode settings

| Setting | Value |
|---------|--------|
| Bundle Identifier | `com.nfg.hangman` |
| Display Name | NFG Hangman |
| Version | 1.0.0+ (increment each upload) |
| Signing | Your Apple Developer team |
| ATS | HTTPS only (Capacitor `cleartext: false` already) |

Add **App Icon** + **Launch Screen** in `ios/App/App/Assets.xcassets`.

### 1D. Required headers on every API call

```
Authorization: Bearer <token>     # after !link
X-Device-Id: <stable UUID>        # persist in Keychain or localStorage
X-Client-App: nfg-hangman
```

Heartbeat every **20s**: `POST /api/mobile/presence/heartbeat` (same body as Crash; set `X-Client-App: nfg-hangman`).

### 1E. Tabs (polish to match Crash companion)

Source already in `src/App.jsx`, `GuessKeyboard.jsx`, `ChatPanel.jsx`, `OnlinePanel.jsx`, `AccountPanel.jsx`, `src/lib/nfgApi.js`.

1. **Play** — `wss://y666suf.com/hangman/ws` → `type: "update"` (masked word, wrong/maxWrong, guessed). Keyboard → `POST /api/mobile/hangman/guess` body `{ "letter": "a" }`. **6 wrong = out** (server enforces via `process_chat_message` — do not change rules).
2. **Board** — `GET /api/hangman/leaderboard` or WS `alltime`. Subtitle: separate from Crash.
3. **Chat** — `GET/POST /api/mobile/chat`; platform WS `type: "app_chat"`. No `!` commands in app.
4. **Account** — `POST /api/mobile/link/start` → viewer types `!link CODE` on TikTok LIVE → poll `GET /api/mobile/link/status/:code` → store token as `nfg_session_token`. Links: `/privacy`, `/legal`, `/sideload#hangman`.

Top bar: **LIVE** from `GET /api/mobile/platform/status` → `tiktokLive.isLive`; **{activeAppUsers} in apps** from same response.

### 1F. Polish checklist

- [ ] Safe-area / notch padding on all tabs
- [ ] Error states: platform down, Hangman WS down, not linked (401 on guess)
- [ ] Optional: Capacitor Haptics on key tap
- [ ] Pixel-match Crash companion typography/colors (`#0b1020`, cyan `#67e8f9`, purple `#a78bfa`)
- [ ] AdMob later: ATT, SKAdNetwork, privacy manifest updates

### 1G. Archive & App Store Connect

1. Product → **Archive** → Distribute → **App Store Connect**
2. Create **new** app record: **NFG Hangman**, bundle `com.nfg.hangman`
3. Privacy Policy URL: `https://y666suf.com/privacy`
4. Support URL: `https://y666suf.com` or `support@y666suf.com`
5. Age rating: word game ~**13+** (Crash listing stays **17+** if simulated gambling)
6. Screenshots: Play, Board, Chat, Account
7. Description: virtual points only, no cash-out; optional TikTok link while LIVE

Export IPA for website sideload:

```bash
# After archive, export Ad Hoc or copy from Organizer
cp ~/path/to/NFG-Hangman.ipa ~/Downloads/NFG-Hangman.ipa
```

---

## Part 2 — NFG Crash (native Swift) — verify & ship

Use your **existing** Crash Xcode project (`com.nfg.crash`). Align with the PC server below (no repo path — update your Swift networking layer).

### 2A. Production base URL

```
https://y666suf.com
```

### 2B. Headers

```
Authorization: Bearer <token>
X-Device-Id: <stable UUID>
X-Client-App: nfg-crash
```

### 2C. Endpoints to verify (against LIVE PC)

| Feature | Method | Path |
|---------|--------|------|
| Platform / LIVE | GET | `/api/mobile/platform/status` |
| Crash round | GET | `/api/mobile/status` |
| Wallet | GET | `/api/mobile/me` |
| Link start | POST | `/api/mobile/link/start` |
| Link poll | GET | `/api/mobile/link/status/:code` |
| Chat | GET/POST | `/api/mobile/chat` |
| Presence | POST | `/api/mobile/presence/heartbeat` |
| Rewarded ad | GET/POST | `/api/mobile/rewarded-ad/status`, `/claim` (10k pts, no cooldown) |
| Store (if used) | GET/POST | `/api/mobile/store/products`, `/test-purchase` |

### 2D. WebSocket (Crash)

Connect to **`wss://y666suf.com/`** (root path — not `/hangman/ws`).

Listen for:

- `type: "state"` — round phase, multiplier
- `type: "app_chat"` — shared in-app chat
- `type: "presence_update"` — `{ activeAppUsers, activeAppUserList }`
- Existing game events you already handle

### 2E. Crash-only rules

- Bets / cash-out use Crash server logic only — **do not** call Hangman guess API
- TikTok chat on PC uses prefixed Spotify: `!csong`, `!cqueue` (not bare `!song`)
- Rewarded ad: **10,000** points per claim, unlimited (`COOLDOWN_MS = 0` on server)

### 2F. App Store Connect (Crash)

- Bundle `com.nfg.crash` — **separate** listing from Hangman
- Same privacy URL: `https://y666suf.com/privacy`
- Export: `~/Downloads/NFG-Crash.ipa` for sideload page

---

## Part 3 — Device testing (cellular, not Mac Wi‑Fi only)

With **PC running** `run-electron-cloudflare.bat` and **@y666.suf LIVE**:

### Hangman app

1. Account → Start link → type `!link XXXXXX` in TikTok chat
2. Play → tap letter → see masked word update
3. Board → all-time names load
4. Chat → message appears in Crash app too (shared)
5. Top bar → LIVE green; “N in apps” when both apps open

### Crash app

1. Same link flow (shared `mobile-sessions.json` on PC)
2. Bet / cash-out on LIVE round
3. Watch rewarded ad → +10k balance
4. Chat + presence with Hangman app open

### curl sanity (Mac terminal)

```bash
curl -s https://y666suf.com/api/mobile/platform/status | python3 -m json.tool | head -40
curl -s https://y666suf.com/api/hangman/leaderboard | python3 -m json.tool | head -20
curl -I https://y666suf.com/privacy
curl -I https://y666suf.com/download/nfg-hangman.ipa
curl -I https://y666suf.com/download/nfg-crash.ipa
```

---

## Part 4 — Deliver IPAs to Windows PC (website downloads)

The PC serves IPAs from `%USERPROFILE%\Downloads\` (or env overrides).

**Option A — AirDrop / cloud / USB**

Copy to Windows:

- `NFG-Crash.ipa` → `C:\Users\<you>\Downloads\NFG-Crash.ipa`
- `NFG-Hangman.ipa` → `C:\Users\<you>\Downloads\NFG-Hangman.ipa`

**Option B — git (only if IPAs are small enough for your workflow; usually avoid)**

Prefer manual copy; PC `.gitignore` excludes `*.ipa`.

Restart PC launcher or Node after copying — server logs:

```
iOS download [crash]: /download/nfg-crash.ipa ← ...
iOS download [hangman]: /download/nfg-hangman.ipa ← ...
```

Verify in browser: `https://y666suf.com/sideload`

---

## Part 5 — Push iOS source changes back to GitHub

If you edited files under `hangman v2/iOS/app/`:

```bash
cd ~/Documents/NFG
git add "hangman v2/iOS/app"
git commit -m "iOS: Hangman companion polish and production config"
git push origin main
```

On **Windows PC** afterward:

```powershell
cd C:\Users\Yusef\test
git pull origin main
.\run-electron-cloudflare.bat
```

Crash Swift project: commit in **its own repo** if separate; only API contract must stay compatible with `server/mobile-*.js` on NFG monorepo.

---

## Part 6 — Report back (Mac)

Reply with:

1. TestFlight build numbers for **Crash** and **Hangman**
2. App Store Connect app IDs / bundle IDs confirmed
3. Screenshot of device test: link + guess + shared chat
4. Whether `https://y666suf.com/download/nfg-hangman.ipa` works after IPA copy to PC
5. Any Swift/Capacitor changes you still need on PC server

---

## Do NOT

- Point production builds at `localhost` or LAN IP
- Use one bundle ID for both games
- Send Crash bets to `/api/mobile/hangman/guess`
- Change Hangman 6-wrong elimination or letter rules client-side
- Use bare `!song` / `!queue` in TikTok (wrong game may respond)

---

## Server reference (PC — read only)

Hangman mobile guess chain:  
`POST /api/mobile/hangman/guess` → Python `POST /api/hangman/app/guess` → **`chat_bridge.process_chat_message`**

Shared chat/presence: `server/mobile-chat.js`, `server/mobile-presence.js`, `server/mobile-auth.js`

Platform status: `server/mobile-platform.js`, `server/mobile-hangman.js`
