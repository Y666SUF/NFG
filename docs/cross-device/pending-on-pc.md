---
cross_device_status: pending
from_device: mac
target_device: pc
created_at: 2026-09-16T02:15:00Z
title: Fix app-guest auth 500 (now is not defined) + absolute wallet sync
related_paths:
  - server/mobile-auth.js
  - server/mobile-crash-solo.js
---

# PC companion task: Fix iOS cannot-connect (app-guest 500)

## Context

Live `POST https://y666suf.com/api/mobile/auth/app-guest` returns **500**:

```text
ReferenceError: now is not defined
```

That endpoint is how the iPhone creates/refreshes guest sessions and re-binds TikTok by device. When it 500s, **some users cannot connect to the game server**.

Mac already fixed `server/mobile-auth.js` (define `const now = nowMs()` before writing the new session). Also confirm `server/mobile-crash-solo.js` honors absolute `clientBalance` so phone wallet stays authority.

## Do on this device

```powershell
cd C:\Users\Yusef\test
.\scripts\sync-pull.ps1
```

1. Open `server/mobile-auth.js` → in `POST /api/mobile/auth/app-guest`, confirm the new-guest session block has:
   ```js
   const now = nowMs();
   state.sessions[token] = { … issuedAt: now, lastSeenAt: now, expiresAt: now + SESSION_TTL_MS };
   ```
2. Confirm `server/mobile-crash-solo.js` contains `pickAbsoluteBalance` / `clientBalance` / `setBalance`.
3. **Restart** the live Node process (do not start a second copy).

## Verify

```powershell
# Must be 200 JSON with token — NOT 500
curl -s -X POST https://y666suf.com/api/mobile/auth/app-guest `
  -H "Content-Type: application/json" `
  -d "{\"deviceId\":\"pc-verify-$(Get-Random)\"}"
```

```powershell
# Solo sync exists (401 without auth is OK; 404 is bad)
curl -s -o NUL -w "%{http_code}" -X POST https://y666suf.com/api/mobile/crash/solo/sync `
  -H "Content-Type: application/json" -d "{}"
```

Expect app-guest **200** with `token` + `userId`. Expect solo sync **401** (not 404).

## When done

- Set `cross_device_status: done` in frontmatter
- `.\scripts\sync-push.ps1 "PC: fix app-guest now ReferenceError + restart"`
