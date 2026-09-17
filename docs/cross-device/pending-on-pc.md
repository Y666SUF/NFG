---
cross_device_status: done
from_device: mac
target_device: pc
created_at: 2026-09-16T02:15:00Z
completed_at: 2026-09-17T05:15:00Z
title: Fix app-guest auth 500 (now is not defined) + absolute wallet sync
related_paths:
  - server/mobile-auth.js
  - server/mobile-crash-solo.js
---

# PC companion task: Fix iOS cannot-connect (app-guest 500)

## Done on PC (2026-09-17)

- Pulled `origin/main` (includes `const now = nowMs()` in app-guest + `pickAbsoluteBalance` / `clientBalance` in solo sync)
- Resolved stash conflict on `server/mobile-crash-solo.js` → kept GitHub version
- Restarted live Crash Node on `:3847`
- Verified:
  - `POST /api/mobile/auth/app-guest` → **200** JSON with `ok:true` + `token`
  - `POST /api/mobile/crash/solo/sync` (no auth) → **401** (not 404)
