---
cross_device_status: done
from_device: mac
target_device: pc
created_at: 2026-08-03T01:00:00Z
title: Deploy on-device crash sync + inventory sync
related_paths:
 - server/mobile-crash-solo.js
 - server/mobile-inventory.js
 - server/mobile-api.js
---

# PC companion task: On-device crash wallet sync

iOS now runs **crash rounds entirely on the phone** (no live server needed). When online, it syncs win/loss balance deltas.

## New endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/mobile/crash/solo/sync` | Apply queued solo crash `netDelta`s (idempotent) |
| POST | `/api/mobile/inventory/sync` | Offline steal charge sync |

Files:

- `server/mobile-crash-solo.js`
- `server/mobile-inventory.js`
- wired in `server/mobile-api.js`

## Do on Windows PC

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
```

Restart the **live** Node process (do not start a second copy).

## Verify

```powershell
curl -X POST https://y666suf.com/api/mobile/crash/solo/sync -H "Content-Type: application/json" -d "{}"
curl -X POST https://y666suf.com/api/mobile/inventory/sync -H "Content-Type: application/json" -d "{}"
```

Both should return **401** `auth_required` (not 404).

## When done

1. Set `cross_device_status: done`
2. `.\scripts\sync-push.ps1 "Server: on-device crash + inventory sync"`
