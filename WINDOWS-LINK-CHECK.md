# Windows PC — check TikTok `!link` is registering

Copy this into **Cursor on your Windows game PC** (folder with `server/index.js`), or follow the steps manually.

---

## What must be true

1. Game running: `npm start` (port **3847**)
2. Console shows: `[TikTok] Bridge on — @y666.suf → http://127.0.0.1:3847/`
3. You are **LIVE** on TikTok as **@y666.suf**
4. iPhone has a **fresh** link code (tap **Get link code** — codes expire in 10 minutes)
5. You comment **exactly** `!link ABCDEF` on **your live** (copy from the app — no extra words)

---

## Step 1 — See pending codes (on the PC)

PowerShell:

```powershell
curl http://127.0.0.1:3847/api/mobile/link/debug
```

You should see `"pending"` with your code and `secondsLeft`. If `pendingCount` is **0**, generate a new code on the iPhone first.

---

## Step 2 — Simulate TikTok (bypasses TikTok)

Replace `YOURCODE` with the code from the iPhone app (e.g. `A1B2C3`):

```powershell
$code = "YOURCODE"
$body = '{"userId":"y666.suf","displayName":"Yusuf","message":"!link ' + $code + '"}'
Invoke-RestMethod -Uri http://127.0.0.1:3847/api/chat -Method POST -Body $body -ContentType "application/json; charset=utf-8"
Invoke-RestMethod -Uri "http://127.0.0.1:3847/api/mobile/link/status/$code"
```

- Second command should show `"status":"linked"` with a `token`.
- If this works but TikTok does not → **TikTok bridge** is not receiving your live chat (see Step 4).

Watch the game console for:

```text
[Mobile link] OK @y666.suf linked via TikTok live code=...
```

---

## Step 3 — Real TikTok live test

1. Stay **live** on @y666.suf  
2. New code on iPhone → **Get link code**  
3. On TikTok, comment **only** the line from the app (e.g. `!link A1B2C3`)  
4. On PC console you should see within 1–2 seconds:

```text
[TikTok] !link chat from @y666.suf: "!link A1B2C3"
[Mobile link] OK @y666.suf linked via TikTok live code=A1B2C3
```

5. iPhone should switch to the game screen automatically.

---

## Step 4 — If Step 2 works but Step 3 does not

| Symptom | Fix |
|--------|-----|
| No `[TikTok] Bridge on` line | Restart `npm start`; check `tiktok.config.json` has `"enabled": true` and `"uniqueId": "y666.suf"` |
| `Waiting until @y666.suf is LIVE` | Start your TikTok live first, then restart game or wait for reconnect |
| `Forward error` in console | Game not listening — restart `npm start` |
| Comment has extra text | Only `!link CODE` — no emoji, no “hey !link …” |
| Code expired | New code on phone; comment within 10 minutes |
| Wrong account in `index.js` | TikTok bridge must match your live account (`y666.suf`) |

---

## Step 5 — Apply latest server files (Cursor prompt)

Paste into Cursor on Windows:

```
Update NFG Crash server for iOS !link debugging:

1. In server/mobile-auth.js:
   - parseLinkCode() tolerant of minor formatting
   - console.log when codes are created and when link succeeds/fails
   - GET /api/mobile/link/debug (localhost only) listing pending codes

2. In server/mobile-api.js: pass isLocalhost into registerMobileAuthRoutes

3. In server/index.js: registerMobileApi(..., { isLocalhost })
   - log failed !link from TikTok chat

4. In server/tiktok-bridge.js: log lines starting with !link when chat arrives

5. Ensure POST /api/chat calls completeLinkFromTikTok for non-mobile messages BEFORE normal game commands.

Restart npm start after changes.
```

---

## Files to copy from Mac if missing

If `/api/mobile/link/start` returns 404, copy these from the Mac `Documents/test/server/` folder to Windows:

- `mobile-auth.js`
- `mobile-api.js`
- `index.js` (merge the `registerMobileApi` + `completeLinkFromTikTok` blocks)

See also: `WINDOWS-CURSOR-PROMPT.md`
