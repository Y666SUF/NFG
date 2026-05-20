"""Hangman Spotify chat command parsing — prefixed to avoid clash with NFG Crash."""
from __future__ import annotations

import re
from typing import Optional

# !hsong !hqueue !haddsong  or  !hangmansong !hangmanqueue !hangmanaddsong
_HANGMAN_QUEUE_RE = re.compile(
    r"^!(?:h(?:song|queue|addsong)|hangman(?:song|queue|addsong))\b(.*)$",
    re.I,
)
_LEGACY_GENERIC_RE = re.compile(r"^!(?:song|queue|addsong)\b", re.I)

# Admin: !hqueueallow !hqueuedeny !hqueueremove !hqueuelist (+ long forms)
_HANGMAN_ADMIN_CMDS = frozenset(
    {
        "!hqueueallow",
        "!hqueuedeny",
        "!hqueueremove",
        "!hqueuelist",
        "!hangmanqueueallow",
        "!hangmanqueuedeny",
        "!hangmanqueueremove",
        "!hangmanqueuelist",
    }
)


def hangman_spotify_queue_match(text: str) -> Optional[re.Match[str]]:
    raw = (text or "").strip()
    if not raw:
        return None
    if _LEGACY_GENERIC_RE.match(raw):
        return None
    return _HANGMAN_QUEUE_RE.match(raw)


def hangman_spotify_command_name(text: str) -> str:
    """song | queue | addsong"""
    raw = (text or "").strip().lower()
    if raw.startswith("!hqueue") or raw.startswith("!hangmanqueue"):
        return "queue"
    if raw.startswith("!haddsong") or raw.startswith("!hangmanaddsong"):
        return "addsong"
    return "song"


def hangman_spotify_admin_command(text: str) -> Optional[str]:
    parts = (text or "").strip().split(maxsplit=1)
    if not parts:
        return None
    cmd = parts[0].lower()
    if cmd in _HANGMAN_ADMIN_CMDS:
        return cmd
    return None


def legacy_spotify_hint() -> str:
    return "[Spotify] Use !hsong or !hqueue for Hangman (NFG Crash uses !csong / !cqueue)."


def hangman_spotify_usage_hint() -> str:
    return (
        "[Spotify] Hangman: !hsong / !hqueue / !haddsong "
        "(or !hangmansong …). Broadcaster: !hqueueallow @viewer"
    )
