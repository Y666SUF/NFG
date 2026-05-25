# Windows Cursor — NFG Crash full functionality handoff

Paste everything below into a **new Cursor Agent chat** on your Windows PC after opening the repo.

---

## PROMPT START (copy from here)

You are on my **Windows game PC** in Cursor. Make the **live NFG Crash server** at **https://y666suf.com** match the latest MacBook work so the iOS app (build 52 on `com.yusufali.nfgcrash`) is fully functional.

### Repo

- **GitHub:** https://github.com/Y666SUF/NFG
- **Branch:** `emergent/ui-polish-2026` (not `main`)
- Live server folder is wherever we run Node for port **3847** (often `C:\Users\Yusef\test` or similar — find `index.js` + `game.js`).

### Step 1 — Sync repo on Windows

```powershell
cd C:\Users\Yusef\test
# or wherever the NFG repo lives
git fetch origin
git checkout emergent/ui-polish-2026
git pull origin emergent/ui-polish-2026
npm install
```

If the repo is not cloned yet:

```powershell
cd C:\Users\Yusef
git clone https://github.com/Y666SUF/NFG.git test
cd test
git checkout emergent/ui-polish-2026
npm install
```

### Step 2 — Deploy critical server fixes (REQUIRED for Entries + Last 5)

Update the **live** `server/game.js` on this PC (the copy the running process uses) with these changes from the pulled branch:

1. **openBets** — must stay visible during running/ended, not only betting:

```js
openBets: this.bets.size > 0 ? this.listOpenBets() : [],
```

NOT `openBets: this.phase === PHASE.BETTING ? this.listOpenBets() : []`.

2. **recentCrashes** — in constructor:

```js
this.recentCrashes = [];
```

In `getState()`:

```js
recentCrashes: [...this.recentCrashes],
```

In `_finishRound()` after crash point is set:

```js
const crashVal = Math.floor(resultCrash * 100) / 100;
this.recentCrashes.push(crashVal);
if (this.recentCrashes.length > 5) this.recentCrashes = this.recentCrashes.slice(-5);
```

See `docs/DEPLOY-SERVER-FOR-ENTRIES.md` in the repo for full context.

### Step 3 — Restart live server

Restart whatever runs the game (Electron launcher, `node server/index.js`, PM2, or `run-electron-cloudflare.bat`). Do **not** overwrite `data/points.live.json` or secrets from git.

### Step 4 — Verify production API

```powershell
curl https://y666suf.com/api/state
```

During a round when bets exist, `openBets` must be a **non-empty array**. `recentCrashes` should appear after crashes.

### What the iOS app already has (MacBook — do NOT rebuild on Windows)

iOS is Swift/Xcode on Mac only. Windows only maintains **server + tunnel**. The phone app expects:

| Feature | Server need | iOS (already on device build 52) |
|--------|-------------|----------------------------------|
| Entries panel | `openBets` fix above | Client cache + optimistic bet on place |
| Last 5 crashes strip | `recentCrashes` in state | Reads from API |
| Presence join/leave | `mobile-presence.js` routes + WS `presence_update` | Green door / red X toasts |
| Mobile bets | `POST /api/chat` with Bearer auth | `!amount mult` via SyncClient |
| Tax pot | `taxPot` in getState | UI row |
| Arcade / shop / chat | existing mobile-api routes | Wallet tab |

### Step 5 — Diff check

Compare running PC `game.js` vs `server/game.js` in the pulled branch. Report any other drift (mobile-api, index.js broadcast, presence). Apply missing pieces from the branch without wiping live player data.

### Constraints

- Never commit or push `data/points*.json`, `.env`, or secrets.
- Do not force-push `main`.
- If Mac has unpushed commits, note them — Windows should pull `emergent/ui-polish-2026` again after Mac runs `./scripts/sync-push-branch.sh`.

### Done when

1. Live `https://y666suf.com/api/state` shows `openBets` during running when bets exist.
2. `recentCrashes` populates after rounds.
3. Mobile bet from the app updates balance and appears in entries for all clients.
4. Short summary of files changed on PC and restart command used.

## PROMPT END
