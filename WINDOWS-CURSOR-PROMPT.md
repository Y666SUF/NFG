# Cursor prompt — NFG Crash Windows server changes for iOS app

Copy everything below the line into a **new Cursor chat** on your Windows PC, with your **tiktok-live-crash-game** project folder open (the folder that has `server/index.js`, `package.json`, `data/points.live.json`).

---

## PROMPT START (copy from here)

You are editing my **NFG Crash** TikTok live game (Node.js + Express on port **3847**). I have a separate **iOS app** that must use the **same `data/points.live.json`** and the same game logic as this Windows server. Do **not** create a second sync server on another port — this game already IS the server.

### Goals

1. **iOS connects** to this PC over LAN: `http://<PC_IP>:3847`
2. **WebSocket** at `ws://<PC_IP>:3847` (root path, no `/ws`) — broadcasts `{ type: "state", payload: game.getState() }` (already exists)
3. **Mobile bets** via `POST /api/chat` with `"source": "mobile"` — same bet commands as TikTok (`!100 2.5`, `!30k 2`, `!balance`, etc.)
4. **Anti-impersonation**: iOS must NOT trust a typed username. Users verify by commenting `!link <CODE>` on **TikTok live**; only then do they get a Bearer session token.
5. **Leaderboard**: iOS uses existing `GET /api/balances` (top 50) and shows top 5 on main screen.

### Required file changes

#### 1. CREATE `server/mobile-auth.js` (new file)

Implement:

- `data/mobile-sessions.json` persistence for session tokens
- `POST /api/mobile/link/start` — body `{ deviceId }` → returns `{ code, expiresInSeconds, instructions, tiktokCommand: "!link CODE" }` (code expires in 10 minutes)
- `GET /api/mobile/link/status/:code` — returns `{ status: "pending"|"linked"|"expired_or_unknown", token?, userId?, displayName?, secondsLeft? }`
- `GET /api/mobile/session` — requires `Authorization: Bearer <token>`
- `POST /api/mobile/session/logout`
- `completeLinkFromTikTok(userId, displayName, message)` — only when message matches `!link CODE`; userId must come from TikTok live, not from mobile
- `validateBearer(req)` — returns session or null

Use `normalizeUser` from `./store`. Session TTL ~90 days. Link codes are 6 hex chars uppercase.

#### 2. CREATE `server/mobile-api.js` (new file)

- `require("./mobile-auth")` and call `registerMobileAuthRoutes(app)` inside `registerMobileApi`
- `GET /api/mobile/status` — returns `{ ok, service: "nfg-crash", phase, roundId, multiplier, sharedData: true }`
- Export `registerMobileApi(app, { game, pointStore })`

#### 3. EDIT `server/index.js`

Add requires near top:

```js
const { registerMobileApi } = require("./mobile-api");
const { completeLinkFromTikTok, validateBearer } = require("./mobile-auth");
```

After `app.get("/api/state", ...)` and **after** `const game = new CrashGame(...)` is created, add:

```js
registerMobileApi(app, { game, pointStore });
```

At the **start** of `app.post("/api/chat", ...)`, add logic:

**A) Mobile requests (`source === "mobile"`):**

- Call `validateBearer(req)`; if no session → `401` with `{ error: "auth_required" }`
- Overwrite `req.body.userId` and `req.body.user` with `session.userId` (never trust client username)

**B) Non-mobile (TikTok / web / bridge):**

- Before normal chat handling, call `completeLinkFromTikTok(user, displayName, message)`
- If `link.handled`, return JSON immediately with optional `tiktokChatReply` confirming link success/failure
- Do NOT allow `!link` completion when `source === "mobile"`

Do **not** change existing TikTok bridge, gift logic, or WebSocket behaviour.

#### 4. Windows Firewall

Document in a short comment or README note: allow **TCP 3847** on Private network.

### APIs the iOS app already calls

| Endpoint | Use |
|----------|-----|
| `GET /api/state` | Round snapshot |
| WebSocket `/` | Live `state`, `chat_result`, `game_event` |
| `POST /api/chat` | Bets (`source: "mobile"`, `Authorization: Bearer`) |
| `GET /api/economy/profile/:user` | Balance after link |
| `GET /api/balances` | Full leaderboard |
| `POST /api/mobile/link/start` | Start TikTok verify |
| `GET /api/mobile/link/status/:code` | Poll until linked |

### Testing checklist (implement then verify)

1. `npm start` on Windows — server on `http://0.0.0.0:3847`
2. `GET http://localhost:3847/api/mobile/status` → `ok: true`
3. `POST http://localhost:3847/api/mobile/link/start` with `{ "deviceId": "test" }` → returns code
4. While **live**, comment `!link <CODE>` from TikTok → chat reply confirms link
5. `GET /api/mobile/link/status/<CODE>` → `status: "linked"` with `token`
6. `POST /api/chat` with `Authorization: Bearer <token>`, `{ "source": "mobile", "message": "!balance" }` → uses linked user only
7. `POST /api/chat` with `source: "mobile"` and **no** Bearer → `401`
8. iPhone on same Wi‑Fi: Settings → server `http://<PC_LAN_IP>:3847` → link flow → place bet → points match TikTok live

### Do NOT

- Add a separate `sync-server` on 3847 if this game already uses 3847
- Let mobile clients set `userId` without a valid Bearer token
- Accept `!link` from `source: "mobile"` POST (only from TikTok live path)

### iOS project location

The iOS app lives in a separate repo/folder (`nfg-crash/ios`). Only change the **Node game server** in this Windows project. Match behaviour exactly to the Mac reference implementation if present in `server/mobile-auth.js` and `server/mobile-api.js`.

When done, list files created/changed and any manual steps (firewall, `npm start`, copy `data/` folder if needed).

## PROMPT END
