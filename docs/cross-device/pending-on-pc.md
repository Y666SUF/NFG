---
cross_device_status: done
from_device: mac
target_device: pc
created_at: 2026-06-22T22:00:00Z
title: Deploy offline_sync arcade pending points fix
related_paths:
 - server/mobile-arcade.js
 - server/mobile-api.js
 - docs/WINDOWS_OFFLINE_SYNC_FIX_PROMPT.txt
---

# PC companion task: offline_sync arcade pending points

## Done on Windows PC

- Merged `origin/main` commit `e014225c2` — `applyOfflineArcadeSync` + `offline_sync` in `server/mobile-arcade.js`
- `registerMobileArcadeRoutes` wired in `server/mobile-api.js`
- Live Node restarted (single instance on 3847)
- Smoke tests passed locally and via https://y666suf.com:
  - Jump: `ok: true`, `offlineSync: true`, duplicate returns `gained: 0`
  - Blocks + Vault Run: `offlineSync: true`

## Mac / iOS next

Ship TestFlight build with global offline queue flush (connect + 30s timer) and `offline_sync` action — PC server is ready.
