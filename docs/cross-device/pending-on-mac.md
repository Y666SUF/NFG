---
cross_device_status: done
from_device: pc
target_device: mac
created_at: 2026-06-10T14:00:00Z
title: Retro Pixel Jump iOS — y666suf.com + black screen fix
related_paths:
 - .env
 - app.config.js
 - app.config.ts
 - app/_layout.tsx
 - src/
---

# Mac companion task: Retro Pixel Jump iOS (backend URL + black screen)

## Context (PC — already done)

Retro Pixel Jump backend is proxied through the **same Cloudflare tunnel as NFG Crash**:

| Layer | Value |
|-------|--------|
| Public base | `https://y666suf.com/api/pixel-jump` |
| Health | `GET https://y666suf.com/api/pixel-jump/` |
| Leaderboard | `GET/POST https://y666suf.com/api/pixel-jump/leaderboard` |
| Multiplayer | `POST https://y666suf.com/api/pixel-jump/mp/rooms` |
| WebSocket | `wss://y666suf.com/api/pixel-jump/ws/mp/{roomId}?playerId=...` |
| PC launcher | `run-electron-cloudflare.bat` (Node 3847 → uvicorn 8001) |

**Do NOT use** old `trycloudflare.com` URLs — they expire when cloudflared restarts.

Room API returns relative `wsUrl` like `/api/pixel-jump/ws/mp/ABCD?playerId=...` — resolve against `https://y666suf.com` (not against backend base with an extra `/api`).

## When done

- Set `cross_device_status: done` in frontmatter
- `./scripts/sync-push.sh`
