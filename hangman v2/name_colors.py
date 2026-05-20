"""
Purchasable overlay name colours (all-time points). Commands: !red, !blue, …
Persistence: alltime_leaderboard entry key \"name_color\" (hex).
"""
from __future__ import annotations

from typing import Any

NAME_COLOR_COST = 1000

# command (no !) -> CSS hex (readable on dark UI); broad RGB spread
NAME_COLOR_COMMAND_TO_HEX: dict[str, str] = {
    "red": "#f87171",
    "crimson": "#e11d48",
    "rose": "#fda4af",
    "orange": "#fb923c",
    "amber": "#fbbf24",
    "gold": "#fcd34d",
    "yellow": "#facc15",
    "lime": "#a3e635",
    "green": "#4ade80",
    "emerald": "#34d399",
    "teal": "#2dd4bf",
    "cyan": "#22d3ee",
    "sky": "#38bdf8",
    "blue": "#3b82f6",
    "indigo": "#6366f1",
    "violet": "#8b5cf6",
    "purple": "#a855f7",
    "fuchsia": "#d946ef",
    "pink": "#ec4899",
    "magenta": "#e879f9",
    "coral": "#ff7f50",
    "salmon": "#fa8072",
    "lavender": "#c4b5fd",
    "mint": "#6ee7b7",
    "navy": "#60a5fa",
    "maroon": "#b91c1c",
    "olive": "#65a30d",
    "turquoise": "#40e0d0",
    "hotpink": "#ff69b4",
    "chartreuse": "#7fff00",
    "orchid": "#da70d6",
    "steel": "#94a3b8",
    "white": "#f8fafc",
    "snow": "#e2e8f0",
    "ice": "#bae6fd",
    "neon": "#39ff14",
    "electric": "#00ffff",
    "fire": "#ff4500",
    "ocean": "#0077be",
    "grape": "#6b21a8",
    "cherry": "#de3163",
    "ruby": "#e0115f",
    "sapphire": "#0f52ba",
    "jade": "#00a86b",
    "sunset": "#ff6b35",
    "slate": "#cbd5e1",
}

NAME_COLOR_COMMANDS: frozenset[str] = frozenset(NAME_COLOR_COMMAND_TO_HEX.keys())


def command_list_popup_payload(nick: str, user_key: str) -> dict[str, Any]:
    lines = [f"!{cmd} — {NAME_COLOR_COST} pts" for cmd in sorted(NAME_COLOR_COMMAND_TO_HEX.keys())]
    return {
        "title": "Colour name shop",
        "subtitle": f"{NAME_COLOR_COST} pts per new colour · owned colours switch free (!red !blue …)",
        "lines": lines,
        "user_key": user_key,
        "from_name": nick,
        "duration_ms": 14000,
    }
