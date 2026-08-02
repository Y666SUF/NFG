---
cross_device_status: pending
from_device: mac
target_device: pc
created_at: 2026-08-03T00:00:00Z
title: Deploy offline inventory sync + pull latest server
related_paths:
 - server/mobile-inventory.js
 - server/mobile-api.js
 - server/game.js
 - server/mobile-auth.js
---

# PC companion task: Offline play sync (steal charges + scores)

Mac shipped iOS offline mode: Arcade keeps working when the server is down; scores and steal spends sync on reconnect.

## New server piece

- `server/mobile-inventory.js` — `POST /api/mobile/inventory/sync`
- Wired in `server/mobile-api.js` via `registerMobileInventoryRoutes`

Idempotent spend ids are stored on the player profile (`syncedInventorySpendIds`). Steal spends with a `target` call `game._trySteal` (charge burns only on success).

## Do on Windows PC

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
```

Confirm files exist:

- `server/mobile-inventory.js`
- `server/mobile-api.js` requires/registers inventory routes

Restart the **live** Node process (pm2 / `run-electron-cloudflare.bat` — do not start a second copy).

## Verify

```powershell
curl -X POST https://y666suf.com/api/mobile/inventory/sync -H "Content-Type: application/json" -d "{}"
```

Expect `401` with `auth_required` (not 404).

From iOS (after TestFlight / install):

1. With server up: note steal charges + balance
2. Stop Node briefly → app shows Offline banner; Arcade still playable
3. Queue a steal or earn Arcade points offline
4. Restart Node → charges/points catch up without downtime stuck state

## When done

1. Set `cross_device_status: done`
2. `.\scripts\sync-push.ps1 "Server: offline inventory sync endpoint"`
