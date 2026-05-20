# Windows PC setup — NFG Crash + Hangman + Cloudflare

## GAME_ROOT

On this machine the live project **is the repo**:

```
GAME_ROOT = C:\Users\Yusef\test
```

Optional sync clone (same content after pull):

```powershell
cd $HOME\Documents
git clone https://github.com/Y666SUF/NFG.git
cd NFG
git pull origin main
```

If you use a separate clone, copy `server\mobile-*.js` and `server\hangman-*.js` into `GAME_ROOT\server\` — **do not overwrite** merged `tiktok-bridge.js` / `mobile-auth.js` without diffing.

## Start everything

```powershell
cd C:\Users\Yusef\test
git pull origin main
Copy-Item -Force "releases\ipa\NFG-Crash.ipa"    "$env:USERPROFILE\Downloads\NFG-Crash.ipa"    -ErrorAction SilentlyContinue
Copy-Item -Force "releases\ipa\NFG-Hangman.ipa" "$env:USERPROFILE\Downloads\NFG-Hangman.ipa" -ErrorAction SilentlyContinue
.\scripts\test-hangman-mobile-guess.ps1
.\run-electron-cloudflare.bat
```

- **Crash + platform:** Node port **3847** (`server\index.js`)
- **Hangman TikTok game:** Python port **19876** (auto-started; proxied at `/api/hangman/*`, `wss://y666suf.com/hangman/ws`)
- **Tunnel:** `y666suf.com` → `http://127.0.0.1:3847`

Skip Hangman spawn: `$env:NFG_START_HANGMAN='0'`

## Mobile APIs (port 3847)

| Feature | Route |
|---------|--------|
| Platform status | `GET /api/mobile/platform/status` |
| Crash status | `GET /api/mobile/status` |
| Hangman guess (app) | `POST /api/mobile/hangman/guess` → Python `process_chat_message` |
| Hangman board | `GET /api/hangman/leaderboard` |
| Shared chat | `GET/POST /api/mobile/chat` |
| Presence | `POST /api/mobile/presence/heartbeat` |
| TikTok link | `POST /api/mobile/link/start` |
| Rewarded ad | 10k pts, `COOLDOWN_MS = 0` |

Hangman guess path: **`chat_bridge.process_chat_message`** (same as TikTok letter / `!word`).

## Verify (PowerShell)

```powershell
$base = "http://127.0.0.1:3847"
curl "$base/api/mobile/platform/status"
curl "$base/api/mobile/status"
curl "$base/api/hangman/leaderboard"
curl "$base/api/mobile/presence/active"
curl -Method POST "$base/api/mobile/presence/heartbeat" -Headers @{ "X-Device-Id" = "pc-test-1" }
curl "$base/privacy"
curl "https://y666suf.com/api/mobile/platform/status"
```

Hangman guess + chat hardening smoke test:

```powershell
.\scripts\test-hangman-mobile-guess.ps1
```

See `WINDOWS-CURSOR-HANGMAN-GUESS-AND-CHAT-FINALIZE.md` if guess kills Electron.
```

## Legal pages

- Static fallback: `website/privacy.html`, `website/legal.html`
- Production host: React build in `_import_Y666SUF_website/frontend` (served when built)

```powershell
cd C:\Users\Yusef\test\_import_Y666SUF_website\frontend
corepack yarn install
corepack yarn build
```

## Mac sync

```powershell
cd C:\Users\Yusef\test
git pull origin main
# restart run-electron-cloudflare.bat
```

## iOS apps (built on Mac)

| App | Bundle ID |
|-----|-----------|
| NFG Crash | `com.nfg.crash` |
| NFG Hangman | `com.nfg.hangman` |

TikTok LIVE for linking: **@y666.suf** on this PC.

## MacBook (iOS apps)

Copy-paste prompt for Cursor on Mac: **`docs/MAC_IOS_FINALIZE_PROMPT.md`**

Hangman-only build detail: **`docs/MAC_IOS_NFG_HANGMAN_BUILD_PROMPT.md`**

After Mac archives IPAs, copy into repo then sync to Downloads:

```
releases\ipa\NFG-Crash.ipa
releases\ipa\NFG-Hangman.ipa
```

Then:

```powershell
.\scripts\sync-ipa-to-downloads.ps1
```

Or copy straight to `%USERPROFILE%\Downloads\`.

Optional env overrides: `NFG_IPA_FILE`, `NFG_HANGMAN_IPA_FILE`

Then restart `run-electron-cloudflare.bat` and check `https://y666suf.com/sideload`

## Push PC server fixes to GitHub (for Mac pull)

```powershell
cd C:\Users\Yusef\test
git add server/mobile-hangman.js server/mobile-api.js server/mobile-platform.js "hangman v2/server.py" WINDOWS-PC-SETUP.md docs/MAC_IOS_FINALIZE_PROMPT.md
git commit -m "Mobile: Hangman API module, platform status, Mac finalize prompt"
git push origin main
```

Do not commit `data/gift-ledger.jsonl` or live runtime files.
