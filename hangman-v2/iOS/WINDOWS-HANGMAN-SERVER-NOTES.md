# Windows server — NFG Hangman companion APIs

The Hangman iOS app (`com.nfg.hangman`) expects these on **https://y666suf.com** (port 3847 behind tunnel).

## Required endpoints

| Method | Path | Notes |
|--------|------|--------|
| GET | `/api/mobile/platform/status` | `tiktokLive`, `activeAppUsers`, `activeAppUserList` (cross-app) |
| GET | `/api/hangman/leaderboard` | Hangman all-time — **not** Crash `/api/balances` |
| POST | `/api/mobile/hangman/guess` | Bearer + `X-Device-Id` + `X-Client-App: nfg-hangman`, body `{ letter }` |
| GET/POST | `/api/mobile/chat` | Same as Crash |
| POST | `/api/mobile/presence/heartbeat` | Same as Crash |
| GET | `/api/mobile/presence/active` | Online list + superFan badges |
| POST | `/api/mobile/link/start` | TikTok verify |
| GET | `/api/mobile/link/status/:code` | Poll until verified |

## WebSockets

| URL | Messages |
|-----|----------|
| `wss://y666suf.com/hangman/ws` | `type: "update"` (game state), `type: "alltime"` (leaderboard) |
| `wss://y666suf.com` | `type: "app_chat"`, `type: "presence_update"` |

## Guess response (example shape)

```json
{
  "ok": true,
  "masked": "_ a _ _",
  "wrong": 2,
  "maxWrong": 6,
  "guessed": ["a", "e"],
  "correct": true,
  "eliminated": false,
  "won": false
}
```

Do **not** change 6-wrong elimination rules — app only displays server state.

## Website

- `/privacy`, `/legal`, `/sideload#hangman`
- Optional: host `NFG-Hangman.ipa` at `/download/nfg-hangman.ipa`

Copy shared mobile modules from Mac `nfg-crash/server/` (presence, chat, badges, wallet, auth).
