"""
Purchasable heart mascot (all-time points). Same colour names as name shop.
Commands: !buy pink heart, !buy blue heart, … — see !hearts for the list.
Persistence: alltime_leaderboard keys heart_color (hex), heart_colors_owned, glow_mascot_crown (with !buy glow).
"""
from __future__ import annotations

from typing import Any

from name_colors import NAME_COLOR_COMMAND_TO_HEX

# Slightly more than name colour (icon is visible in-session + top 5)
HEART_COLOR_COST = 2000

HEART_COLOR_COMMAND_TO_HEX: dict[str, str] = NAME_COLOR_COMMAND_TO_HEX
HEART_COLOR_COMMANDS: frozenset[str] = frozenset(HEART_COLOR_COMMAND_TO_HEX.keys())


def hearts_list_popup_payload(nick: str, user_key: str) -> dict[str, Any]:
    lines = [
        f"!buy {cmd} heart — {HEART_COLOR_COST} pts" for cmd in sorted(HEART_COLOR_COMMAND_TO_HEX.keys())
    ]
    return {
        "title": "Heart icon colours",
        "subtitle": f"{HEART_COLOR_COST} pts per new heart · owned switch free · with glow: !mascot crown | !mascot heart",
        "lines": lines,
        "user_key": user_key,
        "from_name": nick,
        "duration_ms": 16000,
    }
