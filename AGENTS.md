# NFG — Agent instructions (PC + Mac)

Read **`docs/PC_MAC_SYNC.md`** for git push/pull between machines.

## Cross-device tasks

When work on one machine requires follow-up on the other, the agent writes a **companion prompt** to:

- `docs/cross-device/pending-on-mac.md` — work needed on MacBook
- `docs/cross-device/pending-on-pc.md` — work needed on Windows PC

See **`.cursor/rules/cross-device-sync.mdc`** (always applied).

### Run a pending task on this machine

```text
Run the pending cross-device task in @docs/cross-device/pending-on-mac.md
```

or `@docs/cross-device/pending-on-pc.md` on Windows.

Or run:

- PC: `.\scripts\run-pending-task.ps1`
- Mac: `./scripts/run-pending-task.sh`

Then paste the copied Agent prompt.

## Repo roles

| Machine | Owns |
|---------|------|
| Windows PC | Live server, TikTok bridge, player economy, Electron, Cloudflare tunnel, website build |
| MacBook | Xcode, Capacitor iOS builds, TestFlight, IPA export |

Sync code with `scripts/sync-push.*` / `scripts/sync-pull.*` — not duplicate WINDOWS/MAC prompt docs unless git is unavailable.
