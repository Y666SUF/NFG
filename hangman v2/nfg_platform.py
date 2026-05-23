"""Shared NFG platform hooks (Crash Node server on port 3847)."""
from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from typing import Any, Optional

_LINK_RE = re.compile(r"^!link\s+([A-Fa-f0-9]{6})\s*$", re.I)
# NFG Crash bet noise — must not consume Hangman guesses or points.
_CRASH_BET_RE = re.compile(r"^!b\d*\s*$", re.I)
_CRASH_AMOUNT_RE = re.compile(r"^!\d+(?:\.\d+)?\s*$")
_CRASH_SPOTIFY_RE = re.compile(
    r"^!(?:c(?:song|queue|addsong)|crash(?:song|queue|addsong))\b",
    re.I,
)
_HANGMAN_SPOTIFY_RE = re.compile(
    r"^!(?:h(?:song|queue|addsong)|hangman(?:song|queue|addsong))\b",
    re.I,
)


def nfg_platform_base() -> str:
    return (os.environ.get("NFG_PLATFORM_URL") or "http://127.0.0.1:3847").strip().rstrip("/")


def is_nfg_crash_spotify_noise(text: str) -> bool:
    """NFG Crash Spotify commands — handled on the Node server, not Hangman."""
    return bool(_CRASH_SPOTIFY_RE.match((text or "").strip()))


def is_nfg_hangman_spotify_noise(text: str) -> bool:
    return bool(_HANGMAN_SPOTIFY_RE.match((text or "").strip()))


def is_nfg_crash_chat_noise(text: str) -> bool:
    """True when message is a Crash live bet command (!b, !500, etc.)."""
    t = (text or "").strip()
    if not t:
        return False
    if _CRASH_BET_RE.match(t):
        return True
    if _CRASH_AMOUNT_RE.match(t):
        return True
    return False


def parse_link_command(text: str) -> Optional[str]:
    m = _LINK_RE.match((text or "").strip())
    return m.group(1).upper() if m else None


def forward_tiktok_link_to_platform(
    *,
    user_id: str,
    display_name: str,
    message: str,
) -> dict[str, Any]:
    """
    POST to Node /api/chat so mobile !link works on Hangman LIVE as well as Crash LIVE.
    Returns { ok, linked, tiktokChatReply } when handled.
    """
    code = parse_link_command(message)
    if not code:
        return {"handled": False}

    base = nfg_platform_base()
    payload = {
        "user": user_id,
        "userId": user_id,
        "displayName": display_name or user_id,
        "message": message.strip(),
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{base}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=4.0) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            body = json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8", errors="replace"))
        except Exception:
            body = {"ok": False, "error": str(e)}
    except Exception as e:
        return {
            "handled": True,
            "linked": False,
            "tiktokChatReply": f"Link server unreachable ({e!s}). Is NFG platform running on {base}?",
        }

    return {
        "handled": True,
        "linked": bool(body.get("linked")),
        "tiktokChatReply": body.get("tiktokChatReply"),
        "ok": bool(body.get("ok")),
    }


def platform_tiktok_bridge_is_live() -> bool:
    """True when the Node TikTok bridge (Crash server) is connected to a LIVE room."""
    base = nfg_platform_base()
    req = urllib.request.Request(f"{base}/api/internal/tiktok-bridge", method="GET")
    try:
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            body = json.loads(raw) if raw else {}
    except Exception:
        return False
    return str(body.get("state") or "").strip().lower() == "live"
