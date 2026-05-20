# Windows update: active app users (count + who is online)

Shows how many people have the **NFG Crash iOS app** open and **lists their names** in App Chat.

## Files

1. Replace **`server/mobile-presence.js`** with the Mac copy (includes user list).
2. Update **`server/mobile-api.js`**:

```javascript
const {
  registerMobilePresenceRoutes,
  getActiveAppUserCount,
  getActiveAppUserList,
} = require("./mobile-presence");
```

Inside `registerMobileApi`:

```javascript
registerMobilePresenceRoutes(app, { validateBearer });
```

In `GET /api/mobile/status`, add:

```javascript
activeAppUsers: getActiveAppUserCount(),
activeAppUserList: getActiveAppUserList(),
```

3. Restart the game server.

## New endpoints

| Method | Path | Returns |
|--------|------|---------|
| GET | `/api/mobile/presence/active` | `{ ok, activeAppUsers, activeAppUserList }` |
| POST | `/api/mobile/presence/heartbeat` | same + registers this device |

`activeAppUserList` items:

```json
{ "userId": "y666.suf", "displayName": "Yusuf", "username": "y666.suf", "isGuest": false }
```

Guests (not linked TikTok): `isGuest: true`, `displayName` like `Guest ···a1b2`.

## Verify

```powershell
curl http://127.0.0.1:3847/api/mobile/status
curl http://127.0.0.1:3847/api/mobile/presence/active
curl -X POST http://127.0.0.1:3847/api/mobile/presence/heartbeat -H "X-Device-Id: test-device-1"
```

After heartbeat, `activeAppUsers` should be ≥ 1 and `activeAppUserList` should list entries.

## Notes

- Each player counts for **90 seconds** after last heartbeat (app pings every ~15s in chat, ~30s elsewhere).
- Linked TikTok users show **@username**; unlinked devices show **Guest ···** last 4 of device id.
- Rebuild/install iOS app after server is updated.
