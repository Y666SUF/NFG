"""
Shared TikTok gift matching, diamond→all-time math, and event time filters.

Used by server.py (browser overlay) and main.py (CLI TikTok client) so rules stay aligned.
"""
from __future__ import annotations

import math
import os
import re
import time
from typing import Any


def event_create_unix(event: Any) -> float | None:
    try:
        bm = getattr(event, "base_message", None)
        if bm is None:
            return None
        t = int(getattr(bm, "create_time", 0) or 0)
        if t <= 0:
            return None
        if t > 10_000_000_000:
            t = t // 1000
        return float(t)
    except Exception:
        return None


def min_chat_event_create_unix(wall_session_started: float, wall_tiktok_connected: float | None) -> float:
    lag = os.environ.get("HANGMAN_CHAT_ONLY_AFTER_SESSION_SEC", "5").strip()
    try:
        extra = max(0.0, float(lag))
    except ValueError:
        extra = 5.0
    anchor = wall_session_started
    if wall_tiktok_connected is not None:
        anchor = max(anchor, wall_tiktok_connected)
    return anchor + extra


def tiktok_event_is_current_session(
    event: Any,
    *,
    wall_session_started: float,
    wall_tiktok_connected: float | None,
) -> bool:
    if os.environ.get("HANGMAN_CHAT_TIME_FILTER", "1").strip().lower() in ("0", "false", "no"):
        return True
    cutoff = min_chat_event_create_unix(wall_session_started, wall_tiktok_connected)
    t = event_create_unix(event)
    if t is not None:
        return t >= cutoff
    return time.time() >= cutoff


def tiktok_like_event_is_current_session(
    event: Any,
    *,
    wall_session_started: float,
    wall_tiktok_connected: float | None,
) -> bool:
    if os.environ.get("HANGMAN_CHAT_TIME_FILTER", "1").strip().lower() in ("0", "false", "no"):
        return True
    cutoff = min_chat_event_create_unix(wall_session_started, wall_tiktok_connected)
    try:
        backlog = max(0.0, float(os.environ.get("HANGMAN_LIKE_EVENT_BACKLOG_SEC", "900").strip()))
    except ValueError:
        backlog = 900.0
    like_floor = cutoff - backlog
    t = event_create_unix(event)
    if t is not None:
        return t >= like_floor
    return time.time() >= like_floor


def parse_galaxy_target(text: str) -> str | None:
    t = (text or "").strip()
    if not t or t.startswith("!"):
        return None
    if any(c.isspace() for c in t):
        return None
    raw = t.lstrip("@")
    if len(raw) < 2:
        return None
    return raw


def galaxy_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_GALAXY_GIFT_MATCH", "galaxy").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_GALAXY_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def rosa_gift_match(gift_name: str, gift_id: int) -> bool:
    raw_ids = os.environ.get("HANGMAN_ROSA_GIFT_IDS", "").strip()
    if raw_ids and gift_id:
        ids = {int(x.strip()) for x in raw_ids.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    needles = [
        p.strip().lower()
        for p in (os.environ.get("HANGMAN_ROSA_GIFT_MATCH", "rosa") or "").split(",")
        if p.strip()
    ]
    if not needles:
        return False
    g_norm = re.sub(r"[^a-z0-9]+", " ", (gift_name or "").lower()).strip()
    tokens = [t for t in g_norm.split() if t]
    for needle in needles:
        n_norm = re.sub(r"[^a-z0-9]+", " ", needle).strip()
        if not n_norm:
            continue
        if n_norm in tokens:
            return True
        if len(n_norm) >= 3 and any(t.startswith(n_norm) for t in tokens):
            return True
    return False


def cap_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_CAP_GIFT_MATCH", "cap").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_CAP_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def racing_debut_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_RACING_DEBUT_GIFT_MATCH", "racing debut").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_RACING_DEBUT_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def car_drifting_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_CAR_DRIFTING_GIFT_MATCH", "car drifting").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_CAR_DRIFTING_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def space_cat_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_SPACE_CAT_GIFT_MATCH", "space cat").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_SPACE_CAT_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def lion_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_LION_GIFT_MATCH", "lion").strip().lower()
    if needle:
        n_norm = re.sub(r"[^a-z0-9]+", " ", needle).strip()
        g_norm = re.sub(r"[^a-z0-9]+", " ", (gift_name or "").lower()).strip()
        if n_norm and g_norm and n_norm == g_norm:
            return True
    raw = os.environ.get("HANGMAN_LION_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def money_gun_gift_match(gift_name: str, gift_id: int) -> bool:
    needle = os.environ.get("HANGMAN_MONEY_GUN_GIFT_MATCH", "money gun").strip().lower()
    if needle and needle in (gift_name or "").lower():
        return True
    raw = os.environ.get("HANGMAN_MONEY_GUN_GIFT_IDS", "").strip()
    if raw and gift_id:
        ids = {int(x.strip()) for x in raw.split(",") if x.strip().isdigit()}
        if gift_id in ids:
            return True
    return False


def lion_nuke_window_sec() -> float:
    try:
        v = float(os.environ.get("HANGMAN_LION_NUKE_WINDOW_SEC", "300").strip())
    except ValueError:
        v = 300.0
    return max(10.0, min(v, 3600.0))


def gift_diamond_points_cap() -> int:
    try:
        return max(0, int(os.environ.get("HANGMAN_GIFT_DIAMOND_POINTS_CAP", "5000000").strip()))
    except ValueError:
        return 5000000


def gift_diamond_ratio() -> float:
    try:
        return max(0.0, float(os.environ.get("HANGMAN_GIFT_DIAMOND_RATIO", "0.1").strip()))
    except ValueError:
        return 0.1


def gift_diamond_alltime_points_enabled() -> bool:
    return os.environ.get("HANGMAN_GIFT_DIAMOND_POINTS", "1").strip().lower() not in ("0", "false", "no")


def gift_diamond_alltime_points(event: Any) -> int:
    if not gift_diamond_alltime_points_enabled():
        return 0
    gift = event.gift
    try:
        per = int(getattr(gift, "diamond_count", 0) or 0)
    except (TypeError, ValueError):
        per = 0
    if per <= 0:
        return 0
    use_repeat = os.environ.get("HANGMAN_GIFT_DIAMOND_USE_REPEAT", "1").strip().lower() not in (
        "0",
        "false",
        "no",
    )
    mult = 1
    if use_repeat:
        try:
            rpt = int(getattr(event, "repeat_count", 0) or 0)
        except (TypeError, ValueError):
            rpt = 0
        mult = rpt if rpt > 0 else 1
    diamonds = int(per) * int(mult)
    ratio = gift_diamond_ratio()
    pts = int(math.floor(float(diamonds) * ratio + 1e-12))
    pts = max(0, pts)
    cap = gift_diamond_points_cap()
    if cap > 0 and pts > cap:
        return cap
    return pts


def gift_debug_enabled() -> bool:
    return os.environ.get("HANGMAN_DEBUG_GIFTS", "").strip().lower() in ("1", "true", "yes", "on")


def gift_debug(msg: str) -> None:
    if gift_debug_enabled():
        print(f"[GiftDebug] {msg}", flush=True)


def car_drifting_trim_hours() -> float:
    try:
        return max(0.0, float(os.environ.get("HANGMAN_CAR_DRIFTING_TRIM_HOURS", "48").strip()))
    except ValueError:
        return 48.0


def fmt_mmss(total_sec: float) -> str:
    s = max(0, int(total_sec))
    m = s // 60
    r = s % 60
    return f"{m:02d}:{r:02d}"


def fmt_shield_remaining(exp_unix: float) -> str:
    left = max(0.0, exp_unix - time.time())
    h = int(left // 3600)
    m = int((left % 3600) // 60)
    if h >= 24:
        d = h // 24
        return f"{d} day(s) {h % 24}h left"
    return f"{h}h {m}m left"
