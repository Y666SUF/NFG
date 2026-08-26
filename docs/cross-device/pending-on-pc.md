---
cross_device_status: done
from_device: mac
target_device: pc
created_at: 2026-08-26T01:40:00Z
title: Solo crash sync — honor absolute clientBalance
related_paths:
  - server/mobile-crash-solo.js
  - server/mobile-api.js
---

# PC companion task: Absolute app wallet on solo crash sync

## Context

iOS TestFlight will send **absolute** phone balance on `POST /api/mobile/crash/solo/sync` (`clientBalance` / `appBalance` / `allTime`). Without the updated server file, the PC keeps applying only `netDelta` from a stale starter balance and the phone can snap back to **5,000** / **100,000** after sync.

Mac already updated `server/mobile-crash-solo.js` in git — pull and restart Node.

## Do on this device

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
```

1. Confirm `server/mobile-crash-solo.js` mentions `clientBalance` / `pickAbsoluteBalance` / `appBalanceApplied`.
2. Confirm `server/mobile-api.js` still registers `registerMobileCrashSoloRoutes`.
3. **Restart** the live Node process (do not start a second copy).

## Verify

```powershell
# Expect 401 (auth required), NOT 404
curl -s -o NUL -w "%{http_code}" -X POST https://y666suf.com/api/mobile/crash/solo/sync -H "Content-Type: application/json" -d "{}"
```

From a logged-in phone (or with a real bearer token), body shape:

```json
{
  "rounds": [],
  "clientBalance": 12345,
  "appBalance": 12345,
  "allTime": 12345,
  "clientAllTime": 12345
}
```

Response should include `"appBalanceApplied": true` and `wallet.balance` matching `clientBalance`.

## When done

- Set `cross_device_status: done` in frontmatter
- `.\scripts\sync-push.ps1 "PC: solo crash absolute clientBalance deployed"`
