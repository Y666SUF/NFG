"""
Unlockable win jingles for the stream overlay when a player seals the word.

Sound files live under ``static/win-sounds/`` (served at ``/static/win-sounds/…``).
Replace bundled placeholders with your own short MP3/OGG/WAV files — keep filenames matching ``file``.
"""
from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from alltime_leaderboard import _load_raw, _save_raw, default_storage_path

_lock = threading.Lock()

# id -> { name, cost, file }  (cost 0 = free default for everyone)
WIN_SOUNDS: dict[str, dict[str, Any]] = {
    "classic": {
        "name": "Classic bell",
        "cost": 0,
        "file": "classic.wav",
        "blurb": "Clean ding — default for everyone.",
    },
    "airhorn": {
        "name": "Airhorn",
        "cost": 1200,
        "file": "airhorn.wav",
        "blurb": "Stadium energy — very loud stream.",
    },
    "vine": {
        "name": "Dramatic vine",
        "cost": 1800,
        "file": "vine.wav",
        "blurb": "That one TikTok beat drop vibe.",
    },
    "bruh": {
        "name": "Bruh moment",
        "cost": 900,
        "file": "bruh.wav",
        "blurb": "Short disappointed horn.",
    },
    "victory": {
        "name": "Victory fanfare",
        "cost": 2500,
        "file": "victory.wav",
        "blurb": "Tiny celebration fanfare.",
    },
    "goofy": {
        "name": "Goofy boings",
        "cost": 1500,
        "file": "goofy.wav",
        "blurb": "Silly springy meme energy.",
    },
}

DEFAULT_WIN_SOUND_ID = "classic"


def win_sound_public_url(sound_id: str) -> str | None:
    meta = WIN_SOUNDS.get(sound_id)
    if not meta:
        return None
    fn = str(meta.get("file") or "")
    if not fn:
        return None
    return f"/static/win-sounds/{fn}"


def _normalize_owned(raw: Any) -> list[str]:
    if isinstance(raw, list):
        out = [str(x).strip().lower() for x in raw if str(x).strip()]
    elif isinstance(raw, str) and raw.strip():
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, list):
                return _normalize_owned(parsed)
        except json.JSONDecodeError:
            pass
        out = [raw.strip().lower()]
    else:
        out = []
    if DEFAULT_WIN_SOUND_ID not in out:
        out.insert(0, DEFAULT_WIN_SOUND_ID)
    return list(dict.fromkeys(out))


def _active_id(entry: dict[str, Any]) -> str:
    s = str(entry.get("win_sound_active") or DEFAULT_WIN_SOUND_ID).strip().lower()
    return s if s in WIN_SOUNDS else DEFAULT_WIN_SOUND_ID


def win_sound_payload_for_user(user_key: str, path: Path | None = None) -> dict[str, Any] | None:
    """Payload for WebSocket ``round_popup.win_sound`` so the overlay can play one clip."""
    if not user_key:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        ent = data.get(user_key)
        if not isinstance(ent, dict):
            ent = {}
        owned = _normalize_owned(ent.get("win_sounds_owned"))
        active = _active_id(ent)
        if active not in owned:
            active = DEFAULT_WIN_SOUND_ID
        if active == DEFAULT_WIN_SOUND_ID:
            return None
        meta = WIN_SOUNDS.get(active) or WIN_SOUNDS[DEFAULT_WIN_SOUND_ID]
        url = win_sound_public_url(active)
        if not url:
            return None
        return {
            "id": active,
            "label": str(meta.get("name") or active),
            "url": url,
        }


def try_buy_win_sound(
    user_key: str,
    display_name: str,
    sound_id: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Spend all-time points once to permanently unlock a win sound."""
    sid = (sound_id or "").strip().lower()
    if not user_key:
        return False, "[Shop] Can't buy — no user id."
    meta = WIN_SOUNDS.get(sid)
    if not meta:
        return False, f'[Shop] Unknown win sound "{sound_id}". Type !winsounds for the list.'
    cost = int(meta.get("cost") or 0)
    if cost <= 0:
        return False, f"[Shop] {meta.get('name') or sid} is free — pick it with !setwinsound {sid}."
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        owned = _normalize_owned(entry.get("win_sounds_owned"))
        if sid in owned:
            nm = str(entry.get("name") or label)
            return False, f"@{nm}: You already own '{meta.get('name') or sid}'."
        total = int(entry.get("total", 0))
        if total < cost:
            short = cost - total
            return (
                False,
                f"@{label}: '{meta.get('name')}' costs {cost} all-time pts (you have {total}, need {short} more).",
            )
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - cost
        owned.append(sid)
        entry["win_sounds_owned"] = list(dict.fromkeys(owned))
        entry["win_sound_active"] = sid
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return (
        True,
        f"@{nm}: Unlocked '{meta.get('name')}'! -{cost} all-time pts -- active now. Change with !setwinsound <id>.",
    )


def try_set_win_sound(
    user_key: str,
    display_name: str,
    sound_id: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Set active win sound (must already own it, or free classic)."""
    sid = (sound_id or "").strip().lower()
    if not user_key:
        return False, "[Shop] Can't set — no user id."
    if sid not in WIN_SOUNDS:
        return False, f'[Shop] Unknown win sound "{sound_id}". Type !winsounds.'
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        owned = _normalize_owned(entry.get("win_sounds_owned"))
        cost = int((WIN_SOUNDS.get(sid) or {}).get("cost") or 0)
        if cost > 0 and sid not in owned:
            return False, f"@{label}: Buy '{WIN_SOUNDS[sid].get('name')}' first (!buy winsound {sid})."
        entry["name"] = label or entry.get("name") or user_key
        entry["win_sound_active"] = sid
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    pretty = WIN_SOUNDS[sid].get("name") or sid
    return True, f"@{nm}: Win sound set to '{pretty}' -- plays when you seal a word."


def winsounds_list_popup_payload(nick: str, user_key: str, path: Path | None = None) -> dict[str, Any]:
    """Overlay list (same card as !command / !hearts): title + bullet lines."""
    path = path or default_storage_path()
    active = DEFAULT_WIN_SOUND_ID
    with _lock:
        data = _load_raw(path)
        ent = data.get(user_key) if user_key else None
        if isinstance(ent, dict):
            active = _active_id(ent)
    lines: list[str] = []
    for sid in sorted(WIN_SOUNDS.keys(), key=lambda x: (WIN_SOUNDS[x].get("cost") or 0, x)):
        m = WIN_SOUNDS[sid]
        cost = int(m.get("cost") or 0)
        nm = str(m.get("name") or sid)
        mark = " ★" if sid == active else ""
        if cost == 0:
            lines.append(f"!setwinsound {sid} — {nm} (free){mark}")
        else:
            lines.append(f"!buy winsound {sid} — {cost} pts · {nm}{mark}")
    lines.append("After buying: !setwinsound <id> to switch · plays when you seal the word on stream.")
    return {
        "title": "Win sound shop",
        "subtitle": "One-time unlocks · stream hears your jingle when you win a round",
        "lines": lines,
        "user_key": user_key,
        "from_name": nick,
        "duration_ms": 55_000,
    }