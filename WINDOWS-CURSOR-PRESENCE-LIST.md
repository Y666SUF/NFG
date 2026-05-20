# Windows Cursor prompt — online players list (copy below the line)

---

You are editing my **NFG Crash** Windows game server (Node/Express, port **3847**, **https://y666suf.com**).

The iOS app now shows **who is in the app** in App Chat (count button + name list). The count has not worked because the PC server is missing the latest presence code.

**Do not break:** TikTok bridge, bets, WebSocket, mobile auth, app chat, rewarded ads, store routes.

## Replace `server/mobile-presence.js` entirely

Copy from Mac `nfg-crash/server/mobile-presence.js` OR implement:

- `PRESENCE_TTL_MS = 90000`
- Map keyed by TikTok `userId` when logged in, else `device:{id}`
- `POST /api/mobile/presence/heartbeat` — requires `X-Device-Id`, optional bearer session; returns `{ ok, activeAppUsers, activeAppUserList }`
- `GET /api/mobile/presence/active` — same JSON (no auth required)
- `activeAppUserList`: `[{ userId, displayName, username, isGuest }]` — linked users show TikTok id; guests show `Guest ···` + last 4 of device id

## Update `server/mobile-api.js`

```javascript
const {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
} = require("./mobile-presence");
```

Register routes: `registerMobilePresenceRoutes(app, { validateBearer });`

In `GET /api/mobile/status` add:

```javascript
activeAppUsers: getActiveAppUserCount(),
activeAppUserList: getActiveAppUserList(),
```

## Verify

```powershell
curl http://127.0.0.1:3847/api/mobile/presence/active
curl -X POST http://127.0.0.1:3847/api/mobile/presence/heartbeat -H "X-Device-Id: test-1"
```

Restart server. Report `activeAppUsers` and sample `activeAppUserList` from curl.

---

**End of prompt**
