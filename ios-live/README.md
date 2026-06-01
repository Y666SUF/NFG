# NFG Live — TikTok Live TTS + Spotify song requests

A hands-free iPhone app (your own TikFinity-style tool) for running your TikTok live:

- **Reads live chat aloud** using on-device text-to-speech (free, offline, plays through
  your car / Bluetooth speaker even with the screen off — `audio` background mode).
- Shows the live chat feed, gifts, joins, and Spotify **now-playing + queue**.
- Viewers queue music by typing **`!song <name> <artist>`** in your live chat — so they
  control the music while you drive without you touching your phone.

This folder (`ios-live/`) is the **iOS app only** — built and updated on the MacBook.
All TikTok scraping and Spotify queueing run on the **Windows PC** server (the same one
behind `https://y666suf.com`). See `docs/cross-device/pending-on-pc.md` for the one-time
backend changes the PC needs.

## How it connects

- WebSocket: `wss://y666suf.com` — receives `live_comment`, `live_gift`, `live_join`,
  `live_song_request` broadcasts and reads them aloud.
- REST: `/api/mobile/status` (TikTok live state), `/api/spotify/status` (now playing +
  queue), `POST /api/spotify/queue` (host queues a track from the app).

Change the server in the app under **Settings → Backend server** (defaults to `y666suf.com`).

## Build

```bash
# Quick compile check on the simulator
./scripts/build-simulator.sh

# Build + install on a connected iPhone (get DEVICE_ID from: xcrun xctrace list devices)
./scripts/build-iphone.sh DEVICE_ID
./scripts/install-iphone.sh DEVICE_ID
```

Or just open `NFGLive.xcodeproj` in Xcode, pick your iPhone, and press Run.

## Project layout

- `NFGLive/NFGLiveApp.swift` — app entry; wires `SpeechManager` + `LiveCasterClient`.
- `NFGLive/Config/AppConfig.swift` — server URL + endpoints.
- `NFGLive/Services/LiveCasterClient.swift` — WebSocket feed + Spotify/status polling.
- `NFGLive/Services/SpeechManager.swift` — `AVSpeechSynthesizer` TTS, audio ducking, filters.
- `NFGLive/Views/` — Live feed, Voice controls, Music panel, Settings (tabbed UI).

## Requirements on the PC side

- Spotify must have an **active device** and a **Premium** account for queueing (same as
  the existing `!csong`). Set `LIVE_SONG_COMMAND=1` to enable the bare `!song` keyword.
- Apply `docs/cross-device/pending-on-pc.md` so the server broadcasts the live chat feed.

Bundle id: `com.yusufali.nfglive` · Team: `VM34N9485F` · iOS 17+.
