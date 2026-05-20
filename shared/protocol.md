# NFG Crash — sync protocol

The Windows PC runs the **authoritative game** (TikTok live chat, balances, crash logic). The **sync server** on the PC rebroadcasts state to iOS and other clients over WebSocket. iOS is a **viewer/controller** unless you explicitly enable client actions.

## REST

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Server up, client count |
| GET | `/state` | Current full game snapshot (JSON) |
| POST | `/bridge/push` | Windows game pushes state or events (requires `X-Bridge-Token`) |
| POST | `/bridge/command` | Windows game accepts remote commands from bridge (optional) |

## WebSocket

Connect: `ws://<PC_LAN_IP>:3847/ws?role=ios&token=<optional>`

### Server → client (broadcast)

```json
{
  "type": "game_state",
  "ts": 1716123456789,
  "payload": {
    "phase": "betting",
    "roundId": "r-42",
    "multiplier": 1.0,
    "crashPoint": null,
    "countdownMs": 12000,
    "players": [],
    "activeBets": [],
    "recentChat": []
  }
}
```

```json
{
  "type": "tiktok_event",
  "ts": 1716123456789,
  "payload": {
    "kind": "comment",
    "user": "viewer123",
    "text": "bet 100",
    "giftName": null,
    "coins": 0
  }
}
```

```json
{
  "type": "log",
  "payload": { "level": "info", "message": "Round started" }
}
```

### Client → server

```json
{ "type": "ping" }
```

```json
{
  "type": "client_action",
  "payload": {
    "action": "cashout",
    "playerId": "tiktok:viewer123",
    "roundId": "r-42"
  }
}
```

Server may forward `client_action` to the Windows bridge via HTTP callback if `BRIDGE_CALLBACK_URL` is set.

## Phases

| `phase` | Meaning |
|---------|---------|
| `idle` | Between rounds |
| `betting` | Accept bets |
| `flying` | Multiplier rising |
| `crashed` | Round ended, show result |

## Windows bridge contract

Your existing PC game should **POST** to `/bridge/push` whenever state changes or TikTok events arrive:

```json
{
  "kind": "state",
  "state": { "...": "full GameState object" }
}
```

```json
{
  "kind": "tiktok",
  "event": { "...": "tiktok_event payload" }
}
```

Use the same `GameState` shape as `GET /state` so iOS and OBS overlays stay in sync.
