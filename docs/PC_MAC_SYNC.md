# PC ↔ MacBook sync (one repo, no duplicate prompts)

Use **GitHub** as the link between machines. Both computers work on the **same repo**:

**https://github.com/Y666SUF/NFG**

After you push from one machine and pull on the other, Cursor already has the same code — you do **not** need to re-run long setup prompts on both sides.

---

## One-time Mac setup

If the Mac does not have the repo yet:

```bash
cd ~/Documents
git clone https://github.com/Y666SUF/NFG.git
cd NFG
chmod +x scripts/sync-*.sh
npm install
```

Pick any folder you like (`~/Documents/NFG` or `~/Documents/nfg-crash`); the remote URL matters, not the folder name.

**NFG Crash (native Swift)** — if that Xcode project lives outside this repo, either:

- move shared server/mobile contract changes into `NFG` and open Swift from there, or  
- give the Swift repo the **same GitHub remote pattern** (clone + `sync-push` / `sync-pull` scripts).

---

## Daily workflow

| When you finish on… | Run |
|---------------------|-----|
| **PC (Windows)** | `.\scripts\sync-push.ps1 "describe your change"` |
| **MacBook** | `./scripts/sync-pull.sh` |
| **MacBook** | `./scripts/sync-push.sh "describe your change"` |
| **PC (Windows)** | `.\scripts\sync-pull.ps1` |

**Before** you start work on either machine:

```powershell
# PC
.\scripts\sync-pull.ps1
```

```bash
# Mac
./scripts/sync-pull.sh
```

That keeps you on the latest `main` and avoids “I fixed it on PC but Mac is old” problems.

---

## What Git syncs vs what stays local

| Syncs via GitHub | Stays on PC only (not in git) |
|------------------|-------------------------------|
| `server/`, `hangman v2/` code | `data/points.live.json` (player balances) |
| `hangman v2/iOS/app/` Capacitor source | `data/backups/`, `data/shields.json` |
| Scripts, docs, website source | `.env`, TikTok secrets |
| `package.json`, configs | `node_modules/` (run `npm install` after pull) |

Player data and live TikTok config should **not** be pushed — `.gitignore` already excludes them.

---

## iOS builds (Mac → PC)

`.ipa` files are too large for git. After archiving on Mac:

1. Copy to PC: `releases/ipa/NFG-Hangman.ipa` and `NFG-Crash.ipa`  
   (AirDrop, USB, or `scp` — see `docs/MAC_FINISH_AFTER_PC.md`)
2. On PC: `.\scripts\sync-ipa-to-downloads.ps1` then restart `run-electron-cloudflare.bat`

Commit **source code** changes from Mac with `./scripts/sync-push.sh`; hand off **binaries** separately.

---

## Cursor / Agent tips

1. **Pull first** on whichever machine you open — code matches the other device.
2. **Push when done** — one commit message beats re-pasting `MAC_*` / `WINDOWS_*` prompt docs.
3. **Cross-device companion prompts** — see below; agents auto-write Mac/PC follow-up tasks.
4. Old prompt files (`docs/MAC_*.md`, `WINDOWS-*.md`) are fallbacks; prefer git sync when both machines use this repo.
5. If pull reports conflicts, fix in Cursor, then push from that machine.

---

## Cross-device Cursor prompts (PC ↔ Mac handoff)

Cursor **cannot** mirror chat sessions between devices. This repo links them with:

| Piece | Purpose |
|-------|---------|
| `.cursor/rules/cross-device-sync.mdc` | Every agent queues a companion task when the other device still needs work |
| `docs/cross-device/pending-on-mac.md` | Ready-to-run prompt for Mac (iOS / Xcode) |
| `docs/cross-device/pending-on-pc.md` | Ready-to-run prompt for PC (server / Electron) |
| `scripts/run-pending-task.*` | After pull, copies the one-line Agent prompt |

**Example:** PC agent adds a new mobile API → it writes `pending-on-mac.md` → you push → on Mac:

```bash
./scripts/sync-pull.sh          # also runs run-pending-task if pending
# paste into Agent:
# Run the pending cross-device task in @docs/cross-device/pending-on-mac.md
```

Trust this workspace in Cursor so project hooks in `.cursor/hooks.json` run (reminds you to push after queuing a task).

Details: `docs/cross-device/README.md` and `AGENTS.md`

---

## Quick checks

```bash
# Either machine — am I in sync?
git fetch origin
git status -sb
git log -1 --oneline
```

```powershell
# PC — is live data healthy? (local only)
Invoke-RestMethod http://127.0.0.1:3847/api/admin/data-health
```

---

## First push from this PC

You currently have many local changes not on GitHub yet. When ready:

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
.\scripts\sync-push.ps1 "PC: hangman sync, chat moderation, cosmetics, data failsafes"
```

Then on Mac: `./scripts/sync-pull.sh` — Mac Cursor will see the same server and iOS source changes without re-running the Windows prompts.
