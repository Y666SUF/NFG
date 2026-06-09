# Cross-device companion prompts (Cursor)

Cursor cannot mirror chat sessions between your PC and MacBook directly. This folder is the **handoff queue**: when an agent on one machine needs work on the other, it writes a ready-to-run prompt here. Git sync delivers it.

## Flow

```
PC Agent completes API change
  → writes docs/cross-device/pending-on-mac.md (status: pending)
  → you run .\scripts\sync-push.ps1

Mac: ./scripts/sync-pull.sh
  → ./scripts/run-pending-task.sh   (copies Agent prompt)
  → paste in Cursor Agent → Mac work runs
  → mark status: done → ./scripts/sync-push.sh
```

Reverse direction uses `pending-on-pc.md`.

## Files

| File | Who reads it |
|------|----------------|
| `pending-on-mac.md` | MacBook (iOS, Xcode, Capacitor) |
| `pending-on-pc.md` | Windows PC (server, Electron, tunnel) |

## One-line Agent prompt

**Mac:**
```text
Run the pending cross-device task in @docs/cross-device/pending-on-mac.md
```

**PC:**
```text
Run the pending cross-device task in @docs/cross-device/pending-on-pc.md
```

## Cursor setup (both machines)

1. Clone the same repo: `https://github.com/Y666SUF/NFG`
2. Open the folder in Cursor (trust the workspace so **project hooks** run)
3. Pull before work: `sync-pull` script
4. Rules in `.cursor/rules/cross-device-sync.mdc` sync via git and tell every agent to queue companion tasks automatically

See also: `docs/PC_MAC_SYNC.md`, `AGENTS.md`
