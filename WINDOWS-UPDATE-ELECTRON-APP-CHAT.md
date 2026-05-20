# Windows Cursor prompt — App Chat window + mobile chat API

Open **tiktok-live-crash-game** in Cursor → **new Agent chat** → paste **PROMPT START** through **PROMPT END**.

When you run **Electron**, you should get **3 windows**:
1. Main game  
2. Player Lookup (if you already have it)  
3. **App Chat** — live iPhone app messages  

---

## PROMPT START

You are editing my **NFG Crash** Windows project (Node server port **3847**, Electron in `electron/main.js`). The iPhone app sends chat via `POST /api/mobile/chat`. Implement server support + a dedicated Electron window that shows messages in real time.

Do **not** break: TikTok bridge, bets, WebSocket, mobile `!link`, LIVE badge (`/api/mobile/status`), full leaderboard (`/api/balances?limit=all`).

TikTok: **@y666.suf**

---

### PART A — Server (skip files that already exist)

#### A1. CREATE `server/mobile-wallet.js` (if missing)

Same as wallet prompt — exports `buildWalletPayload(user, pointStore, game)` with balance, shield, jet lock, `inventory: { stealCharges, shieldBreakCharges, jetLockCharges }`.

#### A2. CREATE `server/mobile-chat.js` (if missing)

- `GET /api/mobile/chat?limit=50` → `{ ok: true, messages: [...] }`
- `POST /api/mobile/chat` with Bearer auth, body `{ message }`
- Reject empty, `!` commands, >240 chars, rate limit ~1.2s per user
- `console.log(\`[App chat] ${displayName} (@${userId}): ${message}\`)`
- `broadcast({ type: "app_chat", payload: { id, userId, displayName, message, at } })`

Use the full `mobile-chat.js` from the iOS companion docs / `WINDOWS-UPDATE-WALLET-AND-CHAT.md`.

#### A3. EDIT `server/mobile-api.js`

- Require `./mobile-chat`, `./mobile-wallet`, `validateBearer` from `./mobile-auth`
- `registerMobileApi(app, { game, pointStore, isLocalhost, broadcast })` must call `registerMobileChatRoutes` when `broadcast` is a function
- Add `GET /api/mobile/me` (Bearer) → `buildWalletPayload(session.userId, ...)`

#### A4. EDIT `server/index.js`

Change to:

```javascript
registerMobileApi(app, { game, pointStore, isLocalhost, broadcast });
```

---

### PART B — App Chat page

#### B1. CREATE `public/app-chat.html`

Create a standalone page that:
- Fetches `GET /api/mobile/chat?limit=80` on load and renders history
- Opens WebSocket to `ws://127.0.0.1:3847` (use `location.host` like `app.js`)
- On `{ type: "app_chat", payload }` append a message bubble (displayName, @userId, message, time)
- Shows connection status (green dot = Live)
- Dark NFG-style UI matching `player-lookup.html`

(Full file content: see `public/app-chat.html` in the reference repo — ~215 lines.)

---

### PART C — Electron third window

#### C1. EDIT `electron/main.js`

1. Add variable: `let chatWindow = null;`

2. After the **Player Lookup** window is created and `loadURL(...player-lookup.html)`, add a **third** `BrowserWindow`:

```javascript
  chatWindow = new BrowserWindow({
    width: 420,
    height: 560,
    minWidth: 360,
    minHeight: 420,
    title: "NFG Crash - App Chat",
    autoHideMenuBar: true,
    backgroundColor: "#0b1020",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  await chatWindow.loadURL(`${ROOT_URL}app-chat.html`);
  chatWindow.on("closed", () => {
    chatWindow = null;
  });
```

3. In the block that positions side windows next to the main game, place **App Chat** to the right of **Player Lookup**:

```javascript
    const sideX = mainBounds.x + mainBounds.width + 16;
    const sideH = Math.max(640, Math.floor(mainBounds.height * 0.75));
    lookupWindow.setBounds({
      x: sideX,
      y: mainBounds.y,
      width: 520,
      height: sideH,
    });
    chatWindow.setBounds({
      x: sideX + 520 + 12,
      y: mainBounds.y,
      width: 400,
      height: sideH,
    });
```

(If there is no lookup window yet, still create `chatWindow` and position it at `sideX`, `mainBounds.y`.)

4. When `mainWindow` closes, also close `chatWindow` if open (same as lookup).

---

### PART D — Verify

1. `npm start` or run Electron  
2. Three windows open; **App Chat** shows “Live” green dot  
3. `curl http://127.0.0.1:3847/api/mobile/chat` → `{ "ok": true, "messages": [] }`  
4. Send a message from iPhone **App Chat** → message appears in the Electron window **and** console: `[App chat] Name (@user): text`

## PROMPT END

---

## If you already applied wallet/chat server only

Apply **PART B** (`public/app-chat.html`) and **PART C** (`electron/main.js`) only.

## File checklist

| File | Action |
|------|--------|
| `server/mobile-chat.js` | Create |
| `server/mobile-wallet.js` | Create (wallet API) |
| `server/mobile-api.js` | Update |
| `server/index.js` | Pass `broadcast` |
| `public/app-chat.html` | Create |
| `electron/main.js` | Add `chatWindow` |
