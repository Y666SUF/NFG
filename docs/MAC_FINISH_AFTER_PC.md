# MacBook prompt — finish NFG Crash + Hangman apps (PC server is ready)

**Copy everything below the line into Cursor on your Mac.**

---

You are finishing **two App Store apps** against the **Windows PC** that already runs the full NFG platform. The PC repo is synced on GitHub; server fixes for **Hangman guess crash** and **app chat labels** are on `main`.

| | NFG Crash | NFG Hangman |
|---|-----------|-------------|
| Bundle ID | `com.nfg.crash` | `com.nfg.hangman` |
| Mac project | Your existing **native Swift** Xcode project | Repo: `hangman v2/iOS/app/` (Capacitor) |
| API base | `https://y666suf.com` | Same |
| WS | `wss://y666suf.com/` (state, `app_chat`, `presence_update`) | `wss://y666suf.com/hangman/ws` |
| Client header | `X-Client-App: nfg-crash` | `X-Client-App: nfg-hangman` |

**PC must be LIVE** on TikTok **@y666.suf** for `!link` and guess tests.

---

## Part 0 — Sync repo on Mac

```bash
cd ~/Documents/nfg-crash
# or: cd ~/Documents/NFG
git pull origin main
git log -1 --oneline
```

Confirm recent commits mention: Hangman guess hardening, `mobile-app-labels.js`, Electron Hangman window.

**Repo folder note:** Windows uses `hangman v2/` (space). Same on Mac.

---

## Part 1 — NFG Hangman (Capacitor) — build & TestFlight

```bash
cd "hangman v2/iOS/app"
cp .env.example .env
```

Production `.env`:

```env
VITE_NFG_API_BASE=https://y666suf.com
VITE_HANGMAN_WS_PATH=/hangman/ws
```

```bash
npm install
npm run build
npx cap sync ios
npx cap open ios
```

**Xcode**

- Bundle ID: `com.nfg.hangman`
- Display name: **NFG Hangman**
- Archive → App Store Connect → **new** app listing (not Crash)

**App behavior checklist**

- [ ] Top bar: LIVE dot + `{activeAppUsers} in apps` from `GET /api/mobile/platform/status`
- [ ] Play: WS `/hangman/ws` + `POST /api/mobile/hangman/guess` with Bearer (linked user)
- [ ] Board: `GET /api/hangman/leaderboard`
- [ ] Chat: `GET/POST /api/mobile/chat` — show **`appLabel`** (NFG Crash / NFG Hangman) + `displayName` (already in `ChatPanel.jsx` on `main`)
- [ ] Account: `!link` flow; links to `/privacy`, `/legal`, `/sideload#hangman`
- [ ] Headers on every call: `Authorization`, `X-Device-Id`, `X-Client-App: nfg-hangman`
- [ ] Heartbeat every 20s: `POST /api/mobile/presence/heartbeat`

**Device test (cellular, not Mac Wi‑Fi only)**

1. PC running `run-electron-cloudflare.bat` (Crash + Hangman + tunnel)
2. Link on LIVE: `!link XXXXXX`
3. Guess one letter — must get JSON (`masked`, `wrong`, `maxWrong: 6`); **must not** kill PC Electron
4. Send chat — appears in Crash app / stream app chat with **`appLabel`**

Export IPA for website:

```bash
cp ~/path/to/export/NFG-Hangman.ipa ~/Downloads/NFG-Hangman.ipa
```

Copy to Windows repo (preferred):

```bash
# After export from Xcode Organizer
scp NFG-Hangman.ipa pc:C:/Users/Yusef/test/releases/ipa/NFG-Hangman.ipa
scp NFG-Crash.ipa    pc:C:/Users/Yusef/test/releases/ipa/NFG-Crash.ipa
```

Or AirDrop/USB to `releases\ipa\` on the PC. PC runs `.\scripts\sync-ipa-to-downloads.ps1` then `run-electron-cloudflare.bat`.

---

## Part 2 — NFG Crash (Swift) — verify & ship

Open your **existing** Crash Xcode project (`com.nfg.crash`). Point production API at **`https://y666suf.com`**.

**Update chat UI** to match server (if not done):

- Each `app_chat` / chat list row shows:
  - `displayName` (from server / pointStore)
  - `appLabel` string: **"NFG Crash"** or **"NFG Hangman"** (not raw `nfg-hangman`)
  - Super Fan badge when `superFan` is true

**Endpoints** (verify against LIVE PC):

| Feature | Path |
|---------|------|
| Platform | `GET /api/mobile/platform/status` |
| Crash round | `GET /api/mobile/status` |
| Wallet | `GET /api/mobile/me` |
| Link | `POST /api/mobile/link/start`, `GET /api/mobile/link/status/:code` |
| Chat | `GET/POST /api/mobile/chat` |
| Presence | `POST /api/mobile/presence/heartbeat` |
| Rewarded ad | `GET/POST /api/mobile/rewarded-ad/*` (10k, no cooldown) |

**WebSocket:** `wss://y666suf.com/` — listen for `app_chat`, `presence_update`, `state`.

Archive → TestFlight → App Store (separate listing from Hangman).

Export: `~/Downloads/NFG-Crash.ipa` → copy to Windows `C:\Users\Yusef\Downloads\NFG-Crash.ipa`.

---

## Part 3 — App Store Connect (both apps)

| Field | Value |
|-------|--------|
| Privacy Policy | `https://y666suf.com/privacy` |
| Support | `https://y666suf.com` or support@y666suf.com |
| Crash age | 17+ if simulated gambling |
| Hangman age | 13+ word game |
| Description | Virtual points only; no cash-out; optional TikTok link on LIVE |

Screenshots: Play, Board, Chat, Account (Hangman); your Crash tabs.

---

## Part 4 — Push Mac-only changes back

```bash
cd ~/Documents/nfg-crash
git add "hangman v2/iOS/app"   # if you changed Capacitor sources
git commit -m "iOS: Hangman companion production build and chat appLabel UI"
git push origin main
```

Crash Swift: commit in **Crash repo** if separate; keep API contract compatible.

---

## Part 5 — Verify from Mac terminal

```bash
curl -s https://y666suf.com/api/mobile/platform/status | head -c 400
curl -s https://y666suf.com/api/hangman/leaderboard | head -c 200
curl -I https://y666suf.com/privacy
curl -I https://y666suf.com/download/nfg-hangman.ipa
curl -I https://y666suf.com/download/nfg-crash.ipa
```

---

## Part 6 — Report back

1. TestFlight build numbers (Crash + Hangman)
2. Screenshot: linked guess + shared chat with `appLabel`
3. Confirm `https://y666suf.com/download/nfg-*.ipa` after IPA copied to PC Downloads
4. Any Swift/Capacitor changes still needed on PC server

---

## Do NOT

- Production builds pointing at `localhost`
- One bundle ID for both games
- Crash bets → `/api/mobile/hangman/guess`
- Change Hangman 6-wrong elimination client-side

## PC reference (already done)

- `GAME_ROOT`: `C:\Users\Yusef\test`
- Launcher: `run-electron-cloudflare.bat` (Crash + Hangman Electron + Cloudflare)
- Smoke test: `scripts/test-hangman-mobile-guess.ps1` → **PASS**
- Guess chain: `process_chat_message` in `hangman v2/chat_bridge.py`
