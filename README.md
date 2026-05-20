# NFG Platform

Monorepo for **NFG Crash**, **Hangman v2**, shared mobile companion APIs, and the [y666suf.com](https://y666suf.com) marketing site.

## Repository layout

| Path | Description |
|------|-------------|
| `server/` | Node platform (port **3847**): Crash game, TikTok bridge, mobile chat/link/presence, IPA downloads, Hangman proxy |
| `public/` | Crash stream UI (Electron / browser) |
| `electron/` | Desktop launcher + Cloudflare tunnel |
| `hangman v2/` | Python Hangman server (port **19876**), TikTok LIVE, all-time leaderboard |
| `hangman v2/iOS/app/` | Capacitor companion app source (NFG Hangman) |
| `_import_Y666SUF_website/frontend/` | React marketing site (build → served on 3847) |
| `docs/` | Build guides (e.g. Mac iOS prompt) |

## Quick start (Windows)

```bat
run-electron-cloudflare.bat
```

- Crash + website: `https://y666suf.com` (tunnel → localhost:3847)
- Hangman WebSocket (proxied): `wss://y666suf.com/hangman/ws`
- Hangman starts automatically on port **19876** unless `NFG_START_HANGMAN=0`

## Spotify chat commands (no clash)

Both games can run on the same machine; commands are **prefixed**:

| Game | Queue song | Examples |
|------|------------|----------|
| **NFG Crash** | `!csong` `!cqueue` `!caddsong` | `!crashsong`, `!crashqueue` |
| **NFG Hangman** | `!hsong` `!hqueue` `!haddsong` | `!hangmansong`, `!hangmanqueue` |

Bare `!song` / `!queue` / `!addsong` are **not** accepted (viewers get a hint). Hangman allowlist: `!hqueueallow` / `!hqueuedeny` / `!hqueuelist`.

## Mobile apps (shared platform)

- Auth: `!link CODE` on TikTok LIVE → `data/mobile-sessions.json`
- Chat: `POST /api/mobile/chat` (shared across Crash + Hangman apps)
- Presence: `POST /api/mobile/presence/heartbeat` with `X-Client-App: nfg-crash` or `nfg-hangman`
- Status: `GET /api/mobile/platform/status`

## iOS downloads

| App | URL | Env override |
|-----|-----|----------------|
| NFG Crash | `/download/nfg-crash.ipa` | `NFG_IPA_FILE` |
| NFG Hangman | `/download/nfg-hangman.ipa` | `NFG_HANGMAN_IPA_FILE` |

Place `.ipa` files in `%USERPROFILE%\Downloads\` or set env vars.

## App Store

**Separate listings** — `com.nfg.crash` vs `com.nfg.hangman`.

| Doc | Use |
|-----|-----|
| `docs/MAC_IOS_FINALIZE_PROMPT.md` | **MacBook** — finalize both apps + TestFlight + IPA handoff |
| `docs/MAC_IOS_NFG_HANGMAN_BUILD_PROMPT.md` | Hangman UI/API detail |
| `WINDOWS-PC-SETUP.md` | **This PC** — ports, tunnel, verify curls |

## Environment (optional)

```env
PORT=3847
HANGMAN_PORT=19876
NFG_PLATFORM_URL=http://127.0.0.1:3847
NFG_INTERNAL_SECRET=nfg-dev-internal
NFG_IPA_FILE=
NFG_HANGMAN_IPA_FILE=
```

Copy `hangman v2/iOS/app/.env.example` → `.env` for companion builds.

## License

Proprietary — Y666.SUF / NFG Games.
