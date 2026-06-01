---
cross_device_status: pending
from_device: mac
target_device: pc
created_at: 2026-06-01T13:30:00Z
title: Live caster feed + !song command for NFG Live app
related_paths:
  - server/index.js
  - server/tiktok-bridge.js
  - server/spotify.js
  - server/spotify-commands.js
---

# PC companion task: Live caster feed + `!song` command

## Context

A new iOS app, **NFG Live** (`ios-live/` on the Mac), was built. It is a hands-free
"TikFinity-style" controller for the TikTok live:

- It reads live chat **aloud** on the iPhone (on-device text-to-speech — no server TTS needed).
- It shows the live chat feed, gifts, and Spotify now-playing/queue.
- Viewers queue music by typing **`!song <name> <artist>`** in the live chat.

The app connects to this PC server over the **existing** Cloudflare tunnel
(`wss://y666suf.com`, the same WebSocket that Crash uses — any non-`/hangman/ws`
upgrade joins the `clients` broadcast pool in `server/index.js`). It also calls
the existing `/api/mobile/status` and `/api/spotify/*` endpoints.

**Almost everything already exists.** The TikTok scraping (`server/tiktok-bridge.js`),
Spotify queueing (`server/spotify.js` → `queueTrackBySearch`), and WebSocket
`broadcast()` are all in place. This task adds two things:

1. **Broadcast the raw live chat / gifts** over the WebSocket so the app can read them aloud.
2. **Accept the bare `!song <query>` command** (currently only `!csong` works; bare `!song`
   is rejected as ambiguous) and confirm it back to chat.

> The app already has graceful fallbacks: if `live_song_request` is not emitted it
> will still pick up the existing `chat_result` → `spotify_queue` message, and it
> polls `/api/spotify/status`. So step 2's broadcast is "nice to have"; the
> **must-do** is step 1 (raw chat broadcast) and enabling the `!song` keyword.

---

## Do on this device (Windows PC)

All changes are in `server/`. After editing, restart with `run-electron-cloudflare.bat`.

### 1. Broadcast raw live chat + gifts to the app  (REQUIRED)

The TikTok bridge already POSTs every comment to `POST /api/chat` and every gift/like
to `POST /api/tiktok/reward` (see `server/tiktok-bridge.js`). The cleanest place to
broadcast is inside those existing handlers in **`server/index.js`**, because that's
where `broadcast()` lives.

**a) In `server/index.js`, inside the `app.post("/api/chat", ...)` handler**, near the
top (right after you read `user` / `message` from the body, before the command parsing),
add a raw broadcast so the app sees every comment:

```js
// --- NFG Live caster feed: mirror raw TikTok comments to the app ---
broadcast({
  type: "live_comment",
  payload: {
    user,
    displayName: req.body?.displayName || user,
    message,
    superFan: req.body?.superFan === true,
    superFanLevel: Number(req.body?.superFanLevel) || 0,
    at: Date.now(),
  },
});
```

> `user`, `message` are already parsed in that handler. Use the same variable names that
> already exist there — don't redeclare them. If the handler reads the body fields under
> different names, reuse those.

**b) In `server/index.js`, inside the `app.post("/api/tiktok/reward", ...)` handler**,
add a gift broadcast (only for `type === "gift"`):

```js
// --- NFG Live caster feed: mirror gifts to the app ---
if (req.body && req.body.type === "gift" && (Number(req.body.coins) > 0)) {
  broadcast({
    type: "live_gift",
    payload: {
      user: req.body.userId,
      displayName: req.body.displayName || req.body.userId,
      giftName: req.body.giftName || "a gift",
      giftCount: Number(req.body.giftCount) || 1,
      coins: Number(req.body.coins) || 0,
      at: Date.now(),
    },
  });
}
```

> If `/api/tiktok/reward` is defined in a separate module rather than `index.js`, either
> move the broadcast there (it must have access to `broadcast`) or have the bridge POST a
> copy to a tiny new localhost route in `index.js` that just broadcasts. Keeping it in
> `index.js` next to the existing reward logic is simplest.

**c) (Optional) New viewer joins** — only if you want "X joined" read aloud. In
`server/tiktok-bridge.js`, the `evMember`/`roomUser` events can POST to a new localhost
route that broadcasts `{ type: "live_join", payload: { user, displayName, at } }`. Skip
this if join spam is annoying.

### 2. Enable the `!song <name> <artist>` command  (REQUIRED for the headline feature)

Right now `server/spotify-commands.js` **rejects** bare `!song` (returns the "ambiguous"
hint) because Crash + Hangman both run. For the live caster we want bare `!song` to work.

Pick **one** of these:

**Option A (recommended) — gate it behind an env flag** so it only activates when you want:

In `server/spotify-commands.js`, change `parseCrashSpotifyQueueCommand` so that when
`process.env.LIVE_SONG_COMMAND === "1"`, a bare `!song <query>` (and `!sr`, `!request`)
is treated as a real queue command instead of the ambiguous rejection:

```js
const LIVE_SONG_RE = /^!(?:song|sr|request)\b(.*)$/i;

function parseCrashSpotifyQueueCommand(text) {
  const raw = String(text || "").trim();
  if (!raw) return null;

  // NFG Live: bare !song goes straight to the Spotify queue when enabled.
  if (process.env.LIVE_SONG_COMMAND === "1") {
    const live = raw.match(LIVE_SONG_RE);
    if (live) {
      return { command: "song", query: String(live[1] || "").trim() };
    }
  }

  if (LEGACY_GENERIC_RE.test(raw)) {
    return {
      rejected: true,
      reason: "ambiguous",
      help: "Use !csong or !cqueue for NFG Crash (Hangman uses !hsong / !hqueue).",
    };
  }
  // ...existing !csong / !crashsong parsing unchanged...
}
```

Then set `LIVE_SONG_COMMAND=1` in your `.env` (or in `run-electron-cloudflare.bat`).

**Option B — always-on**: just make the `LIVE_SONG_RE` branch run unconditionally
(no env flag). Only do this if Hangman's own `!song` handling won't conflict.

The existing `/api/chat` handler already calls `queueTrackBySearch(spotifyCmd.query, displayName)`
and returns `tiktokChatReply`, so once the parser returns `{command:"song", query}` the
song will queue and confirm in chat automatically. **No other change needed for queueing.**

### 3. (Optional) Broadcast a dedicated song-request event

In `server/index.js`, in the spotify-command branch of `/api/chat` (right after
`const queued = await queueTrackBySearch(...)`), add:

```js
broadcast({
  type: "live_song_request",
  payload: {
    ok: queued.ok === true,
    requestedBy: queued.requestedBy || view.displayName || user,
    track: queued.track || "",
    error: queued.error || "",
    at: Date.now(),
  },
});
```

This gives the app an instant "✅ Added <track>" row + voice confirmation. If you skip it,
the app falls back to the existing `chat_result` broadcast + Spotify polling.

---

## Verify

1. Restart the server (`run-electron-cloudflare.bat`) with `LIVE_SONG_COMMAND=1` set.
2. With the server running, from any machine:
   ```bash
   curl -X POST https://y666suf.com/api/chat ^
     -H "Content-Type: application/json" ^
     -d "{\"userId\":\"tester\",\"displayName\":\"Tester\",\"message\":\"hello world\"}"
   ```
   - A WebSocket client connected to `wss://y666suf.com` should receive a `live_comment`.
3. Send `!song blinding lights the weeknd` the same way — it should queue on Spotify and
   return a `tiktokChatReply` confirmation (and a `live_song_request` if you added step 3).
   Confirm with `curl https://y666suf.com/api/spotify/status` that `upcoming` grew.
4. Spotify must have an **active device** (open Spotify on the phone/PC and hit play once)
   and the account must be **Premium** for queueing to work — this is unchanged from `!csong`.

## When done

- Set `cross_device_status: done` in the frontmatter above.
- `.\scripts\sync-push.ps1` with a message like: `PC: live caster feed + !song for NFG Live app`.
- No reverse Mac task is needed — the iOS app already handles all these message types.
