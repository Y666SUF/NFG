"""Spotify now-playing via Windows Global System Media Transport Controls (GSMTC).

Requires Spotify desktop to be running and reporting to Windows "Now playing".
Only works on Windows with optional winrt packages (see requirements.txt).
"""
from __future__ import annotations

import sys
from typing import Any

# Windows: 4 == MediaPlaybackStatus.playing
_PLAYING = 4


async def spotify_now_playing_async() -> dict[str, Any]:
    if sys.platform != "win32":
        return {"ok": False, "title": "", "artist": "", "line": "", "playing": False, "error": "not_windows"}

    try:
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
    except ImportError:
        return {"ok": False, "title": "", "artist": "", "line": "", "playing": False, "error": "winrt_missing"}

    manager = await MediaManager.request_async()
    sessions = manager.get_sessions()
    spotify = None
    for session in sessions:
        a = session.source_app_user_model_id or ""
        if "spotify" in a.lower():
            spotify = session
            break

    if spotify is None:
        return {"ok": False, "title": "", "artist": "", "line": "", "playing": False, "error": "no_spotify_session"}

    try:
        props = await spotify.try_get_media_properties_async()
        title = (props.title or "").strip()
        artist = (props.artist or "").strip()
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "title": "", "artist": "", "line": "", "playing": False, "error": str(e)}

    if not title and not artist:
        return {"ok": False, "title": "", "artist": "", "line": "", "playing": False, "error": "empty_metadata"}

    if title and artist:
        line = f"{title} — {artist}"
    else:
        line = title or artist

    try:
        playback = spotify.get_playback_info()
        playing = int(playback.playback_status) == _PLAYING
    except Exception:  # noqa: BLE001
        playing = True

    return {
        "ok": True,
        "title": title,
        "artist": artist,
        "line": line,
        "playing": playing,
        "error": "",
    }
