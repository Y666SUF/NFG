"""
Drop-in helper for your Windows NFG crash game (Python).

Call push_state() whenever your game state changes.
Call push_tiktok() when TikTok live chat sends a comment/gift.

Install: pip install requests
"""

from __future__ import annotations

import os
from typing import Any

import requests

SYNC_URL = os.environ.get("NFG_SYNC_URL", "http://127.0.0.1:3847")
BRIDGE_TOKEN = os.environ.get("NFG_BRIDGE_TOKEN", "change-me-to-a-long-secret")


def _post(path: str, body: dict[str, Any]) -> None:
    r = requests.post(
        f"{SYNC_URL}{path}",
        json=body,
        headers={"X-Bridge-Token": BRIDGE_TOKEN},
        timeout=5,
    )
    r.raise_for_status()


def push_state(state: dict[str, Any]) -> None:
    """Send full game snapshot — same shape as GET /state."""
    _post("/bridge/push", {"kind": "state", "state": state})


def push_tiktok(event: dict[str, Any]) -> None:
    """Forward TikTok comment/gift/etc. to iOS clients."""
    _post("/bridge/push", {"kind": "tiktok", "event": event})


def push_log(message: str, level: str = "info") -> None:
    _post("/bridge/push", {"kind": "log", "message": message, "level": level})


# Example wiring inside your game loop:
if __name__ == "__main__":
    push_state(
        {
            "phase": "betting",
            "roundId": "r-demo",
            "multiplier": 1.0,
            "crashPoint": None,
            "countdownMs": 10000,
            "players": [{"id": "tiktok:demo", "displayName": "Demo", "balance": 1000}],
            "activeBets": [],
            "recentChat": [],
        }
    )
    push_tiktok(
        {
            "kind": "comment",
            "user": "demo_viewer",
            "text": "bet 50",
            "giftName": None,
            "coins": 0,
        }
    )
    print("Pushed demo state + TikTok event to sync server")
