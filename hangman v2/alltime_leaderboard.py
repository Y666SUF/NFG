"""
Persistent all-time totals (JSON). Keyed by TikTok user_key (unique_id or fallback).

On every save, a slim mirror is written next to the main file: ``data/alltime_points_snapshot.json``
(``totals`` = user_key → points, plus optional ``names`` for display labels). Handy for diffing or recovery.

Optional per-user fields:
- word_solve_streak_peak: lifetime best consecutive words that user sealed (bragging-rights flame
  tier in the UI); not cleared on !resetsession.
- word_solve_streak_current: running consecutive words sealed (same rules as in-session streak); survives
  server restarts and session score reset; cleared when someone else seals or host ends the round unsolved.
- heart_color: hex from !buy <colour> heart (session + top-5 mascot when no glow).
- heart_colors_owned: list of hex — paid heart colours; switching among them is free.
- glow_mascot_crown: when true (default), glow users see the procedural crown mascot; when false, they see
  heart_color (must be in heart_colors_owned). Toggle with !mascot crown | !mascot heart (no charge).
- name_badge: star | heart | crown — emoji before your name on the overlay (!buy prefix …).
- name_badges_owned: list of star|heart|crown — paid badges; switching among them is free.
- name_color: active name colour hex; name_colors_owned lists every hex purchased (free switch).
- win_sounds_owned: list of unlocked win jingle ids; win_sound_active: id played when they seal a word (see win_sounds.py).
- like_bonus_date / like_bonus_day: UTC calendar day and points from LIVE likes that day (+1 per 10 likes
  this connection), capped at 500 per day (all-time total only; session scores unchanged).
- live_likes_lifetime: TikTok LIVE likes counted for this user_key since the last Like MVP reset (burst totals);
  every 50,000 unlocks a higher ``like_cosmetic_tier`` for stream name styling (see LIVE_LIKES_COSMETIC_STEP).
  After each Like MVP payout (see ``reset_all_live_likes_lifetime``), this is set back to 0 for everyone.
"""
from __future__ import annotations

import json
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from text_normalize import normalize_lookup_token

_lock = threading.Lock()

# Cosmetic: spend all-time points once; stored as entry["glow"] = true
GLOW_COST = 5000

# TikTok LIVE likes → all-time only (helps dig out of negative); +1 per 10 likes this server session;
# at most LIKE_BONUS_DAILY_MAX points from likes per UTC calendar day (other all-time points uncapped).
LIKE_BONUS_DAILY_MAX = 500
LIKE_BONUS_LIKES_PER_POINT = 10

# Lifetime LIVE like count → name cosmetic tier (1 = 50k–99.999k likes, …). Capped to avoid absurd payloads.
LIVE_LIKES_COSMETIC_STEP = 50_000
LIVE_LIKES_COSMETIC_TIER_CAP = 99

# Emoji prefix before display name on stream overlay (!buy prefix star|heart|crown).
NAME_BADGE_COST = 1500
_NAME_BADGE_ALLOWED: frozenset[str] = frozenset({"star", "heart", "crown"})
WIN_BANNER_COST = 2500
_WIN_BANNER_ALLOWED: frozenset[str] = frozenset({"gold", "neon", "royal"})

# After Galaxy steal: victim loses points but keeps these keys (shop unlocks + streak bragging rights).
_GALAXY_VICTIM_PRESERVE_KEYS: frozenset[str] = frozenset(
    {
        "name_color",
        "heart_color",
        "glow",
        "name_badge",
        "name_badges_owned",
        "name_colors_owned",
        "heart_colors_owned",
        "glow_mascot_crown",
        "win_sounds_owned",
        "win_sound_active",
        "win_banner_style",
        "win_banners_owned",
        "word_solve_streak_peak",
        "word_solve_streak_current",
        "like_bonus_date",
        "like_bonus_day",
        "live_likes_lifetime",
        # Win banner cosmetics (upgrade how the winner popup looks, not their point total).
        "win_banner_style",
        "win_banners_owned",
    }
)

_GALAXY_LIST_COPY_KEYS: frozenset[str] = frozenset(
    {
        "win_sounds_owned",
        "name_badges_owned",
        "name_colors_owned",
        "heart_colors_owned",
    }
)


def _sanitize_hex_color(raw: Any) -> str | None:
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip()
    if not s.startswith("#"):
        return None
    body = s[1:]
    if len(body) not in (3, 6):
        return None
    for ch in body:
        if ch not in "0123456789abcdefABCDEF":
            return None
    return "#" + body.lower()


def _name_hex_owned_set(entry: dict[str, Any]) -> set[str]:
    """Union of stored purchases and current active colour (migrates legacy rows)."""
    s: set[str] = set()
    raw = entry.get("name_colors_owned")
    if isinstance(raw, list):
        for x in raw:
            h = _sanitize_hex_color(x)
            if h:
                s.add(h)
    cur = _sanitize_hex_color(entry.get("name_color"))
    if cur:
        s.add(cur)
    return s


def _heart_hex_owned_set(entry: dict[str, Any]) -> set[str]:
    """Union of stored heart purchases and current heart colour (migrates legacy rows)."""
    s: set[str] = set()
    raw = entry.get("heart_colors_owned")
    if isinstance(raw, list):
        for x in raw:
            h = _sanitize_hex_color(x)
            if h:
                s.add(h)
    cur = _sanitize_hex_color(entry.get("heart_color"))
    if cur:
        s.add(cur)
    return s


def try_buy_name_color(
    user_key: str,
    display_name: str,
    command: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Set entry['name_color']; charge NAME_COLOR_COST only for colours not yet in name_colors_owned."""
    from name_colors import NAME_COLOR_COMMAND_TO_HEX, NAME_COLOR_COST

    cmd = (command or "").strip().lower()
    if cmd not in NAME_COLOR_COMMAND_TO_HEX:
        return False, f"[Colour] Unknown !{cmd} — type !command for the list."
    if not user_key:
        return False, "[Colour] Can't buy — no user id."
    path = path or default_storage_path()
    raw_hex = NAME_COLOR_COMMAND_TO_HEX[cmd]
    hex_col = _sanitize_hex_color(raw_hex)
    if not hex_col:
        return False, f"[Colour] Unknown !{cmd} — type !command for the list."
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        cur = _sanitize_hex_color(entry.get("name_color"))
        if cur == hex_col:
            nm = str(entry.get("name") or label)
            return False, f"@{nm}: You're already using the {cmd} name colour — pick another from !command."
        owned = _name_hex_owned_set(entry)
        if hex_col in owned:
            entry["name"] = label or entry.get("name") or user_key
            entry["name_color"] = hex_col
            entry["name_colors_owned"] = sorted(owned)
            data[user_key] = entry
            _save_raw(path, data)
            nm = str(entry.get("name") or user_key)
            return (
                True,
                f"@{nm}: Name colour set to {cmd} (already unlocked — no charge).",
            )
        total = int(entry.get("total", 0))
        if total < NAME_COLOR_COST:
            short = NAME_COLOR_COST - total
            return (
                False,
                f"@{label}: !{cmd} costs {NAME_COLOR_COST} all-time points (you have {total}, need {short} more).",
            )
        owned.add(hex_col)
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - NAME_COLOR_COST
        entry["name_color"] = hex_col
        entry["name_colors_owned"] = sorted(owned)
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return True, f"@{nm}: Name colour set to {cmd}! -{NAME_COLOR_COST} all-time pts (unlocked — switch back free)."


def user_name_color_hex(user_key: str, path: Path | None = None) -> str | None:
    if not user_key:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return None
    return _sanitize_hex_color(ent.get("name_color"))


def _glow_mascot_crown_from_entry(ent: dict[str, Any]) -> bool:
    """If missing, treat as True (glow crown mascot — legacy rows)."""
    v = ent.get("glow_mascot_crown")
    if v is None:
        return True
    return bool(v)


def user_glow_mascot_crown(user_key: str, path: Path | None = None) -> bool:
    """While glow is on: True = crown mascot, False = coloured heart mascot (if heart_color set)."""
    if not user_key:
        return True
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        ent = data.get(user_key)
    if not isinstance(ent, dict) or not bool(ent.get("glow")):
        return True
    return _glow_mascot_crown_from_entry(ent)


def try_set_glow_mascot_pref(
    user_key: str,
    display_name: str,
    use_crown: bool,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Free toggle for glow players: crown mascot vs purchased heart mascot."""
    if not user_key:
        return False, "[Shop] Can't set — no user id."
    label = (display_name or "").strip() or user_key
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        if not bool(entry.get("glow")):
            return (
                False,
                f"@{label}: !mascot is for glow players — !buy glow first, or use !buy pink heart without glow.",
            )
        owned = _heart_hex_owned_set(entry)
        if use_crown:
            entry["glow_mascot_crown"] = True
        else:
            hc = _sanitize_hex_color(entry.get("heart_color"))
            if not hc or hc not in owned:
                return (
                    False,
                    f"@{label}: Unlock a heart colour first (!buy pink heart) — then !mascot heart shows it.",
                )
            entry["glow_mascot_crown"] = False
        entry["name"] = label or entry.get("name") or user_key
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    if use_crown:
        return True, f"@{nm}: Mascot set to glow crown (no charge). !mascot heart = your heart icon again."
    return True, f"@{nm}: Mascot set to your heart colour (no charge) — glowing name unchanged."


def user_heart_color_hex(user_key: str, path: Path | None = None) -> str | None:
    if not user_key:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return None
    return _sanitize_hex_color(ent.get("heart_color"))


def try_buy_heart_color(
    user_key: str,
    display_name: str,
    command: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Set entry['heart_color']; charge HEART_COLOR_COST only for heart colours not yet in heart_colors_owned."""
    from heart_icons import HEART_COLOR_COMMAND_TO_HEX, HEART_COLOR_COST

    cmd = (command or "").strip().lower()
    if cmd not in HEART_COLOR_COMMAND_TO_HEX:
        return False, f"[Shop] Unknown heart colour !{cmd} — type !hearts for the list."
    if not user_key:
        return False, "[Shop] Can't buy — no user id."
    path = path or default_storage_path()
    raw_hex = HEART_COLOR_COMMAND_TO_HEX[cmd]
    hex_col = _sanitize_hex_color(raw_hex)
    if not hex_col:
        return False, f"[Shop] Unknown heart colour !{cmd} — type !hearts for the list."
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        owned = _heart_hex_owned_set(entry)
        cur = _sanitize_hex_color(entry.get("heart_color"))
        if cur == hex_col:
            nm = str(entry.get("name") or label)
            if bool(entry.get("glow")) and _glow_mascot_crown_from_entry(entry):
                entry["name"] = label or entry.get("name") or user_key
                entry["glow_mascot_crown"] = False
                entry["heart_colors_owned"] = sorted(owned)
                data[user_key] = entry
                _save_raw(path, data)
                return (
                    True,
                    f"@{nm}: Showing your {cmd} heart mascot (glow crown off — no charge). !mascot crown to switch back.",
                )
            return (
                False,
                f"@{nm}: You're already using the {cmd} heart — pick another from !hearts.",
            )
        if hex_col in owned:
            entry["name"] = label or entry.get("name") or user_key
            entry["heart_color"] = hex_col
            entry["heart_colors_owned"] = sorted(owned)
            if bool(entry.get("glow")):
                entry["glow_mascot_crown"] = False
            data[user_key] = entry
            _save_raw(path, data)
            nm = str(entry.get("name") or user_key)
            return (
                True,
                f"@{nm}: Heart icon set to {cmd} (already unlocked — no charge).",
            )
        total = int(entry.get("total", 0))
        if total < HEART_COLOR_COST:
            short = HEART_COLOR_COST - total
            return (
                False,
                f"@{label}: !buy {cmd} heart costs {HEART_COLOR_COST} all-time points "
                f"(you have {total}, need {short} more).",
            )
        owned.add(hex_col)
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - HEART_COLOR_COST
        entry["heart_color"] = hex_col
        entry["heart_colors_owned"] = sorted(owned)
        if bool(entry.get("glow")):
            entry["glow_mascot_crown"] = False
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return (
        True,
        f"@{nm}: Heart icon set to {cmd}! -{HEART_COLOR_COST} all-time pts (unlocked — !mascot crown/heart with glow).",
    )


def default_storage_path() -> Path:
    return Path(__file__).resolve().parent / "data" / "alltime_leaderboard.json"


def _load_raw(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def _save_points_snapshot(main_path: Path, data: dict[str, Any]) -> None:
    """Write ``alltime_points_snapshot.json`` beside the main leaderboard (points + names only)."""
    snap_path = main_path.with_name("alltime_points_snapshot.json")
    totals: dict[str, int] = {}
    names: dict[str, str] = {}
    for k, v in data.items():
        if not isinstance(v, dict):
            continue
        try:
            totals[k] = int(v.get("total", 0) or 0)
        except (TypeError, ValueError):
            totals[k] = 0
        nm = (str(v.get("name") or "")).strip()
        if nm:
            names[k] = nm
    payload: dict[str, Any] = {
        "updated_at_unix": int(time.time()),
        "source": main_path.name,
        "totals": {k: totals[k] for k in sorted(totals.keys())},
    }
    if names:
        payload["names"] = {k: names[k] for k in sorted(names.keys())}
    tmp = snap_path.with_suffix(snap_path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=0, ensure_ascii=False)
    tmp.replace(snap_path)


def _save_raw(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    text = json.dumps(data, indent=0, ensure_ascii=False)
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    tmp.replace(path)
    try:
        _save_points_snapshot(path, data)
    except OSError:
        pass


def record_word_streak_peak(
    user_key: str, display_name: str, streak: int, path: Path | None = None
) -> None:
    """Raise stored peak if `streak` exceeds word_solve_streak_peak (same JSON as all-time)."""
    if not user_key:
        return
    try:
        st = int(streak)
    except (TypeError, ValueError):
        return
    if st < 1:
        return
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        prev = int(entry.get("word_solve_streak_peak", 0) or 0)
        if st <= prev:
            return
        entry["word_solve_streak_peak"] = st
        entry["name"] = (display_name or "").strip() or entry.get("name") or user_key
        data[user_key] = entry
        _save_raw(path, data)


def word_streak_peak_for_key(user_key: str, path: Path | None = None) -> int:
    if not user_key:
        return 0
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return 0
    try:
        return max(0, int(ent.get("word_solve_streak_peak", 0) or 0))
    except (TypeError, ValueError):
        return 0


def word_solve_streak_current_for_key(user_key: str, path: Path | None = None) -> int:
    """Running seal streak stored with all-time data (survives server / overlay restarts)."""
    if not user_key:
        return 0
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return 0
    try:
        return max(0, int(ent.get("word_solve_streak_current", 0) or 0))
    except (TypeError, ValueError):
        return 0


def persist_word_solve_streak_currents_batch(
    rows: list[tuple[str, str, int]], path: Path | None = None
) -> None:
    """Write ``word_solve_streak_current`` for each (user_key, display_name, streak)."""
    if not rows:
        return
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        for user_key, display_name, streak in rows:
            if not user_key:
                continue
            try:
                st = max(0, int(streak))
            except (TypeError, ValueError):
                st = 0
            entry = dict(data.get(user_key) or {})
            entry["word_solve_streak_current"] = st
            entry["name"] = (display_name or "").strip() or entry.get("name") or user_key
            entry.setdefault("total", int(entry.get("total", 0) or 0))
            data[user_key] = entry
        _save_raw(path, data)


def add_points(user_key: str, display_name: str, delta: int, path: Path | None = None) -> None:
    if not user_key or delta == 0:
        return
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        entry["name"] = display_name or entry.get("name") or user_key
        entry["total"] = int(entry.get("total", 0)) + int(delta)
        data[user_key] = entry
        _save_raw(path, data)


def live_like_cosmetic_tier(lifetime_likes: int) -> int:
    """Tier 0 below first milestone; tier 1 at 50k, tier 2 at 100k, …"""
    try:
        n = int(lifetime_likes)
    except (TypeError, ValueError):
        return 0
    if n < LIVE_LIKES_COSMETIC_STEP:
        return 0
    return min(LIVE_LIKES_COSMETIC_TIER_CAP, n // LIVE_LIKES_COSMETIC_STEP)


def user_live_likes_lifetime(user_key: str, path: Path | None = None) -> int:
    if not user_key:
        return 0
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        ent = data.get(user_key)
    if not isinstance(ent, dict):
        return 0
    try:
        return max(0, int(ent.get("live_likes_lifetime", 0) or 0))
    except (TypeError, ValueError):
        return 0


def user_like_cosmetic_tier(user_key: str, path: Path | None = None) -> int:
    return live_like_cosmetic_tier(user_live_likes_lifetime(user_key, path))


def top_live_likes_lifetime_holder(path: Path | None = None) -> dict[str, Any] | None:
    """
    The viewer with highest ``live_likes_lifetime`` in storage (likes since the last Like MVP reset).

    Tie-break: lexicographic ``user_key`` (stable). Returns ``None`` if nobody has lifetime likes > 0.
    """
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    best_key: str | None = None
    best_likes = -1
    best_ent: dict[str, Any] | None = None
    for uk, ent in data.items():
        if not isinstance(uk, str) or not uk or uk == "anon":
            continue
        if not isinstance(ent, dict):
            continue
        try:
            li = max(0, int(ent.get("live_likes_lifetime", 0) or 0))
        except (TypeError, ValueError):
            li = 0
        if li <= 0:
            continue
        if best_key is None or li > best_likes or (li == best_likes and uk < best_key):
            best_key = uk
            best_likes = li
            best_ent = ent
    if not best_key or best_ent is None:
        return None
    nm = str(best_ent.get("name") or best_key).strip() or best_key
    nb = best_ent.get("name_badge")
    nb_s = str(nb).strip() if isinstance(nb, str) and nb.strip() else None
    return {
        "user_key": best_key,
        "name": nm,
        "live_likes_lifetime": int(best_likes),
        "name_badge": nb_s,
        "like_cosmetic_tier": int(live_like_cosmetic_tier(int(best_likes))),
    }


def record_live_likes_lifetime(
    user_key: str,
    display_name: str,
    delta: int,
    path: Path | None = None,
) -> tuple[int, int, int]:
    """
    Add ``delta`` TikTok LIVE likes to ``live_likes_lifetime`` (persistent).

    Returns ``(new_lifetime_total, new_cosmetic_tier, old_cosmetic_tier)``.
    """
    if not user_key or user_key == "anon":
        return (0, 0, 0)
    try:
        d = int(delta)
    except (TypeError, ValueError):
        return (0, 0, 0)
    if d <= 0:
        return (0, 0, 0)
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        try:
            prev = max(0, int(entry.get("live_likes_lifetime", 0) or 0))
        except (TypeError, ValueError):
            prev = 0
        old_tier = live_like_cosmetic_tier(prev)
        new_total = prev + d
        new_tier = live_like_cosmetic_tier(new_total)
        entry["name"] = label or entry.get("name") or user_key
        entry["live_likes_lifetime"] = int(new_total)
        data[user_key] = entry
        _save_raw(path, data)
    return (int(new_total), int(new_tier), int(old_tier))


def reset_all_live_likes_lifetime(path: Path | None = None) -> int:
    """
    Set ``live_likes_lifetime`` to 0 for every stored user. Called after Like MVP processes its due
    slot(s) so the next contest period starts from zero.

    Returns how many user keys had a positive ``live_likes_lifetime`` before reset.
    """
    path = path or default_storage_path()
    cleared = 0
    with _lock:
        data = _load_raw(path)
        changed = False
        for uk, ent in list(data.items()):
            if not isinstance(uk, str) or not uk or uk == "anon":
                continue
            if not isinstance(ent, dict):
                continue
            try:
                li = max(0, int(ent.get("live_likes_lifetime", 0) or 0))
            except (TypeError, ValueError):
                li = 0
            if li <= 0:
                continue
            cleared += 1
            new_ent = dict(ent)
            new_ent["live_likes_lifetime"] = 0
            data[uk] = new_ent
            changed = True
        if changed:
            _save_raw(path, data)
    return cleared


def reset_alltime_points_for_all_users(path: Path | None = None) -> int:
    """
    Set ``total`` to 0 for every stored user row.

    Returns how many user keys had a non-zero total before reset.
    """
    path = path or default_storage_path()
    reset_count = 0
    with _lock:
        data = _load_raw(path)
        changed = False
        for uk, ent in list(data.items()):
            if not isinstance(uk, str) or not uk or uk == "anon":
                continue
            if not isinstance(ent, dict):
                continue
            try:
                total = int(ent.get("total", 0) or 0)
            except (TypeError, ValueError):
                total = 0
            if total == 0:
                continue
            reset_count += 1
            new_ent = dict(ent)
            new_ent["total"] = 0
            data[uk] = new_ent
            changed = True
        if changed:
            _save_raw(path, data)
    return reset_count


def _like_bonus_today_utc() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def try_award_live_like_alltime_bonus(
    user_key: str,
    display_name: str,
    session_like_total: int,
    session_tens_cursor: int,
    path: Path | None = None,
) -> tuple[int, int]:
    """
    +1 all-time point per full ``LIKE_BONUS_LIKES_PER_POINT`` likes this live (session counter).
    At most ``LIKE_BONUS_DAILY_MAX`` such points per UTC calendar day (``like_bonus_date`` / ``like_bonus_day``).
    Session hangman scores are unchanged.

    ``session_tens_cursor`` = how many 10-like blocks from this live were already converted.

    Returns ``(new_session_tens_cursor, points_awarded)``.
    """
    if not user_key or user_key == "anon":
        return (session_tens_cursor, 0)
    try:
        likes = max(0, int(session_like_total))
    except (TypeError, ValueError):
        likes = 0
    try:
        cur = max(0, int(session_tens_cursor))
    except (TypeError, ValueError):
        cur = 0
    eligible = likes // LIKE_BONUS_LIKES_PER_POINT
    new_blocks = max(0, eligible - cur)
    if new_blocks <= 0:
        return (cur, 0)
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    today = _like_bonus_today_utc()
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        stored_date = str(entry.get("like_bonus_date") or "").strip()
        if stored_date != today:
            day_awarded = 0
        else:
            try:
                day_awarded = max(0, min(LIKE_BONUS_DAILY_MAX, int(entry.get("like_bonus_day", 0) or 0)))
            except (TypeError, ValueError):
                day_awarded = 0
        rem = LIKE_BONUS_DAILY_MAX - day_awarded
        if rem <= 0:
            return (eligible, 0)
        award = min(new_blocks, rem)
        if award <= 0:
            return (cur, 0)
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = int(entry.get("total", 0)) + int(award)
        entry["like_bonus_date"] = today
        entry["like_bonus_day"] = day_awarded + int(award)
        data[user_key] = entry
        _save_raw(path, data)
    return (cur + int(award), int(award))


def display_name_for_key(user_key: str, path: Path | None = None) -> str:
    """Display name from the all-time file for a key, or the key itself."""
    if not user_key:
        return ""
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    v = data.get(user_key)
    if isinstance(v, dict):
        return str(v.get("name") or user_key)
    return user_key


def user_alltime_total(user_key: str, path: Path | None = None) -> int:
    """All-time point total for a key (0 if missing or not in file). May be negative."""
    if not user_key:
        return 0
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    v = data.get(user_key)
    if not isinstance(v, dict):
        return 0
    try:
        return int(v.get("total", 0))
    except (TypeError, ValueError):
        return 0


def resolve_user_key_from_handle(raw: str, path: Path | None = None) -> str | None:
    """
    Find stored leaderboard key from typed @username or handle (matches key or stored name).
    Comparison is case-insensitive; strips leading @.
    """
    t = normalize_lookup_token(raw or "")
    if len(t) < 2:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    for key in data:
        if normalize_lookup_token(key) == t:
            return key
    for key, v in data.items():
        if not isinstance(v, dict):
            continue
        name = normalize_lookup_token(str(v.get("name") or ""))
        if name and name == t:
            return key
    return None


def canonical_alltime_key(user_key: str, display_name: str, path: Path | None = None) -> str:
    """
    Map TikTok-derived keys onto the JSON row key for the same viewer.

    TikTok may expose ``unique_id``, a numeric id, or only a nickname across events. The leaderboard
    keeps the first shape we stored. Without this, one person can appear as two keys: guesses won't
    match wager duelists, or they'll look “ignored” when the session row doesn't line up.
    """
    raw = (user_key or "").strip()
    t = normalize_lookup_token(raw)
    if not t or t == "anon":
        return raw
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        for k in data:
            if normalize_lookup_token(k) == t:
                return k
        dn = normalize_lookup_token(display_name or "")
        if len(dn) >= 2:
            hits = [
                k
                for k, v in data.items()
                if isinstance(v, dict) and normalize_lookup_token(str(v.get("name") or "")) == dn
            ]
            if len(hits) == 1:
                return hits[0]
    return t


def transfer_alltime_points(
    victim_key: str,
    sender_key: str,
    sender_display_name: str,
    path: Path | None = None,
) -> tuple[bool, int, str]:
    """
    Move the victim's entire all-time point total onto the sender.
    The victim's row stays at ``total`` 0 so shop unlocks (colours, heart, glow, win sounds,
    owned badge/colour inventory lists) and ``word_solve_streak_peak`` are preserved — only points move.
    Returns (success, points_moved, victim_label). Fails if victim is missing or has no positive total.
    """
    if not victim_key or not sender_key or victim_key == sender_key:
        return (False, 0, "")
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        vent = data.get(victim_key)
        if vent is None or not isinstance(vent, dict):
            return (False, 0, "")
        pts = int(vent.get("total", 0))
        vlabel = str(vent.get("name") or victim_key)
        if pts <= 0:
            return (False, 0, vlabel)
        victim_rest: dict[str, Any] = {}
        for k in _GALAXY_VICTIM_PRESERVE_KEYS:
            if k not in vent:
                continue
            val = vent[k]
            if k in _GALAXY_LIST_COPY_KEYS and isinstance(val, list):
                victim_rest[k] = list(val)
            else:
                victim_rest[k] = val
        data[victim_key] = {"name": vlabel, "total": 0, **victim_rest}
        sent = dict(data.get(sender_key) or {})
        sent["name"] = (sender_display_name or "").strip() or sent.get("name") or sender_key
        sent["total"] = int(sent.get("total", 0)) + pts
        data[sender_key] = sent
        _save_raw(path, data)
    return (True, pts, vlabel)


def _coalesce_leaderboard_key(user_key: str, data: dict[str, Any]) -> str:
    """
    Return the JSON object key that should be used for user_key.
    Prefer an exact match; else first case-insensitive key with a dict row (TikTok ids are case-stable,
    but this avoids duplicate rows if casing ever differs).
    """
    if not user_key:
        return user_key
    if user_key in data and isinstance(data.get(user_key), dict):
        return user_key
    ul = user_key.lower()
    for k in data:
        if str(k).lower() == ul and isinstance(data.get(k), dict):
            return str(k)
    return user_key


def try_wager_settle(
    winner_key: str,
    loser_key: str,
    amount: int,
    winner_display_name: str,
    path: Path | None = None,
) -> tuple[bool, str, int]:
    """
    Atomic all-time transfer: loser loses up to ``amount`` (capped by their current balance),
    winner gains that same sum. Returns ``(ok, message, transferred)`` where ``transferred`` is 0 on failure.
    """
    if not winner_key or not loser_key or winner_key == loser_key or amount <= 0:
        return (False, "Invalid wager.", 0)
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        winner_key = _coalesce_leaderboard_key(winner_key, data)
        loser_key = _coalesce_leaderboard_key(loser_key, data)
        if winner_key == loser_key:
            return (False, "Invalid wager.", 0)
        lo = data.get(loser_key)
        wi = data.get(winner_key)
        if not isinstance(lo, dict):
            return (False, "Loser has no all-time entry.", 0)
        loser_total = int(lo.get("total", 0))
        pay = min(int(amount), max(0, loser_total))
        if pay <= 0:
            return (False, "Loser has no points to transfer.", 0)
        # Same merge pattern as add_points so cosmetics / streak peaks are preserved.
        wi = dict(wi) if isinstance(wi, dict) else {}
        wi["name"] = (winner_display_name or "").strip() or wi.get("name") or winner_key
        wi["total"] = int(wi.get("total", 0)) + int(pay)
        lo = dict(lo)
        lo["total"] = loser_total - int(pay)
        lo["name"] = str(lo.get("name") or loser_key)
        data[winner_key] = wi
        data[loser_key] = lo
        _save_raw(path, data)
    return (True, "", int(pay))


def reset_alltime_total(user_key: str, path: Path | None = None) -> tuple[bool, str]:
    """
    Remove a player from the all-time file (no points).
    Returns (ok, display_name_used_in_message) — name is from the entry before delete, else user_key.
    """
    if not user_key:
        return (False, "")
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
        entry = data.get(user_key)
        if entry is None:
            return (False, user_key)
        label = user_key
        if isinstance(entry, dict):
            label = str(entry.get("name") or user_key)
        del data[user_key]
        _save_raw(path, data)
    return (True, label)


def _sanitize_name_badge(raw: Any) -> str | None:
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip().lower()
    if s in _NAME_BADGE_ALLOWED:
        return s
    return None


def _badges_owned_set(entry: dict[str, Any]) -> set[str]:
    """Union of name_badges_owned and current name_badge (migrates legacy rows)."""
    s: set[str] = set()
    raw = entry.get("name_badges_owned")
    if isinstance(raw, list):
        for x in raw:
            bb = _sanitize_name_badge(x)
            if bb:
                s.add(bb)
    cur = _sanitize_name_badge(entry.get("name_badge"))
    if cur:
        s.add(cur)
    return s


def _sanitize_win_banner_style(raw: Any) -> str | None:
    if not raw or not isinstance(raw, str):
        return None
    s = raw.strip().lower()
    if s in _WIN_BANNER_ALLOWED:
        return s
    return None


def _win_banners_owned_set(entry: dict[str, Any]) -> set[str]:
    """Union of win_banners_owned and current win_banner_style (migrates legacy rows)."""
    s: set[str] = set()
    raw = entry.get("win_banners_owned")
    if isinstance(raw, list):
        for x in raw:
            b = _sanitize_win_banner_style(x)
            if b:
                s.add(b)
    cur = _sanitize_win_banner_style(entry.get("win_banner_style"))
    if cur:
        s.add(cur)
    return s


def user_win_banner_style(user_key: str, path: Path | None = None) -> str | None:
    if not user_key:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return None
    return _sanitize_win_banner_style(ent.get("win_banner_style"))


def try_buy_win_banner(
    user_key: str,
    display_name: str,
    style: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Set win banner style; charge WIN_BANNER_COST only for first unlock per style."""
    b = _sanitize_win_banner_style(style)
    if not b:
        return (
            False,
            '[Shop] Win banner style must be one of: gold, neon, royal (!buy banner gold).',
        )
    if not user_key:
        return False, "[Shop] Can't buy — no user id."
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        prev = _sanitize_win_banner_style(entry.get("win_banner_style"))
        if prev == b:
            nm = str(entry.get("name") or label)
            return False, f"@{nm}: Your win banner is already set to {b}."
        owned = _win_banners_owned_set(entry)
        if b in owned:
            entry["name"] = label or entry.get("name") or user_key
            entry["win_banner_style"] = b
            entry["win_banners_owned"] = sorted(owned)
            data[user_key] = entry
            _save_raw(path, data)
            nm = str(entry.get("name") or user_key)
            return True, f"@{nm}: Win banner style set to {b} (already unlocked — no charge)."
        total = int(entry.get("total", 0))
        if total < WIN_BANNER_COST:
            short = WIN_BANNER_COST - total
            return (
                False,
                f"@{label}: !buy banner {b} costs {WIN_BANNER_COST} all-time points "
                f"(you have {total}, need {short} more).",
            )
        owned.add(b)
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - WIN_BANNER_COST
        entry["win_banner_style"] = b
        entry["win_banners_owned"] = sorted(owned)
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return (
        True,
        f"@{nm}: Win banner style set to {b}! -{WIN_BANNER_COST} all-time pts "
        "(your word-solved popup stays up longer).",
    )


def user_name_badge(user_key: str, path: Path | None = None) -> str | None:
    if not user_key:
        return None
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return None
    return _sanitize_name_badge(ent.get("name_badge"))


def try_buy_name_badge(
    user_key: str,
    display_name: str,
    badge: str,
    path: Path | None = None,
) -> tuple[bool, str]:
    """Set name_badge; charge NAME_BADGE_COST only for badges not yet in name_badges_owned."""
    b = _sanitize_name_badge(badge)
    if not b:
        return False, "[Shop] Badge must be: star, heart, or crown (!buy prefix star)."
    if not user_key:
        return False, "[Shop] Can't buy — no user id."
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        prev_b = _sanitize_name_badge(entry.get("name_badge"))
        if prev_b == b:
            nm = str(entry.get("name") or label)
            return False, f"@{nm}: You're already showing the {b} badge — use another (!buy prefix star|heart|crown) to switch."
        owned = _badges_owned_set(entry)
        if b in owned:
            entry["name"] = label or entry.get("name") or user_key
            entry["name_badge"] = b
            entry["name_badges_owned"] = sorted(owned)
            data[user_key] = entry
            _save_raw(path, data)
            nm = str(entry.get("name") or user_key)
            return (
                True,
                f"@{nm}: Name badge set to {b} (already unlocked — no charge).",
            )
        total = int(entry.get("total", 0))
        if total < NAME_BADGE_COST:
            short = NAME_BADGE_COST - total
            return (
                False,
                f"@{label}: !buy prefix {b} costs {NAME_BADGE_COST} all-time points "
                f"(you have {total}, need {short} more).",
            )
        owned.add(b)
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - NAME_BADGE_COST
        entry["name_badge"] = b
        entry["name_badges_owned"] = sorted(owned)
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return (
        True,
        f"@{nm}: Name badge set to {b}! -{NAME_BADGE_COST} all-time pts (unlocked — switch back free).",
    )


def user_has_glow(user_key: str, path: Path | None = None) -> bool:
    if not user_key:
        return False
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    ent = data.get(user_key)
    if not isinstance(ent, dict):
        return False
    return bool(ent.get("glow"))


def try_buy_glow(user_key: str, display_name: str, path: Path | None = None) -> tuple[bool, str]:
    """
    Spend GLOW_COST all-time points once to unlock crown + glowing name; on all-time top 5, a unique sparkle border.
    Returns (success, one line for chat).
    """
    if not user_key:
        return False, "[Shop] Can't buy — no user id."
    path = path or default_storage_path()
    label = (display_name or "").strip() or user_key
    with _lock:
        data = _load_raw(path)
        entry = dict(data.get(user_key) or {})
        total = int(entry.get("total", 0))
        if entry.get("glow"):
            nm = str(entry.get("name") or label)
            return False, f"@{nm}: You already have glow."
        if total < GLOW_COST:
            short = GLOW_COST - total
            return (
                False,
                f"@{label}: !buy glow costs {GLOW_COST} all-time points (you have {total}, need {short} more).",
            )
        entry["name"] = label or entry.get("name") or user_key
        entry["total"] = total - GLOW_COST
        entry["glow"] = True
        entry["glow_mascot_crown"] = True
        data[user_key] = entry
        _save_raw(path, data)
        nm = str(entry.get("name") or user_key)
    return (
        True,
        f"@{nm}: Glow unlocked! -{GLOW_COST} all-time pts — crown mascot + glowing name (!mascot heart if you own hearts).",
    )


def top_players(limit: int = 15, path: Path | None = None) -> list[dict[str, Any]]:
    """Rows sorted by total; includes glow, optional name_color and heart_color hex."""
    path = path or default_storage_path()
    with _lock:
        data = _load_raw(path)
    rows: list[tuple[str, str, int, bool, str | None, int, str | None, str | None, bool, int, int]] = []
    for key, v in data.items():
        if not isinstance(v, dict):
            continue
        name = str(v.get("name") or key)
        total = int(v.get("total", 0))
        glow = bool(v.get("glow"))
        nc = _sanitize_hex_color(v.get("name_color"))
        hc = _sanitize_hex_color(v.get("heart_color"))
        nb = _sanitize_name_badge(v.get("name_badge"))
        gcrown = _glow_mascot_crown_from_entry(v) if glow else True
        try:
            ll = max(0, int(v.get("live_likes_lifetime", 0) or 0))
        except (TypeError, ValueError):
            ll = 0
        lt = live_like_cosmetic_tier(ll)
        try:
            peak = max(0, int(v.get("word_solve_streak_peak", 0) or 0))
        except (TypeError, ValueError):
            peak = 0
        rows.append((key, name, total, glow, nc, peak, hc, nb, gcrown, ll, lt))
    rows.sort(key=lambda t: t[2], reverse=True)
    return [
        {
            "name": n,
            "total": t,
            "user_key": k,
            "glow": g,
            "name_color": nc,
            "word_streak_peak": pk,
            "heart_color": hc,
            "name_badge": nb,
            "glow_mascot_crown": gc,
            "live_likes_lifetime": ll,
            "like_cosmetic_tier": lt,
        }
        for k, n, t, g, nc, pk, hc, nb, gc, ll, lt in rows[:limit]
    ]
